# Generic methods derived from `factor`. The abstract type and `factor` /
# `intensity` generic functions are forward-declared in `FinanceCore.jl` so
# that `Rates.jl` can attach `Rate <: AbstractDeflator` and define methods
# for Rate before this file is included.

# ─── Generic plumbing onto `factor` ───────────────────────────────────────────
#
# Every deflator gets `discount`, `accumulation`, `forward`, and the
# actuarial-overload `Base.zero` (= spot rate, NOT additive identity) as a
# free derived API once it provides `factor`.

discount(p::AbstractDeflator, t)            = factor(p, t)
discount(p::AbstractDeflator, from, to)     = factor(p, from, to)
accumulation(p::AbstractDeflator, t)        = inv(factor(p, t))
accumulation(p::AbstractDeflator, from, to) = inv(factor(p, from, to))

"""
    forward(p::AbstractDeflator, from, to)

The continuously-compounded forward zero rate of `p` over `[from, to]`,
returned as a `Continuous` [`Rate`](@ref). Defined as
`-log(factor(p, from, to)) / (to - from)`.

For a constant-force `Rate`, this is just the rate itself (preserved by a
more-specific method on `Rate` that retains the original periodicity). For
a yield curve, this is the implied forward rate between the two dates.

Generic via `factor`, so any `AbstractDeflator` that implements the required
two-argument `factor(p, from, to)` gets a working `forward`.

# Examples

```julia-repl
julia> r = Continuous(0.03);

julia> forward(r, 1, 6)              # constant-force Rate: returns the rate itself
Continuous(0.03)

julia> c = compose(Continuous(0.03), Continuous(0.012));

julia> forward(c, 1, 6)              # composite: sum of component forces
Continuous(0.042)
```
"""
forward(p::AbstractDeflator, from, to) = Continuous(-log(factor(p, from, to)) / (to - from))

"""
    Base.zero(p::AbstractDeflator, t)

The continuously-compounded **zero rate** (spot rate) of `p` at time `t`,
returned as a `Continuous` [`Rate`](@ref). Defined as
`-log(factor(p, t)) / t`.

!!! note "Actuarial overload of Base.zero"
    This is the established FinanceCore / FinanceModels convention:
    `Base.zero(p, t)` is the spot rate (the constant continuous force that,
    applied uniformly over `[0, t]`, would produce the same `factor(p, t)`).
    It is **not** the additive-identity meaning of `Base.zero(x)`. The
    two-argument form disambiguates by signature.

Only meaningful for subtypes that define the single-argument `factor(p, t)`
(origin-invariant subtypes). Mortality/lapse/default tables indexed by
absolute age don't define single-arg `factor`, so `zero(table, t)` raises
`MethodError` cleanly.

# Examples

```julia-repl
julia> r = Continuous(0.03);

julia> zero(r, 5)                    # constant-force Rate: returns the rate itself
Continuous(0.03)

julia> c = compose(Continuous(0.03), Continuous(0.012));

julia> zero(c, 5)                    # composite spot rate: sum of component forces
Continuous(0.042)
```
"""
Base.zero(p::AbstractDeflator, t) = Continuous(-log(factor(p, t)) / t)

# ─── Composites ───────────────────────────────────────────────────────────────

"""
    CompositeDeflator(components::Tuple)

A composite of independent `AbstractDeflator`s. The composite's `factor` is the
product of component factors; its `intensity` is the sum of component
intensities (when all components support `intensity`).

Constructed via [`compose`](@ref), which flattens nested composites for a
type-stable, statically-dispatched product. The tuple representation gives
zero-allocation hot paths when the composite shape is fixed at compile time.

For composites whose shape varies at runtime (e.g. Monte Carlo with
scenario-dependent components), use [`DynamicCompositeDeflator`](@ref)
constructed via [`dynamic_composite`](@ref).

Composition assumes **independence**: see [`AbstractDeflator`](@ref) for
correlated alternatives.

!!! warning "Single-arg `factor(c, t)` requires axis agreement"
    The single-argument form `factor(c::CompositeDeflator, t)` returns
    `prod(factor(comp, t) for comp in components)`. This is only meaningful
    when **every component agrees on what `t = 0` means**. Mixing a
    years-from-valuation component (origin-invariant `Rate`, pre-sliced
    yield curve) with an absolute-axis component (age-indexed mortality
    table, calendar-dated curve) silently produces wrong numbers — each
    component answers "factor over `[0, t]`" using its own origin.

    The fix is the same as the forward-vs-spot footgun in
    [`AbstractDeflator`](@ref): pre-slice age/calendar-indexed components
    so they share a years-from-valuation axis with the rest of the
    composite. When in doubt, use the two-argument form `factor(c, from, to)`
    with explicit endpoints — it is unambiguous regardless of component
    conventions.
"""
struct CompositeDeflator{T <: Tuple} <: AbstractDeflator
    components::T
end

"""
    DynamicCompositeDeflator(components::AbstractVector)

Vector-backed composite. Trades static dispatch for compile-time stability
when the composite shape varies at runtime. Use [`dynamic_composite`](@ref)
to construct.

`factor` is `mapreduce(comp -> factor(comp, from, to), *, components)` — no
`init` value, so the fold uses the first element's type, preserving autodiff
duals and `BigFloat` element types. Empty composites raise from `mapreduce`.
"""
struct DynamicCompositeDeflator{V <: AbstractVector} <: AbstractDeflator
    components::V
end

"""
    components(c::CompositeDeflator)
    components(c::DynamicCompositeDeflator)

The components of a composite deflator (a tuple or vector). Useful for
debugging and for downstream code that walks the composition tree.
"""
components(c::CompositeDeflator)        = c.components
components(c::DynamicCompositeDeflator) = c.components

# factor for composites
function factor(c::CompositeDeflator, from, to)
    return prod(factor(comp, from, to) for comp in c.components)
end

function factor(c::DynamicCompositeDeflator, from, to)
    return mapreduce(comp -> factor(comp, from, to), *, c.components)
end

# Single-arg factor: only sensible if all components have origin-invariant
# semantics. Inherited via the same prod/mapreduce — components that lack
# single-arg factor will MethodError, which is the right behavior.
function factor(c::CompositeDeflator, t)
    return prod(factor(comp, t) for comp in c.components)
end

function factor(c::DynamicCompositeDeflator, t)
    return mapreduce(comp -> factor(comp, t), *, c.components)
end

# intensity for composites: sum of component intensities (chain rule on
# log(factor) = Σ log(factor_i) for the independent product). Only valid
# when every component supports `intensity` — otherwise MethodError, which
# correctly catches mixed continuous + discrete composites.
function intensity(c::CompositeDeflator, t)
    return sum(intensity(comp, t) for comp in c.components)
end

function intensity(c::DynamicCompositeDeflator, t)
    return mapreduce(comp -> intensity(comp, t), +, c.components)
end

# ─── Constructors ─────────────────────────────────────────────────────────────

"""
    compose(args::AbstractDeflator...)

Compose deflators into a [`CompositeDeflator`](@ref). The composite's `factor`
is the product of the components' factors — this assumes the components are
**independent**.

Nested composites are flattened, so `compose(compose(a, b), c)` and
`compose(a, compose(b, c))` both produce a single `CompositeDeflator` with
three components. This keeps the type stable across associativity and avoids
unnecessary tuple nesting.

# Examples

```julia-repl
julia> i = Continuous(0.04);          # 4% interest force

julia> μ = Continuous(0.012);         # 1.2% default hazard force

julia> deflator = compose(i, μ);      # zero-recovery defaultable discount

julia> discount(deflator, 5) ≈ exp(-0.052 * 5)
true

julia> intensity(deflator, 1.0) ≈ 0.052
true
```

For composites whose shape varies at runtime (e.g. Monte Carlo where each
scenario produces a different number of components), use
[`dynamic_composite`](@ref) instead.
"""
compose() = throw(ArgumentError("compose requires at least one AbstractDeflator"))
compose(p::AbstractDeflator) = p
function compose(args::AbstractDeflator...)
    return CompositeDeflator(_flatten(args))
end

# Flatten any CompositeDeflators in the args. Recursive single-pass; tuple
# operations are statically resolvable so this stays type-stable.
#
# The splat-recursion is type-stable for small N (~16 components, comfortably
# above the realistic actuarial 4-decrement ceiling). Composites built from
# vastly larger numbers of components should use `dynamic_composite` to avoid
# specialization blow-up.
_flatten(args::Tuple) = _flatten_impl((), args...)
_flatten_impl(acc::Tuple) = acc
_flatten_impl(acc::Tuple, c::CompositeDeflator, rest...) =
    _flatten_impl((acc..., c.components...), rest...)
_flatten_impl(acc::Tuple, x::AbstractDeflator, rest...) =
    _flatten_impl((acc..., x), rest...)

"""
    dynamic_composite(components::AbstractVector{<:AbstractDeflator})

Build a [`DynamicCompositeDeflator`](@ref) from a vector. Use this when the
composite shape varies at runtime (e.g. Monte Carlo scenarios where each path
contributes a different number of components) and the compile-time dispatch
of [`compose`](@ref) would cause excessive specialization.

`factor` is computed via `mapreduce` over the vector with no `init` value, so
the fold uses the first element's type — preserving autodiff duals and
`BigFloat` element types. Iteration order matters for reproducibility (and
for the type-seeding behavior); pass a deterministically-ordered vector.

Empty vectors raise `ArgumentError` (matching the empty-args behavior of
[`compose`](@ref)).
"""
function dynamic_composite(v::AbstractVector{<:AbstractDeflator})
    isempty(v) && throw(ArgumentError("dynamic_composite requires at least one AbstractDeflator"))
    return DynamicCompositeDeflator(v)
end

# ─── Display and broadcasting ─────────────────────────────────────────────────

# Match the broadcasting convention from Rate at Rates.jl:111.
Base.Broadcast.broadcastable(p::AbstractDeflator) = Ref(p)

# Pretty-printing matches the constructor-expression style at Rates.jl:115-121.
function Base.show(io::IO, c::CompositeDeflator)
    return print(io, "compose(", join(repr.(c.components), ", "), ")")
end

function Base.show(io::IO, c::DynamicCompositeDeflator)
    return print(io, "dynamic_composite([", join(repr.(c.components), ", "), "])")
end
