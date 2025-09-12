@testset "pv" begin
    cf = [100, 100]

    @test pv(0.05, cf) ≈ cf[1] / 1.05 + cf[2] / 1.05^2

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

end
