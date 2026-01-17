module FinanceCoreLoopVectorizationExt

using FinanceCore
using FinanceCore: TurboBackend, VECTORIZATION_BACKEND, Cashflow, amount, timepoint
using LoopVectorization

# Set the backend to TurboBackend when this extension loads
function __init__()
    VECTORIZATION_BACKEND[] = TurboBackend()
end

# @turbo implementation for TurboBackend
function FinanceCore.__pv_div_pv′(::TurboBackend, r, cashflows, times)
    n = 0.0
    d = 0.0
    @turbo warn_check_args = false for i in eachindex(cashflows)
        cf = cashflows[i]
        t = times[i]
        a = cf * exp(-r * t)
        n += a
        d += a * -t
    end
    return n / d
end

function FinanceCore.__pv_div_pv′(::TurboBackend, r, cashflows::Vector{C}) where {C <: Cashflow}
    n = 0.0
    d = 0.0
    @turbo warn_check_args = false for i in eachindex(cashflows)
        cf = amount(cashflows[i])
        t = timepoint(cashflows[i])
        a = cf * exp(-r * t)
        n += a
        d += a * -t
    end
    return n / d
end

end
