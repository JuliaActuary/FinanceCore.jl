module FinanceCoreDayCountsExt

import FinanceCore
import DayCounts
import Dates

"""
    discount(rate, from::Date, to::Date, dc::DayCounts.DayCount)

Discount `rate` over the interval between two `Date`s, with the interval measured as a
year fraction under the day count convention `dc` (via `DayCounts.yearfrac(from, to, dc)`).
As with the scalar-time methods, a non-`Rate` `rate` is assumed to be `Periodic(rate, 1)`.

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
function FinanceCore.discount(rate, from::Dates.Date, to::Dates.Date, dc::DayCounts.DayCount)
    return FinanceCore.discount(rate, DayCounts.yearfrac(from, to, dc))
end

"""
    accumulation(rate, from::Date, to::Date, dc::DayCounts.DayCount)

Accumulate `rate` over the interval between two `Date`s, with the interval measured as a
year fraction under the day count convention `dc` (via `DayCounts.yearfrac(from, to, dc)`).
As with the scalar-time methods, a non-`Rate` `rate` is assumed to be `Periodic(rate, 1)`.

Available when DayCounts.jl is loaded.

# Examples

```julia-repl
julia> using FinanceCore, DayCounts, Dates

julia> accumulation(0.05, Date(2024, 1, 1), Date(2024, 7, 1), DayCounts.Thirty360())
1.02469507659596
```
"""
function FinanceCore.accumulation(rate, from::Dates.Date, to::Dates.Date, dc::DayCounts.DayCount)
    return FinanceCore.accumulation(rate, DayCounts.yearfrac(from, to, dc))
end

end
