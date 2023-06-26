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
present_value(r, x, t=eachindex(x)) = _present_value(Base.IteratorEltype(x), r, x, t)

# pattern for dispatching on element type taken from
# https://discourse.julialang.org/t/dispatch-over-element-type/93769/8
_present_value(::Base.HasEltype, r, x, t) = _present_value(eltype(x), r, x, t)

function _present_value(t, r, x, times)
    mapreduce((xi, ti) -> xi * discount(r, ti), +, x, times)
end

function _present_value(::Type{C}, r, x, times) where {C<:Cashflow}
    mapreduce(xi -> xi.amount * discount(r, xi.time), +, x)
end

const pv = present_value