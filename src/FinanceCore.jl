module FinanceCore
import Roots
using Dates

# Forward-declare so `src/Rates.jl` can attach `Rate <: AbstractDeflator` and
# define factor/intensity methods for Rate. Generic methods that derive from
# `factor` (discount, accumulation, forward, zero, composites) live in
# `src/Deflator.jl` and are included after Rates.jl.
"""
    AbstractDeflator

Supertype for processes that act as a multiplicative factor over time. The
required primitive is [`factor`](@ref)`(p, from, to)`, which returns the scalar
scaling applied to a unit cashflow over `[from, to]`.

The interpretation of `factor` is chosen by the subtype:

- **Decrement-flavored** (factor ≤ 1 typical): yield discount, mortality
  survival, lapse persistency, default-survival.
- **Accumulation-flavored** (factor ≥ 1 typical): asset accumulation, equity
  paths, salary scales.

The abstraction covers **linear cashflow valuation**: `pv(deflator, cashflows)`
computes `Σ cᵢ · factor(deflator, tᵢ)`. Contingent claim pricing (options,
American exercise, path-dependent payoffs) is **not** in scope and lives in
parallel `present_value(model, contract)` machinery.

# Composition

`compose(a, b, c, ...)` builds a [`CompositeDeflator`](@ref) whose `factor` is
the product of the components' factors — i.e. composition assumes
**independence**. Correlated joints (Li copula, common-shock, joint scenarios)
must be expressed as bespoke `AbstractDeflator` subtypes whose `factor` is not
a product of marginals. This is intentional: the type system makes the
independence assumption visible.

# Recovery on default

Recovery-of-market-value parameterized by ELGD (the dominant modern convention
in reduced-form credit modeling) fits natively: bake `ELGD * λ` into the
default process, then `compose(yield, default_with_lgd)`. Recovery-at-maturity
is a one-line caller recipe (`R*pv(yield) + (1-R)*pv(yield * default)`).
Recovery-of-face-at-default requires `intensity` plus a quadrature integral
over the default-time density and lives in a downstream credit package.

# Forward-vs-spot footgun

For term-structure yield curves, `factor(yc, from, to) = D(0,to)/D(0,from)`
is the **forward** discount, not the spot. Composing `yc * mortality` on an
age axis (e.g. `factor(yc * mort_age65, 65, 70)`) returns the forward 65→70
discount, which is **not** the spot 5y discount unless the yield is
time-homogeneous. Recommended idiom: pre-slice age-indexed tables to start
at the valuation age so both components share a years-from-valuation axis.
Constant-force `Rate`s are origin-invariant and don't trigger this.

# Required interface

- `factor(p, from, to)` — multiplicative factor over `[from, to]`. **Required**
  for every concrete subtype.

# Optional interface

- `factor(p, t)` — single-argument shortcut. Only define for origin-invariant
  subtypes (e.g. constant-force `Rate`, term-structure yield curves where
  `t` means "from time 0"). Subtypes that index by absolute age/calendar
  time should NOT define this — leave the `MethodError` so callers catch
  the misuse.
- `intensity(p, t)` — instantaneous force, `-d/dt log(factor(p, 0, t))` where
  the derivative exists. There is **no fallback**: discrete subtypes (annual
  q_x tables, rating-transition matrices) deliberately MethodError so callers
  can't silently treat them as continuous-time.

See also: [`factor`](@ref), [`intensity`](@ref), [`compose`](@ref),
[`CompositeDeflator`](@ref), [`DynamicCompositeDeflator`](@ref).
"""
abstract type AbstractDeflator end

"""
    factor(p::AbstractDeflator, from, to)
    factor(p::AbstractDeflator, t)

Multiplicative factor of `p` over the interval `[from, to]`, or over `[0, t]`
for origin-invariant subtypes that define the single-argument form.

For yield curves and constant-force rates this is the discount factor. For
mortality, lapse, and default processes it is the survival probability over
the interval. For asset accumulation paths it is `S(to)/S(from)`. The exact
interpretation is chosen by the concrete subtype; see [`AbstractDeflator`](@ref).

The two-argument form `factor(p, from, to)` is **required** for every concrete
subtype. The single-argument form `factor(p, t)` is opt-in and should only be
defined for origin-invariant subtypes.
"""
function factor end

"""
    intensity(p::AbstractDeflator, t)

Instantaneous force at time `t`: `-d/dt log(factor(p, 0, t))` where this
derivative exists. **Optional** — only meaningful for continuous-time
subtypes. There is no numerical-differentiation fallback, so discrete
subtypes (annual q_x tables, rating-transition matrices) raise `MethodError`
when callers ask for `intensity` on them. This is intentional: the type
system surfaces the continuity assumption.

For a `CompositeDeflator` of independent components, `intensity` is the sum
of component intensities (chain rule on `log(factor) = Σ log(factor_i)`).
"""
function intensity end

include("Rates.jl")
export Rate, rate, compounding, discount, accumulation, Periodic, Continuous, forward


include("Contracts.jl")
export Cashflow, Quote, maturity, timepoint, amount, Composite

include("Deflator.jl")
export AbstractDeflator, CompositeDeflator, DynamicCompositeDeflator,
    compose, dynamic_composite, factor, intensity, components

include("irr.jl")
export irr, internal_rate_of_return

include("pv.jl")
export pv, present_value

end
