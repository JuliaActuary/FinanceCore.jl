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
ForwardDiff derivatives of any order with respect to the cashflows or timepoints are supported, including nested dual numbers (for example `ForwardDiff.hessian`). Both stages solve on primal (non-dual) values. Implicit-function steps `r ← r - (g(r) - g₀) / g′` for the pricing residual `g`, where `g₀` is its primal value and `g′` its primal slope at the root, then give the root its partials: the first gives `dr = -(∂g/∂θ) / (∂g/∂r)`, and each step adds one order, so one step per dual layer suffices. The value is the primal IRR exactly. A root whose derivative vanishes (a repeated root) throws an `ArgumentError`, since its sensitivity is undefined.
"""
function internal_rate_of_return(cashflows::AbstractVector{<:Real})
    return internal_rate_of_return(cashflows, 0:(length(cashflows) - 1))
end

internal_rate_of_return(cashflows::AbstractVector{<:Cashflow}) = _irr(cashflows, nothing)

function internal_rate_of_return(cashflows, times)
    @assert length(cashflows) <= length(times)
    return _irr(cashflows, times)
end

# An IRR input is amounts with their times, or Cashflows, which carry their own (`times` is then
# `nothing`). `_flow` reads the amount and time of flow `i` in either form, so the solvers are shared.
Base.@propagate_inbounds _flow(cashflows, times, i) = (cashflows[i], times[i])
Base.@propagate_inbounds _flow(cashflows, ::Nothing, i) = (amount(cashflows[i]), timepoint(cashflows[i]))
_flows(cashflows, times) = (_flow(cashflows, times, i) for i in eachindex(cashflows))

# Dual inputs are solved on their primal values, and implicit-function steps give the root its
# partials (see `_irr_implicit`).
function _irr(cashflows, times)
    flows = _flows(cashflows, times)
    if _ad_depth_flows(flows) > 0
        pcfs, ptimes = _primal_values(cashflows), _primal_values(times)
        r0 = _irr_force(pcfs, ptimes)
        isnothing(r0) && return nothing
        return _periodic_from_force(_irr_implicit(r0, flows, _flows(pcfs, ptimes)))
    end
    r = _irr_force(cashflows, times)
    return isnothing(r) ? nothing : _periodic_from_force(r)
end

# The primal solve, as a force of interest: Newton from the first nonzero amount's time, then the
# robust solver. An empty or all-zero stream has no identifiable IRR, since every rate solves its
# identically zero pricing equation.
function _irr_force(cashflows, times)
    flows = _flows(cashflows, times)
    nonzero = _nonzero(flows)
    isempty(nonzero) && return nothing
    r = _irr_newton(cashflows, times, last(first(nonzero)))
    isnothing(r) && (r = _irr_robust(flows))
    return r
end

# Exact-zero amounts contribute nothing at any rate, so they neither set a solver's time origin nor
# enter the fallback's terms, where a zero far from the origin would evaluate as 0 * Inf.
_nonzero(flows) = Iterators.filter(p -> !iszero(first(p)), flows)

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
    nonzero = _nonzero(flows)
    # Cashflows with only one sign cannot have a finite IRR. Keep this scan on
    # the fallback path so ordinary Newton-convergent calls do not pay for it.
    has_positive = any(p -> first(p) > 0, nonzero)
    has_negative = any(p -> first(p) < 0, nonzero)
    has_positive && has_negative || return nothing

    # Scaling amounts and shifting the time origin preserve roots and prevent
    # overflow/underflow from obscuring the residual. Both the root search and
    # its acceptance check use the same discounted terms.
    M, t0 = _irr_scale_origin(nonzero)
    terms(r) = (cf / M * exp(-r * _elapsed(t, t0)) for (cf, t) in nonzero)
    # Continuous-rate space avoids the periodic singularity at i = -1.
    roots = Roots.find_zeros(r -> sum(terms(r)), -5.0, 3.0)
    filter!(r -> _is_irr_root(r, terms(r)), roots)
    return isempty(roots) ? nothing : argmin(abs, roots)
end

_irr_scale_origin(flows) = (maximum(p -> abs(first(p)), flows), minimum(last, flows))

# The time from the origin `t0`, exact until a single rounding. Integer times are differenced in the
# unsigned type of their width, the larger minus the smaller, and converted to floating point once:
# in their own type the subtraction or a kernel's negation can wrap (an unsigned time before the
# origin, a narrow signed span), and converting each endpoint first rounds times beyond 2^53. Other
# times subtract in their own type.
_elapsed(t, t0) = t - t0
_elapsed(t::Integer, t0::Integer) = _integer_elapsed(promote(t, t0)...)
_integer_elapsed(t::T, t0::T) where {T <: Base.BitInteger} =
    t >= t0 ? float(unsigned(t) - unsigned(t0)) : -float(unsigned(t0) - unsigned(t))
_integer_elapsed(t, t0) = float(t - t0)

# Dual-number hooks, defined for ForwardDiff by FinanceCoreForwardDiffExt: `_primal` strips
# every dual layer, `_ad_depth` counts the layers, and `_is_exact_zero` also requires zero
# partials (ForwardDiff 0.10's `iszero` looks at the value only). Plain numbers have no layers.
_primal(x) = x
_ad_depth(::Type) = 0
_ad_depth(x) = _ad_depth(typeof(x))
_is_exact_zero(x) = iszero(x)

_primal(cf::Cashflow) = Cashflow(_primal(amount(cf)), _primal(timepoint(cf)))

# Dual layers in any amount or time of an IRR input (0 for plain numbers).
_ad_depth_flows(flows) = maximum(p -> max(_ad_depth(first(p)), _ad_depth(last(p))), flows; init = 0)
# A copy without dual partials, or the input itself when its concrete element type has none (so
# that, for example, a range of timepoints keeps the solver's range kernel). The element type
# decides, so the result's type is inferable. Cashflows are always copied: they are then the whole
# input, so they carry the partials (and a concrete `Cashflow{Real, Real}` can still hold dual
# numbers). Their times are `nothing`.
_primal_values(v) = isconcretetype(eltype(v)) && _ad_depth(eltype(v)) == 0 ? v : map(_primal, v)
_primal_values(cashflows::AbstractVector{<:Cashflow}) = map(_primal, cashflows)
_primal_values(::Nothing) = nothing

# `r0` solves the primal residual of the dual `flows`, whose primal values are `primal_flows`, so it
# carries no partials. The implicit-function step `r - (g(r) - g₀) / g′` gives it the first-order
# partials `dr = -(∂g/∂θ) / (∂g/∂r)`, where `g` is the residual scaled by `M` and shifted to the
# time origin `t0` with the dual inputs, `g₀` its primal value at `r0` and `g′` its primal slope
# there. Repeating the step with the dual iterate corrects one more order each time, so one step per
# dual layer gives the partials of nested duals (a Hessian takes two); every step keeps the value
# `r0` exactly. Exact zeros are dropped, as in the fallback. A zero amount that carries partials
# still enters the steps, but not the time origin, the scale or the slope, which use the primal
# nonzero amounts: a zero far from the origin contributes no slope. Each term `cf⋅exp(-r⋅τ)/M` takes
# the scale where it can't overflow: on the amount first, since for a tiny notional
# `exp(-log(M))` alone exceeds floatmax, or in the exponent when `exp(-r⋅τ)` already overflows, as
# for a zero amount far before the origin. The form is chosen from primal values, so every step
# evaluates the same one. A slope that vanishes relative to the size of its terms (as at a
# repeated root) throws rather than return wrong partials.
function _irr_implicit(r0, flows, primal_flows)
    nonzero = _nonzero(primal_flows)
    M, t0 = _irr_scale_origin(nonzero)
    logM = log(M)
    # exp(x) is finite below log(floatmax)
    finite_below = log(floatmax(typeof(r0)))
    term(cf, τ, r) = -r0 * _primal(τ) < finite_below ? cf / M * exp(-r * τ) : cf * exp(-r * τ - logM)
    g(r) = sum(term(cf, _elapsed(t, t0), r) for (cf, t) in flows if !_is_exact_zero(cf))
    slope = zero(r0)
    scale = zero(r0)
    for (a, t) in nonzero
        τ = _elapsed(t, t0)
        x = τ * term(a, τ, r0)
        slope -= x
        scale += abs(x)
    end
    (isfinite(slope) && abs(slope) > sqrt(eps(typeof(r0))) * scale) || throw(
        ArgumentError(
            "internal_rate_of_return has a vanishing or non-finite derivative at the solution " *
                "($slope); its sensitivity is undefined"
        )
    )
    g_r0 = g(r0)
    g₀ = _primal(g_r0)
    r = r0 - (g_r0 - g₀) / slope
    for _ in 2:_ad_depth(g_r0)
        r -= (g(r) - g₀) / slope
    end
    return r
end

# Backend trait for vectorization strategy
abstract type VectorizationBackend end
struct SimdBackend <: VectorizationBackend end
struct TurboBackend <: VectorizationBackend end

_vectorization_backend(r, cashflows, times) = SimdBackend()

# an internal function which calculates the
# present value and it's derivative in one pass
# for use in newton's method, with times measured from the origin `t0` (see `_irr_newton`)
#
# Dispatches to the appropriate backend based on the input types. The
# LoopVectorization extension opts supported dense floating-point arrays into its
# turbo kernel without changing process-global state.
function __pv_div_pv′(r, cashflows, times, t0)
    return __pv_div_pv′(_vectorization_backend(r, cashflows, times), r, cashflows, times, t0)
end

# Newton's step from a kernel's sums. A derivative sum that overflowed, or underflowed into the
# subnormals, has lost its precision: huge amounts make it infinite and the step 0, and tiny amounts
# far from time zero leave a ratio of a few bits, either of which Newton would accept as a root.
# NaN stops Newton, and the robust solver, which scales the amounts, solves instead.
_newton_step(n, d) = isfinite(d) && abs(d) >= floatmin(_primal(d)) ? n / d : oftype(n / d, NaN)

# The element types of the amounts and the times.
_flow_types(cashflows, times) = (eltype(cashflows), eltype(times))
_flow_types(::AbstractVector{Cashflow{A, T}}, ::Nothing) where {A, T} = (A, T)
_flow_types(cashflows, ::Nothing) = (Any, Any)

# The sums take the type of the terms, or the rate's when an abstract element type (`Any[]`, a
# vector of mixed Cashflows) doesn't determine it.
function _irr_accumulator_type(r, ::Type{A}, ::Type{T}) where {A, T}
    S = promote_type(typeof(r), A, T)
    return isconcretetype(S) ? S : typeof(r)
end

# Base @simd implementation
function __pv_div_pv′(::SimdBackend, r, cashflows, times, t0)
    S = _irr_accumulator_type(r, _flow_types(cashflows, times)...)
    n = zero(S)
    d = zero(S)
    @inbounds @simd for i in eachindex(cashflows)
        cf, τ = _flow(cashflows, times, i)
        t = _elapsed(τ, t0)
        a = cf * exp(-r * t)
        n += a
        d += a * -t
    end
    return _newton_step(n, d)
end

"""
    irr(cashflows::vector)
    irr(cashflows::Vector, timepoints::Vector)

An alias for [`internal_rate_of_return`](@ref).
"""
const irr = internal_rate_of_return

# Newton's method on Σ cf⋅exp(-r⋅(t - t0)) = 0, which has the roots of the pricing equation (the
# factor exp(r⋅t0) is positive). With the origin `t0` at the first nonzero amount's time, flows far
# from time 0 converge as the same flows near it do; measured from time 0, flows that are all near
# t = 1000 move Newton by about 1/1000 per step, and it runs out of iterations. For flows that
# start at time 0 the origin is 0, and the arithmetic is unchanged.
# Modified from Algorithms for Optimization, Kochenderfer and Wheeler, p. 88.
function _irr_newton(cashflows, times, t0, x = 0.001, ε = 1.0e-9, k_max = 100)
    for _ in 1:k_max
        Δ = __pv_div_pv′(x, cashflows, times, t0)
        isfinite(Δ) || return nothing
        x -= Δ
        isfinite(x) || return nothing
        abs(Δ) ≤ ε && return x
    end
    return nothing
end
