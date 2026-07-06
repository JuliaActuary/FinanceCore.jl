@testset "DayCounts extension" begin
    d1 = Date(2024, 1, 1)
    d2 = Date(2024, 7, 1)

    conventions = (
        DayCounts.Actual365Fixed(),
        DayCounts.Actual360(),
        DayCounts.Thirty360(),
        DayCounts.ActualActualISDA(),
    )

    @testset "$(nameof(typeof(dc)))" for dc in conventions
        t = DayCounts.yearfrac(d1, d2, dc)

        # date methods agree exactly with the scalar-time methods at the
        # convention's year fraction, for Real and both Rate types
        @test discount(0.05, d1, d2, dc) == discount(0.05, t)
        @test accumulation(0.05, d1, d2, dc) == accumulation(0.05, t)
        @test discount(Continuous(0.05), d1, d2, dc) == exp(-0.05 * t)
        @test discount(Periodic(0.05, 2), d1, d2, dc) == discount(Periodic(0.05, 2), t)
        @test accumulation(Periodic(0.05, 2), d1, d2, dc) == accumulation(Periodic(0.05, 2), t)

        # discount and accumulation invert each other
        @test discount(Periodic(0.05, 2), d1, d2, dc) * accumulation(Periodic(0.05, 2), d1, d2, dc) ≈ 1.0
    end

    # a degenerate interval discounts to exactly 1
    @test discount(Continuous(0.03), d1, d1, DayCounts.Actual365Fixed()) == 1.0

    # reversed dates give a negative year fraction, so discount inverts
    t = DayCounts.yearfrac(d1, d2, DayCounts.Actual365Fixed())
    @test discount(Continuous(0.03), d2, d1, DayCounts.Actual365Fixed()) ≈ exp(0.03 * t)
end
