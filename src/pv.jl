"""
    present_value(interest, cashflows::Vector, timepoints)
    present_value(interest, cashflows::Vector)

Discount the `cashflows` vector at the given `interest_interestrate`,  with the cashflows occurring
at the times specified in `timepoints`. If no `timepoints` given, assumes that cashflows happen at times 1,2,...,n.

The `interest` can be an `InterestCurve`, a single scalar, or a vector wrapped in an `InterestCurve`. 

# Examples
```julia-repl
julia> present_value(0.1, [10,20],[0,1])
28.18181818181818
julia> present_value(Yields.Forward([0.1,0.2]), [10,20],[0,1])
28.18181818181818 # same as above, because first cashflow is at time zero
```

Example on how to use real dates using the [DayCounts.jl](https://github.com/JuliaFinance/DayCounts.jl) package
```jldoctest

using DayCounts 
dates = Date(2012,12,31):Year(1):Date(2013,12,31)
times = map(d -> yearfrac(dates[1], d, DayCounts.Actual365Fixed()),dates) # [0.0,1.0]
present_value(0.1, [10,20],times)

# output
28.18181818181818

```

"""
function present_value(r, x, times)
    mapreduce(xi, ti -> present_value(r, xi, ti), +, x, times)
end
function present_value(r, x)
    mapreduce(px -> present_value(r, last(px), first(px)), +, pairs(x))
end

# time is ignored in favor of the time inside the cashflow
function present_value(r, x::C, time=nothing) where {C<:Cashflow}
    x.amount * discount(r, x.time)
end

function present_value(r, x::R, time) where {R<:Real}
    x * discount(r, time)
end

const pv = present_value