module FinanceCore
import Roots
using Dates

include("Rates.jl")
export Rate, rate, compounding, discount, accumulation, Periodic, Continuous, forward


include("Contracts.jl")
export Cashflow, Quote, maturity, timepoint, amount, Composite

include("irr.jl")
export irr, internal_rate_of_return

include("irr_checked.jl")
export irr_checked, internal_rate_of_return_checked

include("pv.jl")
export pv, present_value

end
