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

function internal_rate_of_return(cashflows::AbstractVector{<:Cashflow})
    flows = ((amount(cf), timepoint(cf)) for cf in cashflows)
    return _irr(r -> __pv_div_pv′(r, cashflows), flows)
end

function internal_rate_of_return(cashflows, times)
    @assert length(cashflows) <= length(times)
    return _irr(r -> __pv_div_pv′(r, cashflows, times), zip(cashflows, times))
end

# The input adapters are lazy: Newton keeps its representation-specific kernel,
# while fallback policy operates on the same (amount, time) stream for both forms.
function _irr(pv_ratio::F, flows) where {F}
    r = _irr_newton(pv_ratio)
    isnothing(r) && (r = _irr_robust(flows))
    return isnothing(r) ? nothing : _periodic_from_force(r)
end

# Convert a force of interest from the solvers to an annual effective rate.
# `expm1` preserves nominal rates too small for `exp(r) - 1` to represent.
_periodic_from_force(r) = Periodic(expm1(r), 1)

function _is_irr_root(r, terms)
    residual = zero(r)
    scale = zero(r)
    for term in terms
        residual += term
        scale += abs(term)
    end
    return isfinite(residual) && isfinite(scale) && !iszero(scale) &&
        abs(residual) ≤ sqrt(eps(Float64)) * scale
end

function _irr_robust(flows)
    # Cashflows with only one sign cannot have a finite IRR. Keep this scan on
    # the fallback path so ordinary Newton-convergent calls do not pay for it.
    has_positive = any(p -> first(p) > 0, flows)
    has_negative = any(p -> first(p) < 0, flows)
    has_positive && has_negative || return nothing

    # Scaling amounts and shifting the time origin preserve roots and prevent
    # overflow/underflow from obscuring the residual. Both the root search and
    # its acceptance check use the same discounted terms.
    M = maximum(p -> abs(first(p)), flows)
    t0 = minimum(last, flows)
    terms(r) = (cf / M * exp(-r * (t - t0)) for (cf, t) in flows)
    # Continuous-rate space avoids the periodic singularity at i = -1.
    roots = Roots.find_zeros(r -> sum(terms(r)), -5.0, 3.0)
    filter!(r -> _is_irr_root(r, terms(r)), roots)
    return isempty(roots) ? nothing : argmin(abs, roots)
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

An alias for [`internal_rate_of_return`](@ref).
"""
const irr = internal_rate_of_return

# Modified from Algorithms for Optimization, Kochenderfer and Wheeler, p. 88.
# The evaluator selects the kernel; termination and failure policy are shared.
function _irr_newton(pv_ratio, x = 0.001, ε = 1.0e-9, k_max = 100)
    for _ in 1:k_max
        Δ = pv_ratio(x)
        isfinite(Δ) || return nothing
        x -= Δ
        isfinite(x) || return nothing
        abs(Δ) ≤ ε && return x
    end
    return nothing
end
