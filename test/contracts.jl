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

    @testset "addition requires exactly equal times" begin
        function grouped(f)
            return try
                f()
            catch e
                e isa ArgumentError || rethrow()
                :throws
            end
        end
        # addition is associative: both groupings throw, or both are defined and equal
        associates(a, b, c) = grouped(() -> (a + b) + c) == grouped(() -> a + (b + c))

        # times within `isapprox` tolerance of their neighbours, but not of each other
        a, b, c = Cashflow(1.0, 1.0), Cashflow(2.0, 1.0 + 1.0e-8), Cashflow(4.0, 1.0 + 2.0e-8)
        @test associates(a, b, c)
        @test_throws ArgumentError (a + b) + c
        @test_throws ArgumentError a + (b + c)
        @test_throws ArgumentError a + b
        @test_throws ArgumentError a - b
        @test Cashflow(1.0, 1.0) ≈ Cashflow(1.0, 1.0 + 1.0e-8)    # isapprox keeps its tolerance

        a, b, c = Cashflow(1.0, 2.5), Cashflow(2.0, 2.5), Cashflow(4.0, 2.5)
        @test associates(a, b, c)
        @test (a + b) + c == Cashflow(7.0, 2.5)
        @test a - b == Cashflow(-1.0, 2.5)

        # signed zeros are equal times
        @test Cashflow(1.0, -0.0) + Cashflow(2.0, 0.0) ≈ Cashflow(3.0, 0.0)
        @test Cashflow(1.0, 0.0) - Cashflow(2.0, -0.0) ≈ Cashflow(-1.0, 0.0)

        d = Date(2026, 6, 30)
        a, b, c = Cashflow(1.0, d), Cashflow(2.0, d), Cashflow(4.0, d)
        @test associates(a, b, c)
        @test (a + b) + c == Cashflow(7.0, d)
        @test associates(a, b, Cashflow(4.0, d + Day(1)))
    end

    @testset "aggregate" begin
        cfs = [Cashflow(1.0, 2.0), Cashflow(2.0, 0.5), Cashflow(3.0, 2.0), Cashflow(-1.5, 1.2), Cashflow(4.0, 0.5)]
        total(x) = sum(amount, x)

        # merging exactly equal times preserves the total and the present value
        merged = FinanceCore.aggregate(cfs)
        @test merged == [Cashflow(6.0, 0.5), Cashflow(-1.5, 1.2), Cashflow(4.0, 2.0)]
        @test total(merged) == total(cfs)
        for r in (0.05, Periodic(0.04, 2), Continuous(0.03))
            @test pv(r, merged) ≈ pv(r, cfs)
        end
        @test FinanceCore.aggregate(reverse(cfs)) == merged

        # a rounding key preserves the total, but moves cashflows to other times, which changes
        # their present value
        rounded = FinanceCore.aggregate(cfs; key = round)
        @test rounded == [Cashflow(6.0, 0.0), Cashflow(-1.5, 1.0), Cashflow(4.0, 2.0)]
        @test total(rounded) == total(cfs)
        for r in (0.05, Periodic(0.04, 2), Continuous(0.03))
            @test !(pv(r, rounded) ≈ pv(r, cfs))
        end

        # signed zeros are one time
        @test length(FinanceCore.aggregate([Cashflow(1.0, 0.0), Cashflow(2.0, -0.0)])) == 1

        dates = [Cashflow(1.0, Date(2026, 1, 15)), Cashflow(2.0, Date(2026, 2, 1)), Cashflow(3.0, Date(2026, 1, 31))]
        @test FinanceCore.aggregate(dates; key = lastdayofmonth) ==
            [Cashflow(4.0, Date(2026, 1, 31)), Cashflow(2.0, Date(2026, 2, 28))]
        @test FinanceCore.aggregate(Cashflow{Float64, Float64}[]) == Cashflow{Float64, Float64}[]
    end

    @testset "isapprox numeric precision" begin
        @test Cashflow(1.0f0, 1.0f0) ≈ Cashflow(1.0f0 + 1.0f-5, 1.0f0 + 1.0f-5)

        one_big = big"1.0"
        delta_big = big"1.0e-20"
        @test !(
            Cashflow(one_big, one_big) ≈
                Cashflow(one_big + delta_big, one_big + delta_big)
        )

        @test isapprox(
            Cashflow(one_big, one_big),
            Cashflow(one_big + delta_big, one_big + delta_big); atol = big"1.0e-19"
        )
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
