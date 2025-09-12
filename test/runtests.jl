using FinanceCore
using Test
using Dates
import DayCounts


include("Rates.jl")
include("irr.jl")
include("present_value.jl")
include("contracts.jl")

using Aqua
@testset "Aqua.jl" begin
    Aqua.test_all(FinanceCore; ambiguities = false)
end
