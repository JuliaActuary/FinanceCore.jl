# FinanceCore.jl release notes

## v3.0.0

### Valuation composes

In 2.x, `present_value` valued a collection by passing each element's index as a third positional
argument. FinanceModels read that argument as a valuation time, so `pv(r, [bond])` was not
`pv(r, bond)`, and `pv(r, [a, b])` was not `pv(r, [b, a])`. Now the third argument only gives the
payment times of plain amounts. Contracts carry their own timing, and `present_value` has no
valuation-time argument:

- `present_value(r, amounts, times)` pays each amount at the paired time. A `Cashflow` among the
  amounts is paid at its own time.
- `present_value(r, collection)` pays a number at its key (a vector's index, a `Dict`'s key) and
  values any other element, such as a `Cashflow`, a contract or a nested collection, on its own:
  `present_value(r, element)`. Tuples, `Dict`s and nested collections work.
- `present_value(r, cf::Cashflow)` discounts the amount from the cashflow's time, and
  `present_value(r, Composite(a, b))` is `present_value(r, a) + present_value(r, b)` (without
  FinanceModels, it used to throw a `MethodError`).

So present value is linear over self-timed contracts whose values share a reporting currency:
`pv(r, [c]) === pv(r, c)`, and `pv(r, [a, b]) ≈ pv(r, a) + pv(r, b) ≈ pv(r, [b, a])`. A numeric
vector is an indexed schedule: reordering it moves amounts to other times. Present values of
numeric vectors without times are bitwise unchanged.

`present_value(r, amounts, times)` no longer builds a vector of discounted amounts before summing,
so it does not allocate. Results can differ from 2.8 in the last bits.

Amounts and times pair by position, and different lengths now throw a `DimensionMismatch`,
whatever the collections: vectors (paired from each one's first index, so offset vectors pair too),
tuples, generators, or a single time, which pays a collection of one amount. No amounts are worth
zero whatever the times. 2.x zipped the two, dropping the extra entries: a single time paid only the
first amount. Each collection is also iterated once, so a single-pass iterator of amounts keeps its
first amount, which 2.8 lost to its emptiness check.

### Cashflows add only at equal times

`Cashflow + Cashflow` and `-` accepted times within `isapprox` tolerance, so addition was not
associative: with times `1`, `1 + 1e-8` and `1 + 2e-8`, `(a + b) + c` threw while `a + (b + c)`
was defined. The times must now be exactly equal (`==`). `isapprox` on Cashflows keeps its
tolerance.

The new, unexported `FinanceCore.aggregate(cashflows; key = identity)` combines cashflows by
time: one `Cashflow` per distinct `key(time)`, in ascending order, with the summed amount. It
preserves the total amount (≈) for any `key`, and present value (≈) when `key` leaves times
unchanged, as `identity` does. A `key` that moves times, such as rounding, generally changes
present value.

### Interval discounts are defined for constant rates only

`discount(rate, from, to)` and `accumulation(rate, from, to)` are defined for a `Rate` or a number.
The untyped fallback computed `discount(model, to - from)` for any model without its own interval
method, which is wrong unless the rate is constant, and is removed: such a call now throws a
`MethodError`.

### Rate conversion

The three-argument `convert(to, r, from)` hook (which ignored `from`) is replaced by the single
method `convert(to::Frequency, r::Rate)`. Converted rates are identical to before.

### Migration

| Before (2.x) | Now (3.0) |
|---|---|
| `pv(r, [a, b])` of contracts, with the index passed to each as a third argument | Unchanged call: each contract is valued on its own timing, `pv(r, [a, b]) ≈ pv(r, a) + pv(r, b)`. Results change only where they depended on a contract's position |
| `pv(r, cf, t)` with a `Cashflow` (`t` was ignored) | `pv(r, cf)`. To pay the amount at another time: `pv(r, amount(cf), t)` |
| `pv(r, amounts, times)` with more amounts than times, or the reverse (the extra entries were dropped), in any collection | Throws a `DimensionMismatch`. Pass one time per amount |
| `pv(r, amounts, t)` with several amounts and a single time `t` (only the first amount was paid) | Throws a `DimensionMismatch`. To pay them all at `t`: `pv(r, sum(amounts), t)` |
| Valuation as of time `t` (a third argument) | An explicit reduction. For a deterministic rate or curve, apply the interval discount to each cashflow at or after `t`: `sum(cf.amount * discount(r, t, cf.time) for cf in cfs if cf.time >= t; init = 0.0)`, with an `init` of the valuation's type. Do not use `accumulation(r, t) * pv(r, later_cfs)`: with `Continuous(1.0)`, a cashflow at 1000 and `t = 999`, it gives `Inf * 0.0 = NaN` |
| `Cashflow(1.0, 1.0) + Cashflow(1.0, 1.0 + 1e-10)` | Throws an `ArgumentError`. Make the times equal, or combine with `FinanceCore.aggregate(cfs; key = ...)`, knowing that a key that moves times generally changes present value |
| `discount(model, from, to)` or `accumulation(model, from, to)` for a model without its own interval method | Throws a `MethodError`. Define `FinanceCore.discount(m::MyModel, from, to)` (for example `discount(m, to) / discount(m, from)`) and `accumulation` likewise |
| `convert(to, r, from)` | `convert(to, r)` |
