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
    Aqua.test_all(FinanceCore)
end

# Loading LoopVectorization adds narrow, argument-based methods without mutating
# a process-global backend.
using LoopVectorization
@testset "LoopVectorization extension" begin
    @test !isdefined(FinanceCore, :VECTORIZATION_BACKEND)
    @test FinanceCore._vectorization_backend(0.1, [-100.0, 110.0], [0.0, 1.0]) isa
        FinanceCore.TurboBackend
    @test FinanceCore._vectorization_backend(0.1, [-100, 110], [0, 1]) isa
        FinanceCore.SimdBackend
    @test FinanceCore._vectorization_backend(
        0.1,
        [Cashflow(-100.0, 0.0), Cashflow(110.0, 1.0)],
    ) isa FinanceCore.SimdBackend
    @test irr([-100, 110]) ≈ Periodic(0.1, 1)
    @test irr([-100.0, 110.0], [0.0, 1.0]) ≈ Periodic(0.1, 1)
    @test isnothing(irr([0.0, 0.0, 0.0]))
    @test irr([Cashflow(-100.0, 0.0), Cashflow(110.0, 1.0)]) ≈ Periodic(0.1, 1)
end
