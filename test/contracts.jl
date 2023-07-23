@testset "cashflows" begin
    cf11 = Cashflow(1, 1)

    @testset "Amounts & Times" begin
        @test amount(cf11) == 1
        @test amount(1) == 1

        @test maturity(cf11) == 1
        @test timepoint(cf11) == 1
    end

    @testset "algebra" begin
        @test cf11 == cf11
        @test cf11 ≈ Cashflow(1.0, 1.0)

        @test cf11 + cf11 == Cashflow(2, 1)
        @test cf11 - cf11 == Cashflow(0, 1)
        @test cf11 * 2 == Cashflow(2, 1)
        @test cf11 / 2 ≈ Cashflow(0.5, 1)
        @test 2 * cf11 == Cashflow(2, 1)
        @test Cashflow(1.0, 1.0) + Cashflow(1.0, 1.0) ≈ Cashflow(2.0, 1.0)
        @test_throws ArgumentError cf11 + Cashflow(1, 2)

    end

    @testset "Composite" begin
        #TODO
    end

end