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
    timepoint(x,t)

If `x` is an object with a defined time component (e.g. a `Cashflow`), will return that time component, otherwise
will return `t`. This is useful in handling situations where you want to handle either `Cashflow`s or separate amount and time vectors.

# Example

```julia-repl
julia> FinanceCore.timepoint(Cashflow(1.,3.),"ignored")
3.0

julia> FinanceCore.timepoint(1.,4.)
4.0
```

"""
timepoint(x::C, t=x.time) where {C<:Cashflow} = t
timepoint(x::R, t) where {R<:Real} = t

# Base.convert(::Type{Cashflow{A,B}}, y::Cashflow{C,D}) where {A,B,C,D} = Cashflow(A(y.amount), B(y.time))

function Base.isapprox(a::C, b::D; atol::Real=0, rtol::Real=atol > 0 ? 0 : √eps()) where {C<:Cashflow,D<:Cashflow}
    amt = isapprox(amount(a), amount(b); atol, rtol)
    return amt && isapprox(timepoint(a), timepoint(b); atol, rtol)
end

function Base.:+(c1::C, c2::D) where {C<:Cashflow,D<:Cashflow}
    if timepoint(c1) ≈ timepoint(c2)
        Cashflow(amount(c1) + amount(c2), timepoint(c1))
    else
        throw(ArgumentError("Cashflow timepoints must be the same. Got $(timepoint(c1)) and $(timepoint(c2))."))
    end
end

function Base.:-(c1::C, c2::D) where {C<:Cashflow,D<:Cashflow}
    if timepoint(c1) ≈ timepoint(c2)
        Cashflow(amount(c1) - amount(c2), timepoint(c1))
    else
        throw(ArgumentError("Cashflow timepoints must be the same. Got $(timepoint(c1)) and $(timepoint(c2))."))
    end
end

function Base.:*(c1::C, c2::D) where {C<:Cashflow,D<:Real}
    Cashflow(amount(c1) * c2, timepoint(c1))
end
function Base.:*(c1::D, c2::C) where {C<:Cashflow,D<:Real}
    Cashflow(amount(c2) * c1, timepoint(c2))
end
function Base.:/(c1::C, c2::D) where {C<:Cashflow,D<:Real}
    Cashflow(amount(c1) / c2, timepoint(c1))
end


struct Composite{A,B} <: AbstractContract
    a::A
    b::B
end

maturity(c::Composite) = max(maturity(c.a), maturity(c.b))
