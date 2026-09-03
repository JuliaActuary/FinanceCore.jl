"""
    internal_rate_of_return(cashflows::AbstractVector)::Rate
    internal_rate_of_return(cashflows::AbstractVector, timepoints)::Rate
    internal_rate_of_return(cashflows::AbstractVector{<:Cashflow})::Rate

Calculate the internal rate of return with given timepoints. If no timepoints given, assumes equally spaced cashflows starting at time zero (0, 1, 2, ..., n).

Returns a `Periodic(rate, 1)` `Rate`, or `nothing` if no root is found. Get the scalar rate by calling `rate()` on the result.

# Example
```julia-repl
julia> internal_rate_of_return([-100,110],[0,1]) # e.g. cashflows at time 0 and 1
Periodic(0.1, 1)
julia> internal_rate_of_return([-100,110]) # implied the same as above
Periodic(0.1, 1)
```

# Solver notes
First tries Newton's method (fast). If Newton does not converge, falls back to a robust root-finding search in continuous rate space over `[-5, 3]` (approximately `[-0.993, 19.1]` in periodic rate). Fallback roots are residual-validated; when multiple roots remain, returns the one nearest zero.
"""
function internal_rate_of_return(cashflows::AbstractVector{<:Real})
    return internal_rate_of_return(cashflows, 0:(length(cashflows) - 1))
end

function internal_rate_of_return(cashflows::AbstractVector{C}) where {C <: Cashflow}
    # first try to quickly solve with newton's method, otherwise
    # revert to a more robust method

    v = irr_newton(cashflows)
    return isnothing(v) ? irr_robust(cashflows) : v
end

function internal_rate_of_return(cashflows, times)
    # first try to quickly solve with newton's method, otherwise
    # revert to a more robust method

    v = irr_newton(cashflows, times)
    return isnothing(v) ? irr_robust(cashflows, times) : v
end

irr_robust(cashflows) = irr_robust(cashflows, 0:(length(cashflows) - 1))

# Convert a force of interest from the solvers to an annual effective rate.
# `expm1` preserves nominal rates too small for `exp(r) - 1` to represent.
_periodic_from_force(r) = Periodic(expm1(r), 1)

function _is_irr_root(r, cashflows, times, M, t0)
    residual = zero(r)
    scale = zero(r)
    for (cf, t) in zip(cashflows, times)
        term = cf / M * exp(-r * (t - t0))
        residual += term
        scale += abs(term)
    end
    return isfinite(residual) && isfinite(scale) && !iszero(scale) &&
        abs(residual) ≤ sqrt(eps(Float64)) * scale
end

function irr_robust(cashflows, times)
    # Cashflows with only one sign cannot have a finite IRR. This check belongs on
    # the fallback path so ordinary Newton-convergent calls do not pay for a scan.
    has_positive = any(>(0), cashflows)
    has_negative = any(<(0), cashflows)
    has_positive && has_negative || return nothing

    # IRR is scale-invariant; normalizing keeps f(r) in O(1) range
    # so that find_zeros can reliably distinguish roots from noise.
    M = maximum(abs, cashflows)
    iszero(M) && return nothing
    # Shifting every timepoint by the same amount multiplies NPV by a positive
    # factor and therefore preserves its roots. It also prevents all terms from
    # underflowing together when the first timepoint is greater than zero.
    t0 = minimum(i -> times[i], eachindex(cashflows))
    # operate in continuous rate space to avoid the singularity at i = -1
    # in periodic space (where (1+i)^t is undefined for fractional t)
    f(r) = sum(
        cf / M * exp(-r * (t - t0)) for (cf, t) in zip(cashflows, times)
    )
    roots = Roots.find_zeros(f, -5.0, 3.0)
    filter!(r -> _is_irr_root(r, cashflows, times, M, t0), roots)

    # short circuit and return nothing if no roots found
    isempty(roots) && return nothing
    # find the root nearest zero and convert back to periodic rate
    min_i = argmin(abs.(roots))
    return _periodic_from_force(roots[min_i])

end

function _is_irr_root(r, cashflows::AbstractVector{C}, M, t0) where {C <: Cashflow}
    residual = zero(r)
    scale = zero(r)
    for cf in cashflows
        term = amount(cf) / M * exp(-r * (timepoint(cf) - t0))
        residual += term
        scale += abs(term)
    end
    return isfinite(residual) && isfinite(scale) && !iszero(scale) &&
        abs(residual) ≤ sqrt(eps(Float64)) * scale
end

function irr_robust(cashflows::AbstractVector{C}) where {C <: Cashflow}
    has_positive = any(cf -> amount(cf) > 0, cashflows)
    has_negative = any(cf -> amount(cf) < 0, cashflows)
    has_positive && has_negative || return nothing

    M = maximum(cf -> abs(amount(cf)), cashflows)
    iszero(M) && return nothing
    t0 = minimum(timepoint, cashflows)
    f(r) = sum(amount(cf) / M * exp(-r * (timepoint(cf) - t0)) for cf in cashflows)
    roots = Roots.find_zeros(f, -5.0, 3.0)
    filter!(r -> _is_irr_root(r, cashflows, M, t0), roots)

    # short circuit and return nothing if no roots found
    isempty(roots) && return nothing
    # find the root nearest zero and convert back to periodic rate
    min_i = argmin(abs.(roots))
    return _periodic_from_force(roots[min_i])

end


function irr_newton(cashflows, times)
    @assert length(cashflows) <= length(times)
    # use newton's method with hand-coded derivative
    r = __newtons_method1D_irr(
        cashflows,
        times,
        0.001,
        1.0e-9,
        100
    )
    isnothing(r) && return nothing
    return _periodic_from_force(r)

end

function irr_newton(cashflows::AbstractVector{C}) where {C <: Cashflow}
    # use newton's method with hand-coded derivative
    r = __newtons_method1D_irr(
        cashflows,
        0.001,
        1.0e-9,
        100
    )
    isnothing(r) && return nothing
    return _periodic_from_force(r)

end

# Backend trait for vectorization strategy
abstract type VectorizationBackend end
struct SimdBackend <: VectorizationBackend end
struct TurboBackend <: VectorizationBackend end

_vectorization_backend(r, cashflows, times) = SimdBackend()
_vectorization_backend(r, cashflows::AbstractVector{C}) where {C <: Cashflow} = SimdBackend()

# an internal function which calculates the
# present value and it's derivative in one pass
# for use in newton's method
#
# Dispatches to the appropriate backend based on the input types. The
# LoopVectorization extension opts supported dense floating-point arrays into its
# turbo kernel without changing process-global state.
function __pv_div_pv′(r, cashflows, times)
    return __pv_div_pv′(_vectorization_backend(r, cashflows, times), r, cashflows, times)
end

function __pv_div_pv′(r, cashflows::AbstractVector{C}) where {C <: Cashflow}
    return __pv_div_pv′(_vectorization_backend(r, cashflows), r, cashflows)
end

# Base @simd implementation
function __pv_div_pv′(::SimdBackend, r, cashflows, times)
    T = promote_type(typeof(r), eltype(cashflows), eltype(times))
    n = zero(T)
    d = zero(T)
    @inbounds @simd for i in eachindex(cashflows)
        cf = cashflows[i]
        t = times[i]
        a = cf * exp(-r * t)
        n += a
        d += a * -t
    end
    return n / d
end

_irr_accumulator_type(r, ::Type{<:Cashflow}) = typeof(r)
function _irr_accumulator_type(r, ::Type{Cashflow{A, T}}) where {A, T}
    return promote_type(typeof(r), A, T)
end

function __pv_div_pv′(
        ::SimdBackend,
        r,
        cashflows::AbstractVector{C},
    ) where {C <: Cashflow}
    S = _irr_accumulator_type(r, C)
    n = zero(S)
    d = zero(S)
    @inbounds @simd for i in eachindex(cashflows)
        cf = amount(cashflows[i])
        t = timepoint(cashflows[i])
        a = cf * exp(-r * t)
        n += a
        d += a * -t
    end
    return n / d
end

"""
    irr(cashflows::vector)
    irr(cashflows::Vector, timepoints::Vector)

    An alias for `internal_rate_of_return`.
"""
const irr = internal_rate_of_return

# modified from
# Algorithms for Optimization, Mykel J. Kochenderfer and Tim A. Wheeler, pg 88
function __newtons_method1D_irr(cashflows, times, x, ε, k_max)
    for _ in 1:k_max
        Δ = __pv_div_pv′(x, cashflows, times)
        isfinite(Δ) || return nothing
        x -= Δ
        isfinite(x) || return nothing
        abs(Δ) ≤ ε && return x
    end
    return nothing
end

function __newtons_method1D_irr(cashflows::AbstractVector{C}, x, ε, k_max) where {C <: Cashflow}
    for _ in 1:k_max
        Δ = __pv_div_pv′(x, cashflows)
        isfinite(Δ) || return nothing
        x -= Δ
        isfinite(x) || return nothing
        abs(Δ) ≤ ε && return x
    end
    return nothing
end
