# Allow Dates or real timesteps
const Timepoint{T} = Union{T,Dates.Date} where {T<:Real}

abstract type AbstractContract end

struct Quote{N<:Real,T}
    price::N
    instrument::T
end

maturity(q::Quote) = maturity(q.instrument)
Base.isapprox(a::Quote, b::Quote) = isapprox(a.price, b.price) && isapprox(a.instrument, b.instrument)

struct Cashflow{N<:Real,T<:Timepoint} <: AbstractContract
    amount::N
    time::T
end

maturity(c::C) where {C<:Cashflow} = c.time

"""
    amount(x)

If is an object with an amount component (e.g. a `Cashflow`), will retrun that amount component, otherwise just `x`.

# Examples

```julia-repl
julia> FinanceCore.amount(Cashflow(1.,3.))
1.0

julia> FinanceCore.amount(1.)
1.0
```
"""
amount(x::C) where {C<:Cashflow} = x.amount
amount(x::R) where {R<:Real} = x

"""
    time(x,t)

If `x` is an object with a defined time component (e.g. a `Cashflow`), will return that time component, otherwise
will return `t`. This is useful in handling situations where you want to handle either `Cashflow`s or separate amount and time vectors.

# Example

```julia-repl
julia> FinanceCore.time(Cashflow(1.,3.),"ignored")
3.0

julia> FinanceCore.time(1.,4.)
4.0
```

"""
time(x::C, t) where {C<:Cashflow} = x.time
time(x::R, t) where {R<:Real} = t
Base.isapprox(a::C, b::C) where {C<:Cashflow} = isapprox(a.amount, b.amount) && isapprox(a.time, b.time)
Base.convert(::Type{Cashflow{A,B}}, y::Cashflow{C,D}) where {A,B,C,D} = Cashflow(A(y.amount), B(y.time))

struct Composite{A,B} <: AbstractContract
    a::A
    b::B
end

maturity(c::Composite) = max(maturity(c.a), maturity(c.b))
