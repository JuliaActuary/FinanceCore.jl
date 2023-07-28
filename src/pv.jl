"""
    present_value(yield_model, cashflows[, timepoints=pairs(cashflows)])

Discount the `cashflows` vector at the given `yield_model`,  with the cashflows occurring
at the times specified in `timepoints`. If no `timepoints` given, assumes that cashflows happen at the indices of the cashflows.

If your timepoints are dates, you can convert them into a floating point representation of the time interval using DayCounts.jl.

# Examples
```julia-repl
julia> present_value(0.1, [10,20],[0,1])
28.18181818181818
julia> present_value(Continuous(0.1), [10,20],[0,1])
28.096748360719193
julia> present_value(Continuous(0.1), [10,20],[1,2])
25.422989241919232
julia> present_value(Continuous(0.1), [10,20])
25.422989241919232
```

"""
function present_value(r, x, times)
    # previously tried LoopVectorization.vmapreduce, but it didn't play well with 
    # dual numbers when differentiated
    mapreduce((xi, ti) -> present_value(r, xi, ti), +, x, times)
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