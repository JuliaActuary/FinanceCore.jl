# Allow Dates or real timesteps
"""
    Timepoint(a)

Summary
≡≡≡≡≡≡≡≡≡

Timepoint is a type alias for Union{T,Dates.Date} that can be used to represent a point in time. It can be either a `Dates.Date` or a `Real` number. If defined as a real number, the interpretation is the number of (fractional) periods since time zero.

Currently, the usage of `Dates.Date` is not well supported across the JuliaActuary ecosystem but this type is in place such that it can be built upon further.

Supertype Hierarchy
≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡

    Timepoint{T} = Union{T,Dates.Date} <: Any
"""
const Timepoint{T} = Union{T,Dates.Date} where {T<:Real}

abstract type AbstractContract end

"""
    Quote(price,instrument)

The `price`(`<:Real`) is the observed value , and the `instrument` is the instrument/contract that the price is for.

This can be used, e.g., to calibrate a valuation model to prices for the given instruments - see FinanceModels.jl for more details.

"""
struct Quote{N<:Real,T}
    price::N
    instrument::T
end

maturity(q::Quote) = maturity(q.instrument)
Base.isapprox(a::Quote, b::Quote) = isapprox(a.price, b.price) && isapprox(a.instrument, b.instrument)


"""
    Cashflow(amount,time)

A `Cahflow{A,B}` is a contract that pays an `amount` at `time`. 

Cashflows can be:

- negated with the unary `-` operator. 
- added/subtracted together but note that the `time` must be `isapprox` equal.
- multiplied/divided by a scalar.

Supertype Hierarchy
≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡

    Cashflow{A<:Real, B<:Timepoint} <: FinanceCore.AbstractContract <: Any
"""
struct Cashflow{N<:Real,T<:Timepoint} <: AbstractContract
    amount::N
    time::T
end

maturity(c::C) where {C<:Cashflow} = c.time
Base.:-(c::C) where {C<:Cashflow} = Cashflow(-c.amount, c.time)
Base.zero(c::C) where {C<:Cashflow} = Cashflow(zero(c.amount), c.time)

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
timepoint(x::C, t=x.time) where {C<:Cashflow} = x.time
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

"""
    Composite(A,B)

Summary
≡≡≡≡≡≡≡≡≡

    struct Composite{A, B}

A `Composite{A,B}` is a contract that is composed of two other contracts of type `A` and type `B`. 
The maturity of the composite is the maximum of the maturities of the two components. 

It is used to assemble arbitrarily complex contracts from simpler ones.


Fields
≡≡≡≡≡≡≡≡

    a :: A
    b :: B


Supertype Hierarchy
≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡

    Composite{A, B} <: FinanceCore.AbstractContract <: Any
"""
struct Composite{A,B} <: AbstractContract
    a::A
    b::B
end

maturity(c::Composite) = max(maturity(c.a), maturity(c.b))
