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

maturity(c::Cashflow) = c.time
Base.isapprox(a::Cashflow, b::Cashflow) = isapprox(a.amount, b.amount) && isapprox(a.time, b.time)
Base.convert(::Type{Cashflow{A,B}}, y::Cashflow{C,D}) where {A,B,C,D} = Cashflow(A(y.amount), B(y.time))

struct Composite{A,B} <: AbstractContract
    a::A
    b::B
end

maturity(c::Composite) = max(maturity(c.a), maturity(c.b))
