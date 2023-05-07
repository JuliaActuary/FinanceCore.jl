"""
    internal_rate_of_return(cashflows::vector)::Rate
    internal_rate_of_return(cashflows::Vector, timepoints::Vector)::Rate
    
Calculate the internal_rate_of_return with given timepoints. If no timepoints given, will assume that a series of equally spaced cashflows, assuming the first cashflow occurring at time zero and subsequent elements at time 1, 2, 3, ..., n. 

Returns a Rate type with periodic compounding once per period (e.g. annual effective if the `timepoints` given represent years). Get the scalar rate by calling `Yields.rate()` on the result.

# Example
```julia-repl
julia> internal_rate_of_return([-100,110],[0,1]) # e.g. cashflows at time 0 and 1
0.10000000001652906
julia> internal_rate_of_return([-100,110]) # implied the same as above
0.10000000001652906
```

# Solver notes
Will try to return a root within the range [-2,2]. If the fast solver does not find one matching this condition, then a more robust search will be performed over the [.99,2] range.

The solution returned will be in the range [-2,2], but may not be the one nearest zero. For a slightly slower, but more robust version, call `ActuaryUtilities.irr_robust(cashflows,timepoints)` directly.
"""
function internal_rate_of_return(cashflows)
    return internal_rate_of_return(cashflows, 0:length(cashflows)-1)
end

function internal_rate_of_return(cashflows,times)
    # first try to quickly solve with newton's method, otherwise 
    # revert to a more robust method
    lower,upper = -2.,2.
    
    v = try 
        return irr_newton(cashflows,times)
    catch e
        if isa(e,Roots.ConvergenceFailed) || sprint(showerror, e) =="No convergence"
            return irr_robust(cashflows,times)
        else
            throw(e)
        end
    end
    
    if v <= upper && v >= lower
        return v
    else
        return irr_robust(cashflows,times)
    end
end

irr_robust(cashflows) = irr_robust(cashflows,0:length(cashflows)-1)

function irr_robust(cashflows, times)
    f(i) =  sum(cf / (1+i)^t for (cf,t) in zip(cashflows,times))
    # lower bound at -.99 because otherwise we can start taking the root of a negative number
    # when a time is fractional. 
    roots = Roots.find_zeros(f, -0.99, 2)
    
    # short circuit and return nothing if no roots found
    isempty(roots) && return nothing
    # find and return the one nearest zero
    min_i = argmin(roots)
    return Periodic(roots[min_i],1)

end

irr_newton(cashflows) = irr_newton(cashflows,0:length(cashflows)-1)

function irr_newton(cashflows, times)
    @assert length(cashflows) >= length(times)
    # use newton's method with hand-coded derivative
    f(r) =  __pv(r,cashflows,times)
    f′(r) =  __pv′(r,cashflows,times)
    r = Roots.newton(x->(f(x),f(x)/f′(x)),0.0)
    return Periodic(exp(r)-1,1)

end

function __pv(r,cashflows, times)
    # determine the type of the container and use that for the sum after tranforming by multiplying
    v = zero(typeof(first(cashflows) * 0.1)) 
    @turbo for i ∈ eachindex(cashflows)
        cf = cashflows[i]
        t = times[i]
        v += cf * exp(-r*t)
    end
    return v
end
function __pv′(r,cashflows, times)
    v = zero(typeof(first(cashflows) * 0.1))
    @turbo for i ∈ eachindex(cashflows)
        cf = cashflows[i]
        t =times[i]
        v += -t*cf * exp(-r*t)
    end
    return v
end

"""
    irr(cashflows::vector)
    irr(cashflows::Vector, timepoints::Vector)

    An alias for `internal_rate_of_return`.
"""
irr = internal_rate_of_return


function newtons_method(∇f, H, x, ε, k_max) 
    k, Δ = 1, fill(Inf, length(x))
    while norm(Δ) > ε && k ≤ k_max
            Δ = H(x) \ ∇f(x)
            x -= Δ
            k += 1
    end
    return x 
end