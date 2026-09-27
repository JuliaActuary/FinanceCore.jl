"""
    present_value(yield_model, cashflows[, timepoints=pairs(cashflows)])

Discount the `cashflows` vector at the given `yield_model`,  with the cashflows occurring
at the times specified in `timepoints`. If no `timepoints` given, assumes that cashflows happen at the indices of the cashflows.

If your timepoints are dates, you can convert them into a floating point representation of the time interval using DayCounts.jl.

An empty collection of cashflows has a present value of exactly zero (positive zero): the value is
fixed by linearity, and its numeric type follows a convention. For concrete amount, time and rate
types it is the type a present value of such cashflows would have (a dual number with zero partials
under ForwardDiff, a `BigFloat` for a `BigFloat` rate). When the element type says nothing about the
amounts (`Any[]`, `Cashflow[]`, `()`, an empty generator), the rate or curve decides it. The zero is
`zero` of the present value of a zero amount at time zero, so it has the valuation's type but does not
depend on the rate's value (`present_value(Continuous(Inf), Float64[])` is `0.0`); the rate or curve
is still evaluated at time zero to find that type, and can throw where that evaluation throws.

!!! warning "Default timepoints differ from `internal_rate_of_return`"
    With no `timepoints` argument, `present_value` assumes cashflows occur at the vector's *indices* (`1, 2, ..., n`), while [`internal_rate_of_return`](@ref) assumes they start at time zero (`0, 1, ..., n-1`). Pass explicit timepoints to avoid ambiguity.

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
    isempty(x) && return _empty_present_value(r, eltype(values(x)), eltype(times))
    # previously tried LoopVectorization.vmapreduce, but it didn't play well with
    # dual numbers when differentiated
    return mapreduce((xi, ti) -> present_value(r, xi, ti), +, x, times)
end

# Convert scalar rates once per collection rather than once per cashflow in the
# scalar `present_value` method below.
function present_value(r::Real, x::AbstractVector, times)
    return present_value(Rate(r), x, times)
end

function present_value(r, x)
    isempty(x) && return _empty_present_value(r, eltype(values(x)), eltype(keys(x)))
    return mapreduce(px -> present_value(r, last(px), first(px)), +, pairs(x))
end

# The empty sum: `zero` of a zero amount discounted at time zero, so that the result has the type
# of a present value of such cashflows (a dual number under ForwardDiff, for example) but not a value
# that depends on the rate (no NaN, and a positive zero). An element type that says nothing about
# the amounts or times contributes `false`, which promotes to the other operand's type, so the rate
# or curve decides the type.
_empty_present_value(r, ::Type{A}, ::Type{T}) where {A, T} =
    zero(present_value(r, _zero_amount(A), _zero_time(T)))
_zero_amount(::Type{A}) where {A <: Real} = zero(A)
_zero_amount(::Type{Cashflow{N, T}}) where {N, T} = Cashflow(_zero_amount(N), _zero_time(T))
_zero_amount(::Type) = false
_zero_amount(::Type{Union{}}) = false
_zero_time(::Type{T}) where {T <: Real} = zero(T)
_zero_time(::Type{Cashflow{N, T}}) where {N, T} = _zero_time(T)
_zero_time(::Type) = false
_zero_time(::Type{Union{}}) = false

function present_value(r::Real, x::AbstractVector)
    return present_value(Rate(r), x)
end

# time is ignored in favor of the time inside the cashflow
function present_value(r, x::C, time = nothing) where {C <: Cashflow}
    return x.amount * discount(r, x.time)
end

function present_value(r, x::R, time) where {R <: Real}
    return x * discount(r, time)
end

const pv = present_value
