"""
    present_value(yield_model, amounts, timepoints)
    present_value(yield_model, cashflows)
    present_value(yield_model, contract)

Discount cashflows at `yield_model`: a `Rate`, a number (taken as `Periodic(rate, 1)`), or any model
that defines `discount`. The valuation is as of time zero.

- With `timepoints`, each amount is paid at the paired timepoint. A [`Cashflow`](@ref) is paid at its
  own time, not the paired one. Amounts and timepoints pair by position (vectors from each one's
  first index) and must have the same length, whatever the collection: vectors, tuples,
  generators, or a single timepoint with a collection of one amount. Different lengths throw a
  `DimensionMismatch`, except that no amounts are worth zero whatever the times. Each collection
  is iterated once, so single-pass iterators work.
- Without `timepoints`, the collection is valued over its `pairs`: a number is paid at its key (the
  index of a vector, the key of a `Dict`), and any other element, such as a `Cashflow`, a contract or a
  nested collection, is valued on its own timing, `present_value(yield_model, element)`.
- A [`Cashflow`](@ref) is its amount discounted from its time, and a [`Composite`](@ref) is the sum of
  its two components' present values.

So present value is linear over self-timed contracts whose values share a reporting currency:
`pv(r, [a, b]) ≈ pv(r, a) + pv(r, b) ≈ pv(r, [b, a])`, and
`pv(r, Composite(a, b)) == pv(r, a) + pv(r, b)`. A numeric vector is an indexed schedule: reordering
it moves amounts to other times.

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
    With no `timepoints` argument, `present_value` assumes amounts occur at the vector's *indices* (`1, 2, ..., n`), while [`internal_rate_of_return`](@ref) assumes they start at time zero (`0, 1, ..., n-1`). Pass explicit timepoints to avoid ambiguity.

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
julia> present_value(Continuous(0.1), [Cashflow(10, 1), Cashflow(20, 2)])
25.422989241919232
julia> present_value(Continuous(0.1), Any[10, Cashflow(20, 2)])
25.422989241919232
```

"""
present_value(r, x, times) = _sum_present_values(r, x, times)

# Amounts and times pair by position and must have equal lengths (a shorter one would drop
# payments), except that no amounts are worth zero whatever the times. Neither method builds a
# vector of discounted amounts, as `mapreduce(f, +, x, times)` would. (LoopVectorization.vmapreduce
# was tried once, but didn't play well with dual numbers.)
#
# Vectors pair from each one's own first index, so offset vectors pair too. They reduce over the
# positions with Base's pairwise summation, which stays accurate for long streams.
function _sum_present_values(r, x::AbstractVector, times::AbstractVector)
    isempty(x) && return _empty_present_value(r, eltype(x), eltype(times))
    n = length(x)
    n == length(times) || throw(DimensionMismatch("$n amounts but $(length(times)) times"))
    i, j = firstindex(x), firstindex(times)
    return mapreduce(k -> _present_value_at(r, x[i + k], times[j + k]), +, 0:(n - 1))
end

# Any other collection (a tuple, a generator, a scalar time) is iterated together with its pair, in
# a left fold, and once only, so a single-pass iterator loses no item to a separate emptiness or
# length check. If one ends before the other, it throws.
function _sum_present_values(r, x, times)
    xs = iterate(x)
    xs === nothing && return _empty_present_value(r, eltype(values(x)), eltype(times))
    ts = iterate(times)
    ts === nothing && _throw_length_mismatch()
    total = _present_value_at(r, xs[1], ts[1])
    while true
        xs = iterate(x, xs[2])
        ts = iterate(times, ts[2])
        xs === nothing && break
        ts === nothing && _throw_length_mismatch()
        total += _present_value_at(r, xs[1], ts[1])
    end
    ts === nothing || _throw_length_mismatch()
    return total
end
_throw_length_mismatch() = throw(DimensionMismatch("amounts and times have different lengths"))

# Convert scalar rates once per collection rather than once per cashflow in the
# scalar `present_value` method below.
function present_value(r::Real, x::AbstractVector, times)
    return present_value(Rate(r), x, times)
end

function present_value(r, x)
    isempty(x) && return _empty_present_value(r, eltype(values(x)), eltype(keys(x)))
    return mapreduce(px -> _present_value_of(r, last(px), first(px)), +, pairs(x))
end

# An amount is paid at its paired time, and a Cashflow at its own.
_present_value_at(r, x, time) = present_value(r, amount(x), timepoint(x, time))

# In a collection, a number is paid at its key, and anything else (a contract, a nested collection)
# is valued on its own timing.
_present_value_of(r, x::R, key) where {R <: Real} = present_value(r, x, key)
_present_value_of(r, x, key) = present_value(r, x)

# The empty sum: `zero` of a zero amount discounted at time zero, so that the result has the type
# of a present value of such cashflows (a dual number under ForwardDiff, for example) but not a value
# that depends on the rate (no NaN, and a positive zero). An element type that says nothing about
# the amounts or times contributes `false`, which promotes to the other operand's type, so the rate
# or curve decides the type.
_empty_present_value(r, ::Type{A}, ::Type{T}) where {A, T} =
    zero(_present_value_at(r, _zero_amount(A), _zero_time(T)))
_zero_amount(::Type{A}) where {A <: Real} = zero(A)
_zero_amount(::Type{Cashflow{N, T}}) where {N, T} = Cashflow(_zero_amount(N), _zero_time(T))
_zero_amount(::Type) = false
_zero_amount(::Type{Union{}}) = false
_zero_time(::Type{T}) where {T <: Real} = zero(T)
_zero_time(::Type) = false
_zero_time(::Type{Union{}}) = false

function present_value(r::Real, x::AbstractVector)
    return present_value(Rate(r), x)
end

present_value(r, x::Cashflow) = present_value(r, x.amount, x.time)

function present_value(r, x::C) where {C <: Composite}
    return present_value(r, x.a) + present_value(r, x.b)
end

function present_value(r, x::R, time) where {R <: Real}
    return x * discount(r, time)
end

const pv = present_value
