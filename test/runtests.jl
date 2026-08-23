using FinanceCore
using Test
using Dates
using ForwardDiff
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
    @test FinanceCore._vectorization_backend(0.1, [-100.0, 110.0], 0:1) isa
        FinanceCore.TurboBackend
    @test FinanceCore._vectorization_backend(0.1, [-100, 110], [0, 1]) isa
        FinanceCore.SimdBackend
    @test FinanceCore._vectorization_backend(
        0.1,
        [Cashflow(-100.0, 0.0), Cashflow(110.0, 1.0)],
    ) isa FinanceCore.SimdBackend

    cfs = [-100.0, 110.0]
    times = 0:1
    simd_result = FinanceCore.__pv_div_pv′(FinanceCore.SimdBackend(), 0.1, cfs, times)
    turbo_result = FinanceCore.__pv_div_pv′(FinanceCore.TurboBackend(), 0.1, cfs, times)
    @test simd_result ≈ turbo_result rtol = 1.0e-13

    @test irr([-100, 110]) ≈ Periodic(0.1, 1)
    @test irr([-100.0, 110.0], [0.0, 1.0]) ≈ Periodic(0.1, 1)
    @test isnothing(irr([0.0, 0.0, 0.0]))
    @test isnothing(irr([100.0, 100.0], [1.0, 1.0]))
    @test irr([Cashflow(-100.0, 0.0), Cashflow(110.0, 1.0)]) ≈ Periodic(0.1, 1)
end
