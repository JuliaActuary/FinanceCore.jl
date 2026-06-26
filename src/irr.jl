"""
    internal_rate_of_return(cashflows::AbstractVector)::Rate
    internal_rate_of_return(cashflows::AbstractVector, timepoints)::Rate
    internal_rate_of_return(cashflows::Vector{<:Cashflow})::Rate

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
First tries Newton's method (fast). If Newton does not converge, falls back to a robust root-finding search in continuous rate space over `[-5, 3]` (approximately `[-0.993, 19.1]` in periodic rate). When the fallback finds multiple roots, returns the one nearest zero.
"""
function internal_rate_of_return(cashflows::AbstractVector{<:Real})
    # timepoints match the cashflows by construction, so go straight to the solver
    return _solve_irr(cashflows, 0:(length(cashflows) - 1))
end

# `Cashflow`s carry their own timepoints; `times === nothing` is the sentinel that lets
# one solver core serve both representations. Only the innermost kernel (`__pv_div_pv′`)
# specializes on the representation, and it does so in place — no arrays are materialized.
internal_rate_of_return(cashflows::Vector{<:Cashflow}) = _solve_irr(cashflows, nothing)

# Public entry for separate cashflow/timepoint vectors. This is the only path where the
# lengths can disagree, so it's the one place we validate — the @inbounds/@turbo kernels
# assume every cashflow has a timepoint and would read out of bounds otherwise.
function internal_rate_of_return(cashflows, times)
    length(times) >= length(cashflows) ||
        throw(DimensionMismatch("each cashflow needs a timepoint: got $(length(cashflows)) cashflows and $(length(times)) timepoints"))
    return _solve_irr(cashflows, times)
end

# newton's method first (fast); fall back to a robust search if it doesn't converge
function _solve_irr(cashflows, times)
    v = irr_newton(cashflows, times)
    return isnan(rate(v)) ? irr_robust(cashflows, times) : v
end

# Per-element accessors that unify the two cashflow representations without copying:
# either a plain `(cashflows, times)` pair, or a `Vector{<:Cashflow}` whose elements
# carry their own amount/time (signalled by `times === nothing`).
@inline _amt(cashflows, i) = cashflows[i]
@inline _amt(cashflows::AbstractVector{<:Cashflow}, i) = amount(cashflows[i])
@inline _tim(cashflows, times, i) = times[i]
@inline _tim(cashflows::AbstractVector{<:Cashflow}, ::Nothing, i) = timepoint(cashflows[i])

function irr_robust(cashflows, times = nothing)
    # IRR is scale-invariant; normalizing keeps f(r) in O(1) range
    # so that find_zeros can reliably distinguish roots from noise.
    M = maximum(i -> abs(_amt(cashflows, i)), eachindex(cashflows))
    iszero(M) && return nothing
    # operate in continuous rate space to avoid the singularity at i = -1
    # in periodic space (where (1+i)^t is undefined for fractional t)
    f(r) = sum(_amt(cashflows, i) / M * exp(-r * _tim(cashflows, times, i)) for i in eachindex(cashflows))
    roots = Roots.find_zeros(f, -5.0, 3.0)

    # short circuit and return nothing if no roots found
    isempty(roots) && return nothing
    # find the root nearest zero and convert back to periodic rate
    return Periodic(exp(roots[argmin(abs.(roots))]) - 1, 1)
end

function irr_newton(cashflows, times = nothing)
    # use newton's method with hand-coded derivative
    r = __newtons_method1D_irr(cashflows, times, 0.001, 1.0e-9, 100)
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
# `times === nothing` signals a `Vector{<:Cashflow}` input.
__pv_div_pv′(r, cashflows, times = nothing) = __pv_div_pv′(VECTORIZATION_BACKEND[], r, cashflows, times)

# Base @simd implementation. A single method serves both cashflow representations via
# the `_amt`/`_tim` accessors, which inline away with no @simd penalty and no
# allocations. (The @turbo extension keeps two inline kernels instead — LoopVectorization
# macro-expands the loop body before inlining, so it can't see through the accessors.)
function __pv_div_pv′(::SimdBackend, r, cashflows, times)
    n = 0.0
    d = 0.0
    @inbounds @simd for i in eachindex(cashflows)
        cf = _amt(cashflows, i)
        t = _tim(cashflows, times, i)
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
