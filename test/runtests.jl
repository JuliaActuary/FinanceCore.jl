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
    simd_result = FinanceCore.__pv_div_pv′(FinanceCore.SimdBackend(), 0.1, cfs, times, 0)
    turbo_result = FinanceCore.__pv_div_pv′(FinanceCore.TurboBackend(), 0.1, cfs, times, 0)
    @test simd_result ≈ turbo_result rtol = 1.0e-13
    # both kernels measure times from Newton's origin
    far = [1000.0, 1001.0]
    @test FinanceCore.__pv_div_pv′(FinanceCore.TurboBackend(), 0.1, cfs, far, 1000.0) ≈ simd_result rtol = 1.0e-13
    @test FinanceCore.__pv_div_pv′(FinanceCore.SimdBackend(), 0.1, cfs, far, 1000.0) ≈ simd_result rtol = 1.0e-13
    @test rate(irr(cfs, far)) ≈ 0.1
    # a range of integer times is differenced in integers: beyond 2^53 a one-unit step stays one unit
    @test FinanceCore._vectorization_backend(0.1, cfs, (2^53 + 1):(2^53 + 2)) isa FinanceCore.TurboBackend
    @test rate(irr(cfs, (2^53 + 1):(2^53 + 2))) ≈ 0.1 rtol = 1.0e-12
    @test rate(irr(cfs, (2^53):(2^53 + 1))) ≈ 0.1 rtol = 1.0e-12

    @test irr([-100, 110]) ≈ Periodic(0.1, 1)
    @test irr([-100.0, 110.0], [0.0, 1.0]) ≈ Periodic(0.1, 1)
    @test isnothing(irr([0.0, 0.0, 0.0]))
    @test isnothing(irr([100.0, 100.0], [1.0, 1.0]))
    @test irr([Cashflow(-100.0, 0.0), Cashflow(110.0, 1.0)]) ≈ Periodic(0.1, 1)
    # the turbo kernel also hands an overflowed derivative sum to the robust solver
    @test FinanceCore._vectorization_backend(0.1, [-1.0e307, 1.1e307], [0.0, 100.0]) isa
        FinanceCore.TurboBackend
    @test rate(irr([-1.0e307, 1.1e307], [0.0, 100.0])) ≈ 1.1^(1 / 100) - 1 rtol = 1.0e-12
end
