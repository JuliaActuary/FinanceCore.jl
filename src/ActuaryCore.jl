module ActuaryCore
import Roots

include("AbtractYield.jl")

include("Rates.jl")
export Rate, rate, discount, accumulation, Periodic, Continuous, forward

include("irr.jl")
export irr, internal_rate_of_return
end
