module FinanceCoreLoopVectorizationExt

using FinanceCore
using FinanceCore: TurboBackend
using LoopVectorization

# The public IRR solver currently seeds Newton iteration with a Float64, so its
# Float32 cashflow path falls back to SIMD. Float32 remains valid for direct and
# future type-preserving solver calls.
const TurboFloat = Union{Float32, Float64}
const TurboTimes{T} = Union{StridedVector{T}, AbstractRange{Int}}

FinanceCore._vectorization_backend(
    r::T,
    cashflows::StridedVector{T},
    times::TurboTimes{T},
) where {T <: TurboFloat} = TurboBackend()

# @turbo implementation for inputs that pass LoopVectorization.check_args.
# Reassociation and LoopVectorization's exp may differ from the SIMD result by
# approximately one ulp.
function FinanceCore.__pv_div_pv′(
        ::TurboBackend,
        r::T,
        cashflows::StridedVector{T},
        times::TurboTimes{T},
    ) where {T <: TurboFloat}
    n = 0.0
    d = 0.0
    @turbo for i in eachindex(cashflows)
        cf = cashflows[i]
        t = times[i]
        a = cf * exp(-r * t)
        n += a
        d += a * -t
    end
    return n / d
end

end
