@testset "Rates" begin
    @testset "rate types" begin
        rs = Rate.([0.1, 0.02], Continuous())
        @test rs[1] == Rate(0.1, Continuous())
        @test rs[1] == Continuous(0.1)
        @test rate(rs[1]) == 0.1
    end

    @testset "constructor" begin
        @test Continuous(0.05) == Rate(0.05, Continuous())
        @test Periodic(0.02, 2) == Rate(0.02, Periodic(2))

        @test Continuous()(0.05) == Rate(0.05, Continuous())
        @test Periodic(2)(0.02) == Rate(0.02, Periodic(2))


        @test Rate(0.02, 2) == Rate(0.02, Periodic(2))
        @test Rate(0.02, Inf) == Rate(0.02, Continuous())

    end

    @testset "rate conversions" begin
        m = Rate(0.1, Periodic(2))
        @test convert(Periodic(2), 0.1) ≈ m
        @test convert(Periodic(2), m) ≈ m
        @test Periodic(m, 2) ≈ m
        @test Periodic(2)(m) ≈ m
        @test convert(Continuous(), m) ≈ Rate(0.09758, Continuous()) atol = 1.0e-5
        @test Continuous(m) ≈ Rate(0.09758, Continuous()) atol = 1.0e-5
        @test Continuous()(m) ≈ Rate(0.09758, Continuous()) atol = 1.0e-5

        c = Rate(0.09758, Continuous())
        @test convert(Continuous(), c) == c
        @test convert(Continuous(), 0.09758) == c
        @test Continuous(c) == c
        @test Continuous()(c) == c
        @test convert(Periodic(2), c) ≈ Rate(0.1, Periodic(2)) atol = 1.0e-5
        @test Periodic(2)(c) ≈ Rate(0.1, Periodic(2)) atol = 1.0e-5
        @test Periodic(c, 2) ≈ Rate(0.1, Periodic(2)) atol = 1.0e-5
        @test convert(Periodic(2), c) ≈ Rate(0.1, Periodic(2)) atol = 1.0e-5
        @test convert(Periodic(2), c) ≈ Rate(0.1, Periodic(2)) atol = 1.0e-5
        @test convert(Periodic(4), m) ≈ Rate(0.09878030638383972, Periodic(4)) atol = 1.0e-5

    end

    @testset "rate() function returns original value" begin
        # Test rate() returns original value for Continuous
        c = Rate(0.05, Continuous())
        @test rate(c) == 0.05

        # Test rate() returns original value for Periodic (not the internal continuous_value)
        # Note: For Periodic rates, rate() is computed dynamically from continuous_value,
        # so there may be small floating-point differences
        p = Rate(0.04, Periodic(2))
        @test rate(p) ≈ 0.04

        # Verify rate() is correct after arithmetic
        p2 = Periodic(0.04, 2) + 0.01
        @test rate(p2) ≈ 0.05

        c2 = Continuous(0.03) * 2
        @test rate(c2) == 0.06
    end

    @testset "compounding() function returns compounding frequency" begin
        # Test compounding() returns Continuous() for continuous rates
        c = Rate(0.05, Continuous())
        @test compounding(c) == Continuous()

        # Test compounding() returns Periodic(n) for periodic rates
        p = Rate(0.04, Periodic(2))
        @test compounding(p) == Periodic(2)

        # Test with different frequencies
        p4 = Rate(0.06, Periodic(4))
        @test compounding(p4) == Periodic(4)

        # Verify compounding() is correct after arithmetic
        p2 = Periodic(0.04, 2) + 0.01
        @test compounding(p2) == Periodic(2)

        c2 = Continuous(0.03) * 2
        @test compounding(c2) == Continuous()
    end

    @testset "conversion roundtrip preserves discount" begin
        # Start with Periodic, convert to Continuous, back to Periodic
        original = Periodic(0.05, 4)
        continuous = convert(Continuous(), original)
        back = convert(Periodic(4), continuous)
        @test rate(back) ≈ rate(original) atol = 1.0e-10
        @test discount(original, 5) ≈ discount(back, 5) atol = 1.0e-10

        # Verify that converting Periodic to Continuous gives equivalent discount
        p = Periodic(0.1, 2)
        c = convert(Continuous(), p)
        @test discount(p, 10) ≈ discount(c, 10) atol = 1.0e-10
    end

    @testset "rate equality" begin
        a = Periodic(0.02, 2)
        a_eq = Periodic((1 + 0.02 / 2)^2 - 1, 1)
        b = Periodic(0.03, 2)
        c = Continuous(0.02)

        @test a == a
        @test !(a == a_eq) # not equal due to floating point error
        @test a ≈ a_eq
        @test a != b
        @test ~(a ≈ b)
        @test (a ≈ a)
        @test ~(a ≈ c)

    end

    @testset "discounting and accumulation" for t in [-1.3, 2.46, 6.7]

        unspecified_rate = 0.035
        periodic_rate = Periodic(0.02, 2)
        continuous_rate = Continuous(0.03)

        @test discount(unspecified_rate, t) ≈ (1 + 0.035)^(-t)
        @test discount(periodic_rate, t) ≈ (1 + 0.02 / 2)^(-t * 2)
        @test discount(continuous_rate, t) ≈ exp(-0.03 * t)

        @test accumulation(unspecified_rate, t) ≈ (1 + 0.035)^t
        @test accumulation(periodic_rate, t) ≈ (1 + 0.02 / 2)^(t * 2)
        @test accumulation(continuous_rate, t) ≈ exp(0.03 * t)

    end

    @testset "rate over interval" begin

        from = -0.45
        to = 3.4
        rate = 0.15

        @test discount(rate, from, to) ≈ discount(rate, to - from)
        @test accumulation(rate, from, to) ≈ accumulation(rate, to - from)

    end

    @testset "Compounding Interface" begin
        c = Continuous(0.03)
        p = Periodic(0.04, 2)

        @test zero(c, 2) ≈ c
        @test zero(p, 2) ≈ p
        @test forward(c, 2) ≈ c
        @test forward(p, 2) ≈ p

        @test discount(c, 2) ≈ exp(-2 * 0.03)
        @test discount(p, 2) ≈ 1 / (1 + 0.04 / 2)^(2 * 2)

        @test discount(c, 2) ≈ 1 / accumulation(c, 2)
        @test discount(p, 2) ≈ 1 / accumulation(p, 2)


    end

    @testset "rate algebra" begin

        a = 0.03
        b = 0.02

        @testset "addition" begin
            c(x) = Continuous(x)
            p(x) = Periodic(x, 1)

            @test c(a) + b ≈ Continuous(0.05)
            @test a + c(b) ≈ Continuous(0.05)

            @test p(a) + b ≈ Periodic(0.05, 1)
            @test a + p(b) ≈ Periodic(0.05, 1)

            @test p(a) + c(b) ≈ p(a) + Periodic(1)(c(b))
            @test c(a) + p(b) ≈ c(a) + Continuous()(p(b))
        end

        @testset "multiplication" begin
            c(x) = Continuous(x)
            p(x) = Periodic(x, 1)

            @test c(a) * b ≈ Continuous(a * b)
            @test a * c(b) ≈ Continuous(a * b)

            @test p(a) * b ≈ Periodic(a * b, 1)
            @test a * p(b) ≈ Periodic(a * b, 1)
        end

        @testset "division" begin
            c(x) = Continuous(x)
            p(x) = Periodic(x, 1)

            @test c(a) / b ≈ Continuous(a / b)
            @test_throws MethodError a / c(b) ≈ Continuous(a / b)

            @test p(a) / b ≈ Periodic(a / b, 1)
            @test_throws MethodError a / p(b) ≈ Periodic(a / b, 1)
        end

        @testset "subtraction" begin
            c(x) = Continuous(x)
            p(x) = Periodic(x, 1)

            @test c(a) - b ≈ Continuous(0.01)
            @test a - c(b) ≈ Continuous(0.01)

            @test p(a) - b ≈ Periodic(0.01, 1)
            @test a - p(b) ≈ Periodic(0.01, 1)
        end

        @testset "Rate and Rate" begin
            r = Periodic(0.04, 2) - Periodic(0.01, 2)
            @test r ≈ Periodic(0.03, 2)
            r = Periodic(0.04, 2) + Periodic(0.01, 2)
            @test r ≈ Periodic(0.05, 2)

            @test Periodic(0.04, 1) > Periodic(0.03, 2)
            @test Periodic(0.03, 1) < Periodic(0.04, 2)
            @test ~(Periodic(0.04, 1) < Periodic(0.03, 2))
            @test ~(Periodic(0.03, 1) > Periodic(0.04, 2))

            @test Periodic(0.03, 1) < Periodic(0.03, 2)
            @test Periodic(0.03, 100) < Continuous(0.03)
            @test Periodic(0.03, 2) > Periodic(0.03, 1)
            @test Continuous(0.03) > Periodic(0.03, 100)
        end
    end

end
