module FinanceCore
import Roots
using LoopVectorization

include("AbstractYield.jl")

include("Rates.jl")
export AbstractYield, Rate, rate, discount, accumulation, Periodic, Continuous, forward

include("irr.jl")
export irr, internal_rate_of_return
end
