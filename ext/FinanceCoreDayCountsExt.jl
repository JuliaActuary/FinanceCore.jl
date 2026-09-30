module FinanceCoreDayCountsExt

import FinanceCore
import DayCounts
import Dates

"""
    discount(rate::Union{Real, Rate}, from::Date, to::Date, dc::DayCounts.DayCount)

Discount `rate` over the interval between two `Date`s, with the interval measured as a
year fraction under the day count convention `dc` (via `DayCounts.yearfrac(from, to, dc)`).
As with the scalar-time methods, a non-`Rate` `rate` is assumed to be `Periodic(rate, 1)`.

Only a constant rate is accepted: its discount factor depends only on the length of the
interval. A yield curve's does not, since the curve is anchored at its valuation date, so it
cannot be discounted over two dates without that anchor.

Available when DayCounts.jl is loaded.

# Examples

```julia-repl
julia> using FinanceCore, DayCounts, Dates

julia> discount(0.05, Date(2024, 1, 1), Date(2024, 7, 1), DayCounts.Actual365Fixed())
0.9759653002306966

julia> discount(0.05, DayCounts.yearfrac(Date(2024, 1, 1), Date(2024, 7, 1), DayCounts.Actual365Fixed()))
0.9759653002306966
```
"""
function FinanceCore.discount(rate::Union{Real, FinanceCore.Rate}, from::Dates.Date, to::Dates.Date, dc::DayCounts.DayCount)
    return FinanceCore.discount(rate, DayCounts.yearfrac(from, to, dc))
end

"""
    accumulation(rate::Union{Real, Rate}, from::Date, to::Date, dc::DayCounts.DayCount)

Accumulate `rate` over the interval between two `Date`s, with the interval measured as a
year fraction under the day count convention `dc` (via `DayCounts.yearfrac(from, to, dc)`).
As with the scalar-time methods, a non-`Rate` `rate` is assumed to be `Periodic(rate, 1)`.
Only a constant rate is accepted (see `discount`).

Available when DayCounts.jl is loaded.

# Examples

```julia-repl
julia> using FinanceCore, DayCounts, Dates

julia> accumulation(0.05, Date(2024, 1, 1), Date(2024, 7, 1), DayCounts.Thirty360())
1.02469507659596
```
"""
function FinanceCore.accumulation(rate::Union{Real, FinanceCore.Rate}, from::Dates.Date, to::Dates.Date, dc::DayCounts.DayCount)
    return FinanceCore.accumulation(rate, DayCounts.yearfrac(from, to, dc))
end

end
