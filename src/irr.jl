"""
    internal_rate_of_return(cashflows::vector)::Rate
    internal_rate_of_return(cashflows::Vector, timepoints::Vector)::Rate
    
Calculate the internal_rate_of_return with given timepoints. If no timepoints given, will assume that a series of equally spaced cashflows, assuming the first cashflow occurring at time zero and subsequent elements at time 1, 2, 3, ..., n. 

Returns a Rate type with periodic compounding once per period (e.g. annual effective if the `timepoints` given represent years). Get the scalar rate by calling `Yields.rate()` on the result.

# Example
```julia-repl
julia> internal_rate_of_return([-100,110],[0,1]) # e.g. cashflows at time 0 and 1
0.10000000001652906
julia> internal_rate_of_return([-100,110]) # implied the same as above
0.10000000001652906
```

# Solver notes
Will try to return a root within the range [-2,2]. If the fast solver does not find one matching this condition, then a more robust search will be performed over the [.99,2] range.

The solution returned will be in the range [-2,2], but may not be the one nearest zero. For a slightly slower, but more robust version, call `ActuaryUtilities.irr_robust(cashflows,timepoints)` directly.
"""
function internal_rate_of_return(cashflows::AbstractVector{<:Real})
    return internal_rate_of_return(cashflows, 0:(length(cashflows) - 1))
end

function internal_rate_of_return(cashflows)
    throw(ArgumentError("cashflows must be a vector of Real numbers, got $(typeof(cashflows))"))
end

function internal_rate_of_return(cashflows::Vector{C}) where {C <: Cashflow}
    # first try to quickly solve with newton's method, otherwise
    # revert to a more robust method

    v = irr_newton(cashflows)

    lower, upper = -2.0, 2.0
    r = rate(v)
    if isnan(r) || (r >= upper && r <= lower)
        return irr_robust(cashflows)
    else
        return v
    end
end

function internal_rate_of_return(cashflows, times)
    # first try to quickly solve with newton's method, otherwise
    # revert to a more robust method

    v = irr_newton(cashflows, times)

    lower, upper = -2.0, 2.0
    r = rate(v)
    if isnan(r) || (r >= upper && r <= lower)
        return irr_robust(cashflows, times)
    else
        return v
    end
end

irr_robust(cashflows) = irr_robust(cashflows, 0:(length(cashflows) - 1))

function irr_robust(cashflows, times)
    f(i) = sum(cf / (1 + i)^t for (cf, t) in zip(cashflows, times))
    # lower bound at -.99 because otherwise we can start taking the root of a negative number
    # when a time is fractional.
    roots = Roots.find_zeros(f, -0.99, 2)

    # short circuit and return nothing if no roots found
    isempty(roots) && return nothing
    # find and return the one nearest zero
    min_i = argmin(roots)
    return Periodic(roots[min_i], 1)

end

function irr_robust(cashflows::Vector{C}) where {C <: Cashflow}
    f(i) = sum(amount(cf) / (1 + i)^timepoint(t) for (cf, t) in cashflows)
    # lower bound at -.99 because otherwise we can start taking the root of a negative number
    # when a time is fractional.
    roots = Roots.find_zeros(f, -0.99, 2)

    # short circuit and return nothing if no roots found
    isempty(roots) && return nothing
    # find and return the one nearest zero
    min_i = argmin(roots)
    return Periodic(roots[min_i], 1)

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
    return Periodic(exp(r) - 1, 1)

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
