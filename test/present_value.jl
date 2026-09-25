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
        # The empty sum: zero, of the type a present value of such cashflows has.
        for r in (0.05, Periodic(0.05, 1), Continuous(0.05))
            @test pv(r, Float64[]) === 0.0
            @test pv(r, Float64[], Float64[]) === 0.0
            @test pv(r, Int[], Int[]) === 0 * pv(r, [1], [1])
            @test pv(r, Cashflow{Float64, Float64}[]) === 0.0
        end
        # under ForwardDiff the empty sum is a dual number with zero partials
        @test iszero(ForwardDiff.derivative(r -> pv(r, Float64[], Float64[]), 0.05))
        @test iszero(ForwardDiff.derivative(r -> pv(Continuous(r), Cashflow{Float64, Float64}[]), 0.05))
        # an abstract element type has no typed zero
        @test_throws MethodError pv(0.05, Cashflow[])
        @test_throws MethodError pv(0.05, Any[])
    end

end
