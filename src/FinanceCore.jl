module FinanceCore
import Roots
using LoopVectorization
using Dates

include("Rates.jl")
export AbstractYield, Rate, rate, discount, accumulation, Periodic, Continuous, forward

include("irr.jl")
export irr, internal_rate_of_return

include("Contracts.jl")
export Cashflow, Quote, maturity

include("pv.jl")
export pv, present_value

end
