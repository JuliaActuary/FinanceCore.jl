module FinanceCoreLoopVectorizationExt

using FinanceCore
using FinanceCore: TurboBackend
using LoopVectorization

const TurboFloat = Union{Float32, Float64}

FinanceCore._vectorization_backend(
    r::T,
    cashflows::StridedVector{T},
    times::StridedVector{T},
) where {T <: TurboFloat} = TurboBackend()

# @turbo implementation for TurboBackend
function FinanceCore.__pv_div_pv′(
        ::TurboBackend,
        r::T,
        cashflows::StridedVector{T},
        times::StridedVector{T},
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
