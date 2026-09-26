@testset "pv" begin
    cf = [100, 100]

    @test pv(0.05, cf) ≈ cf[1] / 1.05 + cf[2] / 1.05^2
    @test pv(0.05, @view(cf[:])) ≈ cf[1] / 1.05 + cf[2] / 1.05^2

    # this vector came from Numpy Financial's test suite with target of 122.89, but that assumes payments are begin of period
    # 117.04 comes from Excel verification with NPV function
    @test isapprox(pv(0.05, [-15000, 1500, 2500, 3500, 4500, 6000]), 117.04, atol = 1.0e-2)


    @testset "pv with timepoints" begin
        cf = [100, 100]

        @test pv(0.05, cf, [1, 2]) ≈ cf[1] / 1.05 + cf[2] / 1.05^2

        # ActuaryUtilities.jl issue #58
        r = Periodic(0.02, 1)
        @test present_value(r, [1, 2]) ≈ 1 / 1.02 + 2 / 1.02^2
    end

    @testset "empty cashflows" begin
        # The empty sum is exactly zero. For concrete amount, time and rate types it has the type
        # a present value of such cashflows has.
        for r in (0.05, Periodic(0.05, 1), Continuous(0.05))
            @test pv(r, Float64[]) === 0.0
            @test pv(r, Float64[], Float64[]) === 0.0
            @test pv(r, Int[], Int[]) === 0 * pv(r, [1], [1])
            @test pv(r, Cashflow{Float64, Float64}[]) === 0.0
            @test pv(r, BigFloat[]) isa BigFloat
            @test iszero(pv(r, BigFloat[]))
        end
        @test pv(0.05, Float32[]) === 0.0          # a Float64 rate, as for nonempty Float32 amounts
        @test typeof(pv(0.05, Float32[])) == typeof(pv(0.05, Float32[1, 2]))
        @test pv(Periodic(0.05f0, 1), Float32[]) === 0.0f0
        @test pv(big"0.05", Float64[]) isa BigFloat
        # under ForwardDiff the empty sum is a dual number with zero partials
        @test iszero(ForwardDiff.derivative(r -> pv(r, Float64[], Float64[]), 0.05))
        @test iszero(ForwardDiff.derivative(r -> pv(Continuous(r), Cashflow{Float64, Float64}[]), 0.05))
        @test pv(ForwardDiff.Dual(0.05, 1.0), Float64[]) isa ForwardDiff.Dual
        # When the element type says nothing about the amounts or times, the rate decides the type.
        for x in (Any[], Real[], Number[], Cashflow[], (), (a for a in Float64[]), Dict{Int, Float64}())
            @test pv(0.05, x) === 0.0
            @test pv(big"0.05", x) isa BigFloat
            @test iszero(pv(big"0.05", x))
        end
        @test pv(0.05, Float64[], Any[]) === 0.0
        @test iszero(ForwardDiff.derivative(r -> pv(r, Any[]), 0.05))
        # The zero does not depend on the rate's value: evaluating Continuous(Inf) at time zero
        # gives NaN, but the empty present value is a positive zero of the valuation's type.
        @test pv(Continuous(Inf), Float64[]) === 0.0
        @test pv(Continuous(Inf), Any[]) === 0.0
        @test !signbit(pv(Continuous(Inf), Float64[]))
        @test !signbit(pv(Continuous(-Inf), Float64[]))
        @test !signbit(pv(Continuous(NaN), Float64[]))
        @test !signbit(pv(Continuous(-NaN), Float64[]))
    end

end
