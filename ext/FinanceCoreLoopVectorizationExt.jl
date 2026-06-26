module FinanceCoreLoopVectorizationExt

using FinanceCore
using FinanceCore: TurboBackend, VECTORIZATION_BACKEND, Cashflow, amount, timepoint
using LoopVectorization

# Set the backend to TurboBackend when this extension loads
function __init__()
    return VECTORIZATION_BACKEND[] = TurboBackend()
end

# @turbo implementation for TurboBackend. Two kernels (mirroring the split the base
# package can avoid): LoopVectorization macro-expands the loop body before inlining, so
# it can't see through the `_amt`/`_tim` accessors the @simd kernel uses to unify them —
# hiding the access behind a function call measured ~2.5× slower (vectorization is lost).
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

# `times === nothing` ⇒ a `Vector{<:Cashflow}` carrying its own amount/time.
function FinanceCore.__pv_div_pv′(::TurboBackend, r, cashflows::AbstractVector{<:Cashflow}, ::Nothing)
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
