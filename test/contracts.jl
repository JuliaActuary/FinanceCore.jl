@testset "cashflows" begin
    cf11 = Cashflow(1, 1)

    @testset "Amounts & Times" begin
        @test amount(cf11) == 1
        @test amount(1) == 1

        @test maturity(cf11) == 1
        @test timepoint(cf11) == 1
        @test timepoint(cf11, 4) == 1
        @test timepoint(1, 2) == 2

        q = Quote(1.0, cf11)

        @test maturity(q) ≈ maturity(cf11)
        @test q ≈ Quote(1, cf11)
    end

    @testset "algebra" begin
        @test cf11 == cf11
        @test cf11 ≈ Cashflow(1.0, 1.0)
        @test -cf11 ≈ Cashflow(-1.0, 1.0)

        @test cf11 + cf11 == Cashflow(2, 1)
        @test cf11 - cf11 == Cashflow(0, 1)
        @test cf11 * 2 == Cashflow(2, 1)
        @test cf11 / 2 ≈ Cashflow(0.5, 1)
        @test 2 * cf11 == Cashflow(2, 1)
        @test Cashflow(1.0, 1.0) + Cashflow(1.0, 1.0) ≈ Cashflow(2.0, 1.0)
        @test_throws ArgumentError cf11 + Cashflow(1, 2)

        @test pv(0.0, cf11) ≈ 1.0
        @test pv(0.05, cf11) ≈ 1.0 / 1.05
    end

    @testset "Composite" begin
        cp = Composite(cf11, Cashflow(2, 3))
        @test maturity(cp) == 3
        @test maturity(Composite(cp, Cashflow(1, 5))) == 5
        @test cp.a == cf11
        @test cp.b == Cashflow(2, 3)
    end

    @testset "Date-typed Cashflow" begin
        d = Date(2026, 6, 30)
        cf = Cashflow(100.0, d)
        @test amount(cf) == 100.0
        @test timepoint(cf) == d
        @test maturity(cf) == d
        @test -cf == Cashflow(-100.0, d)
        @test cf * 2 == Cashflow(200.0, d)
        @test cf + Cashflow(50.0, d) == Cashflow(150.0, d)
        @test_throws ArgumentError cf + Cashflow(1.0, Date(2027, 6, 30))
    end

end
