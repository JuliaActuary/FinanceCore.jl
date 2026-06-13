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

# Load LoopVectorization last: its extension flips VECTORIZATION_BACKEND for the
# remainder of the session, so these exercise the @turbo irr kernels.
using LoopVectorization
@testset "LoopVectorization extension" begin
    @test FinanceCore.VECTORIZATION_BACKEND[] isa FinanceCore.TurboBackend
    @test irr([-100, 110]) ≈ Periodic(0.1, 1)
    @test irr([-100, 110], [0, 1]) ≈ Periodic(0.1, 1)
    @test isnan(rate(irr([0.0, 0.0, 0.0])))
    @test irr([Cashflow(-100.0, 0.0), Cashflow(110.0, 1.0)]) ≈ Periodic(0.1, 1)
end
