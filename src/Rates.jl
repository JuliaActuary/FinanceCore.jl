abstract type Frequency end
Base.Broadcast.broadcastable(x::T) where {T <: Frequency} = Ref(x)

"""
    Continuous()

A type representing continuous interest compounding frequency.

Use [`rate`](@ref) to retrieve the nominal rate value from a `Rate` with `Continuous` compounding.

# Examples

```julia-repl
julia> Rate(0.01,Continuous())
Continuous(0.01)
```

See also: [`Periodic`](@ref)
"""
struct Continuous <: Frequency end


"""
    Continuous(rate)

A convenience constructor for `Rate(rate, Continuous())`. Use [`rate`](@ref) to retrieve the nominal rate value.

```julia-repl
julia> Continuous(0.01)
Continuous(0.01)
```

See also: [`Periodic`](@ref)
"""
Continuous(rate) = Continuous().(rate)

function (c::Continuous)(r)
    return convert.(c, r)
end

"""
    Periodic(frequency)

A type representing periodic interest compounding with the given frequency.

`frequency` will be converted to an `Integer`, and will round up to 8 decimal places (otherwise will throw an `InexactError`).

Use [`rate`](@ref) to retrieve the nominal rate value from a `Rate` with `Periodic` compounding.

# Examples

Creating a semi-annual bond equivalent yield:

```julia-repl
julia> Rate(0.01,Periodic(2))
Periodic(0.01, 2)
```

See also: [`Continuous`](@ref)
"""
struct Periodic <: Frequency
    frequency::Int
end

function Periodic(frequency::T) where {T <: AbstractFloat}
    f = Int(round(frequency, digits = 8))
    return Periodic(f)
end


function (p::Periodic)(r)
    return convert.(p, r)
end

"""
    Periodic(rate, frequency)

A convenience constructor for `Rate(rate, Periodic(frequency))`. Use [`rate`](@ref) to retrieve the nominal rate value.

# Examples

Creating a semi-annual bond equivalent yield:

```julia-repl
julia> Periodic(0.01,2)
Periodic(0.01, 2)
```

See also: [`Continuous`](@ref)
"""
Periodic(x, frequency) = Periodic(frequency).(x)

struct Rate{N, T <: Frequency}
    continuous_value::N  # Precomputed equivalent continuous rate for faster discount/accumulation
    compounding::T
end

# Outer constructor for Continuous rates - continuous_value equals value
function Rate(value::N, compounding::Continuous) where {N}
    return Rate{N, Continuous}(value, compounding)
end

# Outer constructor for Periodic rates - precompute continuous equivalent
function Rate(value::N, compounding::Periodic) where {N}
    # continuous_value = n * log(1 + r/n), which is the equivalent continuous rate
    continuous_value = compounding.frequency * log(1 + value / compounding.frequency)
    return Rate{N, Periodic}(convert(N, continuous_value), compounding)
end

# make rate a broadcastable type
Base.Broadcast.broadcastable(ic::T) where {T <: Rate} = Ref(ic)

# Pretty printing: show the user-facing rate value, not the internal continuous_value.
# Output is a valid constructor expression, e.g. Periodic(0.06, 2) or Continuous(0.03).
function Base.show(io::IO, r::Rate{<:Any, Periodic})
    print(io, "Periodic(", rate(r), ", ", r.compounding.frequency, ")")
end

function Base.show(io::IO, r::Rate{<:Any, Continuous})
    print(io, "Continuous(", rate(r), ")")
end

"""
    Rate(rate[,frequency=1])
    Rate(rate,frequency::Frequency)

Rate is a type that encapsulates an interest `rate` along with its compounding `frequency`.

Internally, all rates (including `Periodic` rates) are stored as their continuously compounded equivalent for performance. This means the internal field values will differ from the nominal rate. Use [`rate`](@ref) to retrieve the nominal rate value corresponding to the compounding frequency, and [`compounding`](@ref) to retrieve the compounding frequency.

Periodic rates can be constructed via `Rate(rate,frequency)` or `Rate(rate,Periodic(frequency))`. If not given a second argument, `Rate(rate)` is equivalent to `Rate(rate,Periodic(1))`.

Continuous rates can be constructed via `Rate(rate, Inf)` or `Rate(rate,Continuous())`.

# Examples

```julia-repl
julia> Rate(0.01,Continuous())
Continuous(0.01)

julia> Continuous(0.01)
Continuous(0.01)

julia> Continuous()(0.01)
Continuous(0.01)

julia> Rate(0.01,Periodic(2))
Periodic(0.01, 2)

julia> Periodic(0.01,2)
Periodic(0.01, 2)

julia> Periodic(2)(0.01)
Periodic(0.01, 2)

julia> Rate(0.01)
Periodic(0.01, 1)

julia> Rate(0.01,2)
Periodic(0.01, 2)

julia> Rate(0.01,Periodic(4))
Periodic(0.01, 4)

julia> Rate(0.01,Inf)
Continuous(0.01)

julia> rate(Periodic(0.01,2))
0.01
```
"""
Rate(rate) = Rate(rate, Periodic(1))
Rate(x, frequency::T) where {T <: Real} = isinf(frequency) ? Rate(x, Continuous()) : Rate(x, Periodic(frequency))

"""
    convert(cf::Frequency,r::Rate) 

Returns a `Rate` with an equivalent discount but represented with a different compounding frequency.

# Examples

```julia-repl
julia> r = Rate(Periodic(12),0.01)
Rate(0.01, Periodic(12))

julia> convert(Periodic(1),r)
Rate(0.010045960887181016, Periodic(1))

julia> convert(Continuous(),r)
Rate(0.009995835646701251, Continuous())
```
"""
function Base.convert(cf::T, r::Rate{<:Any, <:Frequency}) where {T <: Frequency}
    return convert.(cf, r, r.compounding)
end

function Base.convert(cf::T, r::R) where {R <: Real} where {T <: Frequency}
    return Rate(r, cf)
end

function Base.convert(to::Continuous, r, from::Continuous)
    return r
end

function Base.convert(to::Periodic, r, from::Continuous)
    # For Continuous rates, continuous_value equals the rate value
    return Rate.(to.frequency * (exp(r.continuous_value / to.frequency) - 1), to)
end

function Base.convert(to::Continuous, r, from::Periodic)
    # r.continuous_value already contains the equivalent continuous rate
    return Rate.(r.continuous_value, to)
end

function Base.convert(to::Periodic, r, from::Periodic)
    # r.continuous_value is the equivalent continuous rate, use it to convert directly
    return Rate.(to.frequency * (exp(r.continuous_value / to.frequency) - 1), to)
end

function Continuous(r::Rate{<:Any, <:Periodic})
    return convert.(Continuous(), r)
end
function Continuous(r::Rate{<:Any, <:Continuous})
    return r
end
function Periodic(r::Rate{<:Any, <:Frequency}, frequency::Int)
    return convert.(Periodic(frequency), r)
end


"""
    rate(r::Rate)

Returns the nominal (untyped scalar) interest rate represented by the `Rate`, corresponding to its compounding frequency.

Since `Rate` internally stores all rates (including `Periodic`) as their continuously compounded equivalent for performance, `rate` recovers the nominal rate for the given compounding convention.

# Examples

```julia-repl
julia> r = Continuous(0.03)
Continuous(0.03)

julia> rate(r)
0.03

julia> r = Periodic(0.06, 2)
Periodic(0.06, 2)

julia> rate(r)
0.06
```
"""
function rate(r::Rate{<:Any, Continuous})
    return r.continuous_value
end

function rate(r::Rate{<:Any, Periodic})
    # continuous_value = n * log(1 + r/n), so r = n * (exp(continuous_value/n) - 1)
    n = r.compounding.frequency
    return n * (exp(r.continuous_value / n) - 1)
end

"""
    compounding(r::Rate)

Returns the compounding frequency of the `Rate`.

# Examples

```julia-repl
julia> r = Continuous(0.03)
Continuous(0.03)

julia> compounding(r)
Continuous()

julia> r = Periodic(0.05, 2)
Periodic(0.05, 2)

julia> compounding(r)
Periodic(2)
```
"""
function compounding(r::Rate{<:Any, <:Frequency})
    return r.compounding
end

function Base.isapprox(a::Rate{N, T}, b::Rate{N, T}; atol::Real = 0, rtol::Real = atol > 0 ? 0 : √eps()) where {T <: Periodic, N}
    c = convert(a.compounding, b)
    return (a.compounding.frequency == c.compounding.frequency) && isapprox(rate(a), rate(c); atol, rtol)
end

function Base.isapprox(a::Rate{N, T}, b::Rate{N, T}; atol::Real = 0, rtol::Real = atol > 0 ? 0 : √eps()) where {T <: Continuous, N}
    return isapprox(rate(a), rate(b); atol, rtol)
end

# the fallback for rates not of the same type
function Base.isapprox(a::T, b::N; atol::Real = 0, rtol::Real = atol > 0 ? 0 : √eps()) where {T <: Rate, N <: Rate}
    return isapprox(convert(b.compounding, a), b; atol, rtol)
end


"""
    discount(rate, t)
    discount(rate, from, to)

Discount `rate` for a time `t` or for an interval `(from, to)`. If `rate` is not a `Rate`, it will be assumed to be a `Periodic` rate compounded once per period, i.e. `Periodic(rate,1)`. 

# Examples

```julia-repl
julia> discount(0.03, 10)
0.7440939148967249

julia> discount(Periodic(0.03, 2), 10)
0.7424704182237725

julia> discount(Continuous(0.03), 10)
0.7408182206817179

julia> discount(0.03, 5, 10)
0.8626087843841639
```
"""
discount(rate, t) = discount(Rate(rate), t)
discount(rate::Rate, t) = exp(-rate.continuous_value * t)
discount(rate, from, to) = discount(rate, to - from)

"""
    accumulation(rate, t)
    accumulation(rate, from, to)

Accumulate `rate` for a time `t` or for an interval `(from, to)`. If `rate` is not a `Rate`, it will be assumed to be a `Periodic` rate compounded once per period, i.e. `Periodic(rate,1)`. 

    # Examples

```julia-repl
julia> accumulation(0.03, 10)
1.3439163793441222

julia> accumulation(Periodic(0.03, 2), 10)
1.3468550065500535

julia> accumulation(Continuous(0.03), 10)
1.3498588075760032

julia> accumulation(0.03, 5, 10)
1.1592740743
```
"""
accumulation(rate, t) = accumulation(Rate(rate), t)
accumulation(rate::Rate, t) = exp(rate.continuous_value * t)
accumulation(rate, from, to) = accumulation(rate, to - from)

Base.zero(rate::T, t) where {T <: Rate} = rate
forward(rate::T, to) where {T <: Rate} = rate
forward(rate::T, from, to) where {T <: Rate} = rate

"""
    +(Yields.Rate, T<:Real)
    +(T<:Real, Yields.Rate)
    +(Yields.Rate,Yields.Rate)

The addition of a rate with a number will inherit the type of the `Rate`, or the first argument's type if both are `Rate`s.

# Examples

```julia-repl
julia> Yields.Periodic(0.01,2) + Yields.Periodic(0.04,2)
Yields.Rate{Float64, Yields.Periodic}(0.05000000000000004, Yields.Periodic(2))

julia> Yields.Periodic(0.04,2) + 0.01
Yields.Rate{Float64, Yields.Periodic}(0.05, Yields.Periodic(2))
```
"""
function Base.:+(a::Rate{N, T}, b::Real) where {N, T <: Continuous}
    return Continuous(rate(a) + b)
end
function Base.:+(a::Real, b::Rate{N, T}) where {N, T <: Continuous}
    return Continuous(rate(b) + a)
end

function Base.:+(a::Rate{N, T}, b::Real) where {N, T <: Periodic}
    return Periodic(rate(a) + b, a.compounding.frequency)
end
function Base.:+(a::Real, b::Rate{N, T}) where {N, T <: Periodic}
    return Periodic(rate(b) + a, b.compounding.frequency)
end

function Base.:+(a::T, b::U) where {T <: Rate, U <: Rate}
    a_rate = rate(a)
    b_rate = rate(convert(a.compounding, b))
    r = Rate(a_rate + b_rate, a.compounding)
    return r
end

"""
    -(Yields.Rate, T<:Real)
    -(T<:Real, Yields.Rate)
    -(Yields.Rate, Yields.Rate)


The addition of a rate with a number will inherit the type of the `Rate`, or the first argument's type if both are `Rate`s.

# Examples

```julia-repl
julia> Yields.Periodic(0.04,2) - Yields.Periodic(0.01,2)
Yields.Rate{Float64, Yields.Periodic}(0.030000000000000214, Yields.Periodic(2))

julia> Yields.Periodic(0.04,2) - 0.01
Yields.Rate{Float64, Yields.Periodic}(0.03, Yields.Periodic(2))

```
"""
function Base.:-(a::Rate{N, T}, b::Real) where {N, T <: Continuous}
    return Continuous(rate(a) - b)
end
function Base.:-(a::Real, b::Rate{N, T}) where {N, T <: Continuous}
    return Continuous(a - rate(b))
end

function Base.:-(a::Rate{N, T}, b::Real) where {N, T <: Periodic}
    return Periodic(rate(a) - b, a.compounding.frequency)
end
function Base.:-(a::Real, b::Rate{N, T}) where {N, T <: Periodic}
    return Periodic(a - rate(b), b.compounding.frequency)
end
function Base.:-(a::T, b::U) where {T <: Rate, U <: Rate}
    a_rate = rate(a)
    b_rate = rate(convert(a.compounding, b))
    r = Rate(a_rate - b_rate, a.compounding)
    return r
end

"""
    *(Yields.Rate, T)
    *(T, Yields.Rate)

The multiplication of a Rate with a scalar will inherit the type of the `Rate`, or the first argument's type if both are `Rate`s.
"""
function Base.:*(a::Rate{N, T}, b::Real) where {N, T <: Continuous}
    return Continuous(rate(a) * b)
end
function Base.:*(a::Real, b::Rate{N, T}) where {N, T <: Continuous}
    return Continuous(a * rate(b))
end

function Base.:*(a::Rate{N, T}, b::Real) where {N, T <: Periodic}
    return Periodic(rate(a) * b, a.compounding.frequency)
end
function Base.:*(a::Real, b::Rate{N, T}) where {N, T <: Periodic}
    return Periodic(a * rate(b), b.compounding.frequency)
end


"""
    /(x::Yields.Rate, y::Real)

The division of a Rate with a scalar will inherit the type of the `Rate`, or the first argument's type if both are `Rate`s.
"""
function Base.:/(a::Rate{N, T}, b::Real) where {N, T <: Continuous}
    return Continuous(rate(a) / b)
end

# unclear if dividing a scalar by a rate should be allowed
# function Base.:/(a::Real, b::Rate{N,T}) where {N<:Real,T<:Continuous}
#     return Continuous( a / rate(b))
# end

function Base.:/(a::Rate{N, T}, b::Real) where {N, T <: Periodic}
    return Periodic(rate(a) / b, a.compounding.frequency)
end

# unclear if dividing a scalar by a rate should be allowed
# function Base.:/(a::Real, b::Rate{N,T}) where {N<:Real, T<:Periodic}
#     return Periodic(a / rate(b), b.compounding.frequency)
# end


"""
    <(x::Rate,y::Rate)

Convert the second argument to the periodicity of the first and compare the scalar rate values to determine if the first argument has a lower force of interest than the second.

# Examples

```julia-repl
julia> Yields.Periodic(0.03,100) < Yields.Continuous(0.03)
true
```
"""
# Note: We define separate methods for each combination of Periodic/Continuous
# instead of using `where {T <: Rate, U <: Rate}` to avoid compilation invalidations.
# Abstract type bounds like `<: Rate` cause Julia to invalidate previously compiled
# code for `<(::Any, ::Any)` signatures. Concrete type combinations don't have this issue.
# See: https://juliadebug.github.io/SnoopCompile.jl/stable/tutorials/invalidations/
function Base.:<(a::Rate{N1, Periodic}, b::Rate{N2, Periodic}) where {N1, N2}
    bc = convert(a.compounding, b)
    return rate(a) < rate(bc)
end
function Base.:<(a::Rate{N1, Continuous}, b::Rate{N2, Continuous}) where {N1, N2}
    return rate(a) < rate(b)
end
function Base.:<(a::Rate{N1, Periodic}, b::Rate{N2, Continuous}) where {N1, N2}
    bc = convert(a.compounding, b)
    return rate(a) < rate(bc)
end
function Base.:<(a::Rate{N1, Continuous}, b::Rate{N2, Periodic}) where {N1, N2}
    bc = convert(a.compounding, b)
    return rate(a) < rate(bc)
end

"""
    >(Rate,Rate)

Convert the second argument to the periodicity of the first and compare the scalar rate values to determine if the first argument has a greater force of interest than the second.

# Examples

```julia-repl
julia> Yields.Periodic(0.03,100) > Yields.Continuous(0.03)
false
```
"""
# Note: We define separate methods for each combination of Periodic/Continuous
# instead of using `where {T <: Rate, U <: Rate}` to avoid compilation invalidations.
# See comment above for `<` methods.
function Base.:>(a::Rate{N1, Periodic}, b::Rate{N2, Periodic}) where {N1, N2}
    bc = convert(a.compounding, b)
    return rate(a) > rate(bc)
end
function Base.:>(a::Rate{N1, Continuous}, b::Rate{N2, Continuous}) where {N1, N2}
    return rate(a) > rate(b)
end
function Base.:>(a::Rate{N1, Periodic}, b::Rate{N2, Continuous}) where {N1, N2}
    bc = convert(a.compounding, b)
    return rate(a) > rate(bc)
end
function Base.:>(a::Rate{N1, Continuous}, b::Rate{N2, Periodic}) where {N1, N2}
    bc = convert(a.compounding, b)
    return rate(a) > rate(bc)
end
