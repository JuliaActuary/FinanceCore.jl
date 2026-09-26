"""
    internal_rate_of_return(cashflows::AbstractVector)::Rate
    internal_rate_of_return(cashflows::AbstractVector, timepoints)::Rate
    internal_rate_of_return(cashflows::AbstractVector{<:Cashflow})::Rate

Calculate the internal rate of return with given timepoints. If no timepoints given, assumes equally spaced cashflows starting at time zero (0, 1, 2, ..., n).

Returns a `Periodic(rate, 1)` `Rate`, or `nothing` if no root is found. Get the scalar rate by calling `rate()` on the result.

An empty collection of cashflows, like an all-zero one, returns `nothing`: there is no
identifiable IRR, since every rate solves an identically zero pricing equation.

# Example
```julia-repl
julia> internal_rate_of_return([-100,110],[0,1]) # e.g. cashflows at time 0 and 1
Periodic(0.1, 1)
julia> internal_rate_of_return([-100,110]) # implied the same as above
Periodic(0.1, 1)
```

# Solver notes
First tries Newton's method (fast). If Newton does not converge, falls back to a robust root-finding search in continuous rate space over `[-5, 3]` (approximately `[-0.993, 19.1]` in periodic rate). Fallback roots are residual-validated; when multiple roots remain, returns the one nearest zero.

# Derivatives
First-order ForwardDiff derivatives with respect to the cashflows or timepoints are supported. Both stages solve on primal (non-dual) values, and one implicit-function step then gives the root its partials, `dr = -(∂g/∂θ) / (∂g/∂r)` for the pricing residual `g`; the value is the primal IRR exactly. This is a first-order capability: nested dual numbers (for example `ForwardDiff.hessian`) throw an `ArgumentError`, as does a root whose derivative vanishes (a repeated root), where the sensitivity is undefined.
"""
function internal_rate_of_return(cashflows::AbstractVector{<:Real})
    return internal_rate_of_return(cashflows, 0:(length(cashflows) - 1))
end

function internal_rate_of_return(cashflows::AbstractVector{<:Cashflow})
    flows = ((amount(cf), timepoint(cf)) for cf in cashflows)
    if _ad_depth_flows(flows) > 0
        primal = [Cashflow(_primal(amount(cf)), _primal(timepoint(cf))) for cf in cashflows]
        r0 = _irr_force(r -> __pv_div_pv′(r, primal), ((amount(cf), timepoint(cf)) for cf in primal))
        return _irr_dual(r0, flows)
    end
    return _irr(r -> __pv_div_pv′(r, cashflows), flows)
end

function internal_rate_of_return(cashflows, times)
    @assert length(cashflows) <= length(times)
    flows = zip(cashflows, times)
    if _ad_depth_flows(flows) > 0
        pcfs, ptimes = _primal_values(cashflows), _primal_values(times)
        r0 = _irr_force(r -> __pv_div_pv′(r, pcfs, ptimes), zip(pcfs, ptimes))
        return _irr_dual(r0, flows)
    end
    return _irr(r -> __pv_div_pv′(r, cashflows, times), flows)
end

# The input adapters are lazy: Newton keeps its representation-specific kernel,
# while fallback policy operates on the same (amount, time) stream for both forms.
function _irr(pv_ratio::F, flows) where {F}
    r = _irr_force(pv_ratio, flows)
    return isnothing(r) ? nothing : _periodic_from_force(r)
end

function _irr_force(pv_ratio::F, flows) where {F}
    r = _irr_newton(pv_ratio)
    isnothing(r) && (r = _irr_robust(flows))
    return r
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
    # Exact-zero amounts contribute nothing at any rate, but they would still set the
    # time origin below, and a zero term far from that origin evaluates as 0 * Inf.
    nonzero = Iterators.filter(p -> !iszero(first(p)), flows)
    # Cashflows with only one sign cannot have a finite IRR. Keep this scan on
    # the fallback path so ordinary Newton-convergent calls do not pay for it.
    has_positive = any(p -> first(p) > 0, nonzero)
    has_negative = any(p -> first(p) < 0, nonzero)
    has_positive && has_negative || return nothing

    # Scaling amounts and shifting the time origin preserve roots and prevent
    # overflow/underflow from obscuring the residual. Both the root search and
    # its acceptance check use the same discounted terms.
    M, t0 = _irr_scale_origin(nonzero)
    terms(r) = (cf / M * exp(-r * (t - t0)) for (cf, t) in nonzero)
    # Continuous-rate space avoids the periodic singularity at i = -1.
    roots = Roots.find_zeros(r -> sum(terms(r)), -5.0, 3.0)
    filter!(r -> _is_irr_root(r, terms(r)), roots)
    return isempty(roots) ? nothing : argmin(abs, roots)
end

_irr_scale_origin(flows) = (maximum(p -> abs(first(p)), flows), minimum(last, flows))

# Dual-number hooks, defined for ForwardDiff by FinanceCoreForwardDiffExt: `_primal` strips
# every dual layer, `_ad_depth` counts the layers, and `_is_exact_zero` also requires zero
# partials (ForwardDiff 0.10's `iszero` looks at the value only). Plain numbers have no layers.
_primal(x) = x
_ad_depth(::Type) = 0
_ad_depth(x) = _ad_depth(typeof(x))
_is_exact_zero(x) = iszero(x)

# Dual layers in any amount or time of an IRR input (0 for plain numbers).
_ad_depth_flows(flows) = maximum(p -> max(_ad_depth(first(p)), _ad_depth(last(p))), flows; init = 0)
# A copy without dual partials, or the input itself when it has none (so that, for example, a
# range of timepoints keeps the solver's range kernel).
_primal_values(v) = all(x -> _ad_depth(x) == 0, v) ? v : map(_primal, v)

# The root of dual inputs: `r0` solves their primal values (through both solver stages), and one
# implicit-function step gives it first-order partials. A zero amount that carries partials still
# enters that step; exact zeros are dropped, as in the fallback, since a zero term far from the
# time origin would evaluate as 0 * Inf.
function _irr_dual(r0, flows)
    isnothing(r0) && return nothing
    nonzero = Iterators.filter(p -> !_is_exact_zero(first(p)), flows)
    M, t0 = _irr_scale_origin(Iterators.filter(p -> !iszero(first(p)), ((_primal(cf), _primal(t)) for (cf, t) in nonzero)))
    return _periodic_from_force(_irr_implicit(r0, nonzero, M, t0))
end

# `r0` solves the primal residual, so it carries no partials. One implicit-function step
# `r0 - (g - primal(g)) / g′` gives it the first-order partials `dr = -(∂g/∂θ) / (∂g/∂r)` while
# keeping the value `r0` exactly: `g` is the residual scaled by `M` and shifted to the time origin
# `t0`, evaluated at `r0` with the dual inputs, and `g′` its primal derivative in the rate. Nested
# duals and a slope that vanishes relative to the size of its terms (as at a repeated root) throw
# rather than return wrong partials.
function _irr_implicit(r0, flows, M, t0)
    g = sum(cf / M * exp(-r0 * (t - t0)) for (cf, t) in flows)
    _ad_depth(g) == 1 || throw(
        ArgumentError(
            "internal_rate_of_return supports first-order ForwardDiff derivatives only; " *
                "nested dual numbers are not supported"
        )
    )
    slope = zero(r0)
    scale = zero(r0)
    for (cf, t) in flows
        τ = _primal(t) - t0
        term = _primal(cf) / M * τ * exp(-r0 * τ)
        slope -= term
        scale += abs(term)
    end
    (isfinite(slope) && abs(slope) > sqrt(eps(typeof(r0))) * scale) || throw(
        ArgumentError(
            "internal_rate_of_return has a vanishing or non-finite derivative at the solution " *
                "($slope); its sensitivity is undefined"
        )
    )
    return r0 - (g - _primal(g)) / slope
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
