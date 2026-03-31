"""
    internal_rate_of_return_checked(cashflows::AbstractVector)::Rate
    internal_rate_of_return_checked(cashflows::AbstractVector, timepoints)::Rate
    internal_rate_of_return_checked(cashflows::Vector{<:Cashflow})::Rate

Calculate the internal rate of return. If no timepoints given, assumes equally spaced
cashflows starting at time zero (0, 1, 2, ..., n).

Returns a `Periodic(rate, 1)` `Rate`, or `nothing` if no root is found.

Unlike [`irr`](@ref), this version verifies that Newton's method actually converged
before accepting its result. If Newton does not converge, falls back to a robust
root-finding search over [-0.99, 2]. When the fallback finds multiple roots, returns
the one nearest zero.

# Example
```julia-repl
julia> irr_checked([-100, 110], [0, 1])
Periodic(0.1, 1)
julia> irr_checked([-100, 110])
Periodic(0.1, 1)
```
"""
function internal_rate_of_return_checked(cashflows::AbstractVector{<:Real})
    return internal_rate_of_return_checked(cashflows, 0:(length(cashflows) - 1))
end

function internal_rate_of_return_checked(cashflows::Vector{C}) where {C <: Cashflow}
    v = _irr_checked_newton(cashflows)
    if isnan(rate(v))
        return _irr_checked_robust(cashflows)
    else
        return v
    end
end

function internal_rate_of_return_checked(cashflows, times)
    v = _irr_checked_newton(cashflows, times)
    if isnan(rate(v))
        return _irr_checked_robust(cashflows, times)
    else
        return v
    end
end

# Newton solver that returns NaN on non-convergence
function _irr_checked_newton(cashflows, times)
    @assert length(cashflows) == length(times)
    r = _newtons_method_checked(cashflows, times, 0.001, 1.0e-9, 100)
    return Periodic(exp(r) - 1, 1)
end

function _irr_checked_newton(cashflows::Vector{C}) where {C <: Cashflow}
    r = _newtons_method_checked(cashflows, 0.001, 1.0e-9, 100)
    return Periodic(exp(r) - 1, 1)
end

# Newton's method that returns NaN when k_max is exhausted without convergence.
# Modified from Algorithms for Optimization, Kochenderfer & Wheeler, pg 88.
function _newtons_method_checked(cashflows, times, x, ε, k_max)
    k = 1
    Δ = Inf
    while abs(Δ) > ε && k ≤ k_max
        Δ = __pv_div_pv′(x, cashflows, times)
        x -= Δ
        k += 1
    end
    return abs(Δ) ≤ ε ? x : NaN
end

function _newtons_method_checked(cashflows::Vector{C}, x, ε, k_max) where {C <: Cashflow}
    k = 1
    Δ = Inf
    while abs(Δ) > ε && k ≤ k_max
        Δ = __pv_div_pv′(x, cashflows)
        x -= Δ
        k += 1
    end
    return abs(Δ) ≤ ε ? x : NaN
end

# Robust fallback with corrected root selection and Cashflow handling
_irr_checked_robust(cashflows) = _irr_checked_robust(cashflows, 0:(length(cashflows) - 1))

function _irr_checked_robust(cashflows, times)
    f(i) = sum(cf / (1 + i)^t for (cf, t) in zip(cashflows, times))
    roots = Roots.find_zeros(f, -0.99, 2)
    isempty(roots) && return nothing
    return Periodic(roots[argmin(abs.(roots))], 1)
end

function _irr_checked_robust(cashflows::Vector{C}) where {C <: Cashflow}
    f(i) = sum(amount(cf) / (1 + i)^timepoint(cf) for cf in cashflows)
    roots = Roots.find_zeros(f, -0.99, 2)
    isempty(roots) && return nothing
    return Periodic(roots[argmin(abs.(roots))], 1)
end

"""
    irr_checked(cashflows)
    irr_checked(cashflows, timepoints)

An alias for [`internal_rate_of_return_checked`](@ref).
"""
const irr_checked = internal_rate_of_return_checked
