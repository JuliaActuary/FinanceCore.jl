"""
    internal_rate_of_return(cashflows::AbstractVector)::Union{Periodic, Nothing}
    internal_rate_of_return(cashflows::AbstractVector, timepoints)::Union{Periodic, Nothing}
    internal_rate_of_return(cashflows::Vector{<:Cashflow})::Union{Periodic, Nothing}

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
First tries Newton's method (fast). If Newton does not converge, falls back to a robust root-finding search in continuous rate space over [-5, 3] (approximately [-0.993, 19.1] in periodic rate). When the fallback finds multiple roots, returns the one nearest zero.
"""
function internal_rate_of_return(cashflows::AbstractVector{<:Real})
    return internal_rate_of_return(cashflows, 0:(length(cashflows) - 1))
end

function internal_rate_of_return(cashflows::Vector{C}) where {C <: Cashflow}
    # first try to quickly solve with newton's method, otherwise
    # revert to a more robust method

    v = irr_newton(cashflows)

    if isnan(rate(v))
        return irr_robust(cashflows)
    else
        return v
    end
end

function internal_rate_of_return(cashflows, times)
    # first try to quickly solve with newton's method, otherwise
    # revert to a more robust method

    v = irr_newton(cashflows, times)

    if isnan(rate(v))
        return irr_robust(cashflows, times)
    else
        return v
    end
end

irr_robust(cashflows) = irr_robust(cashflows, 0:(length(cashflows) - 1))

function irr_robust(cashflows, times)
    # IRR is scale-invariant; normalizing keeps f(r) in O(1) range
    # so that find_zeros can reliably distinguish roots from noise.
    M = maximum(abs, cashflows)
    iszero(M) && return nothing
    isfinite(M) || return nothing
    normalized = cashflows ./ M
    f(r) = sum(cf * exp(-r * t) for (cf, t) in zip(normalized, times))
    # operate in continuous rate space to avoid the singularity at i = -1
    # in periodic space (where (1+i)^t is undefined for fractional t)
    roots = Roots.find_zeros(f, -5.0, 3.0)

    # short circuit and return nothing if no roots found
    isempty(roots) && return nothing
    # find the root nearest zero and convert back to periodic rate
    min_i = argmin(abs.(roots))
    return Periodic(Continuous(roots[min_i]), 1)

end

function irr_robust(cashflows::Vector{C}) where {C <: Cashflow}
    M = maximum(cf -> abs(amount(cf)), cashflows)
    iszero(M) && return nothing
    f(r) = sum(amount(cf) / M * exp(-r * timepoint(cf)) for cf in cashflows)
    roots = Roots.find_zeros(f, -5.0, 3.0)

    # short circuit and return nothing if no roots found
    isempty(roots) && return nothing
    # find the root nearest zero and convert back to periodic rate
    min_i = argmin(abs.(roots))
    return Periodic(exp(roots[min_i]) - 1, 1)

end


function irr_newton(cashflows, times)
    if length(cashflows) > length(times)
        throw(ArgumentError("more cashflows ($(length(cashflows))) than timepoints ($(length(times)))"))
    end
    # use newton's method with hand-coded derivative
    r = __newtons_method1D_irr(
        cashflows,
        times,
        0.001,
        1.0e-9,
        100
    )
    return Periodic(Continuous(r), 1)

end

function irr_newton(cashflows::Vector{C}) where {C <: Cashflow}
    # use newton's method with hand-coded derivative
    r = __newtons_method1D_irr(
        cashflows,
        0.001,
        1.0e-9,
        100
    )
    return Periodic(exp(r) - 1, 1)

end

# Backend trait for vectorization strategy
abstract type VectorizationBackend end
struct SimdBackend <: VectorizationBackend end
struct TurboBackend <: VectorizationBackend end

# Global backend setting - extensions can change this
const VECTORIZATION_BACKEND = Ref{VectorizationBackend}(SimdBackend())

# an internal function which calculates the
# present value and it's derivative in one pass
# for use in newton's method
#
# Dispatches to the appropriate backend. When LoopVectorization
# is loaded, the extension sets VECTORIZATION_BACKEND to TurboBackend()
# and provides a faster @turbo-based implementation.
function __pv_div_pv′(r, cashflows, times)
    return __pv_div_pv′(VECTORIZATION_BACKEND[], r, cashflows, times)
end

function __pv_div_pv′(r, cashflows::Vector{C}) where {C <: Cashflow}
    return __pv_div_pv′(VECTORIZATION_BACKEND[], r, cashflows)
end

# Base @simd implementation
function __pv_div_pv′(::SimdBackend, r, cashflows, times)
    n = 0.0
    d = 0.0
    @inbounds @simd for i in eachindex(cashflows)
        cf = cashflows[i]
        t = times[i]
        a = cf * exp(-r * t)
        n += a
        d += a * -t
    end
    return n / d
end

function __pv_div_pv′(::SimdBackend, r, cashflows::Vector{C}) where {C <: Cashflow}
    n = 0.0
    d = 0.0
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
irr = internal_rate_of_return

# modified from
# Algorithms for Optimization, Mykel J. Kochenderfer and Tim A. Wheeler, pg 88
function __newtons_method1D_irr(cashflows, times, x, ε, k_max)
    k = 1
    Δ = Inf
    while abs(Δ) > ε && k ≤ k_max
        # @show x,H(x),  ∇f(x)
        Δ = __pv_div_pv′(x, cashflows, times)
        x -= Δ
        k += 1
    end
    return x
end

function __newtons_method1D_irr(cashflows::Vector{C}, x, ε, k_max) where {C <: Cashflow}
    k = 1
    Δ = Inf
    while abs(Δ) > ε && k ≤ k_max
        # @show x,H(x),  ∇f(x)
        Δ = __pv_div_pv′(x, cashflows)
        x -= Δ
        k += 1
    end
    return x
end
