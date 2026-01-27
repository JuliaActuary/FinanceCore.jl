module FinanceCore
import Roots
using Compat: @compat
using Dates

include("Rates.jl")
export Rate, rate, discount, accumulation, Periodic, Continuous, forward
# Frequency is the abstract supertype of Continuous and Periodic
@compat public Frequency


include("Contracts.jl")
export Cashflow, Quote, maturity, timepoint, amount, Composite
# AbstractContract is the abstract supertype of Cashflow and Composite
# Timepoint is a type alias useful for type annotations
@compat public AbstractContract, Timepoint

include("irr.jl")
export irr, internal_rate_of_return

include("pv.jl")
export pv, present_value

end
