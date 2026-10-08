# A discount model that is not a constant rate: it discounts from time zero, but has no interval method.
struct LinearDiscount end
FinanceCore.discount(::LinearDiscount, t) = 1 - t / 100
FinanceCore.accumulation(::LinearDiscount, t) = 1 / (1 - t / 100)

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

    @testset "constructing from a number or a Rate" begin
        # the same rate: type, stored force and convention
        identical(a, b) = typeof(a) === typeof(b) && isequal(a.continuous_value, b.continuous_value) &&
            compounding(a) == compounding(b)
        D = ForwardDiff.Dual(0.03, 1.0)
        for x in (0.03, 0.03f0, big"0.03", D, 1)
            c = Rate(x, Continuous())
            @test c isa Rate{typeof(x), Continuous}
            @test c.continuous_value === x
            p = Rate(x, Periodic(2))
            @test p isa Rate{typeof(2 * log1p(x / 2)), Periodic}
            @test isequal(p.continuous_value, 2 * log1p(x / 2))
            # the numeric frequency shorthand
            @test identical(Rate(x, 2), p)
            @test identical(Rate(x, 2.0), p)
            @test identical(Rate(x, Inf), c)
            @test identical(Rate(x), Rate(x, Periodic(1)))

            # A Rate is returned as it is, or converted to another frequency, keeping its force and
            # numeric type exactly. Before 3.0, Rate(r, Continuous()) nested the rate in a new one.
            for r in (c, p)
                @test Rate(r) === r
                for f in (Continuous(), Periodic(1), Periodic(2), Periodic(12))
                    converted = @inferred Rate(r, f)
                    @test identical(converted, convert(f, r))
                    @test identical(converted, f(r))
                    @test converted.continuous_value === r.continuous_value
                    @test compounding(converted) == f
                end
                @test identical(Rate(r, 12), convert(Periodic(12), r))
                @test identical(Rate(r, Inf), convert(Continuous(), r))
            end
        end

        # Rates hold real numbers. Before 3.0, Rate("0.03", Continuous()) built a rate holding a string.
        @test_throws MethodError Rate("0.03", Continuous())
        @test_throws MethodError Rate("0.03", Periodic(2))
        @test_throws MethodError Rate(0.03 + 0.0im, Continuous())
        @test_throws TypeError Rate{String, Continuous}("0.03", Continuous())

        # The numeric constructors and the conversion dispatch disjointly.
        @test isempty(Test.detect_ambiguities(FinanceCore))
    end

    @testset "printing keeps the number type" begin
        @test repr(Continuous(0.03)) == "Continuous(0.03)"
        @test repr(Periodic(0.05, 2)) == "Periodic(0.05, 2)"
        # Before 3.0, these printed as Float64 rates.
        @test repr(Continuous(0.03f0)) == "Continuous(0.03f0)"
        @test repr(Periodic(0.05f0, 2)) == "Periodic(0.05f0, 2)"
        @test repr(Continuous(Float16(0.03))) == "Continuous(Float16(0.03))"
        # The output is a constructor expression for a rate of the same type.
        for r in (
                Continuous(0.03), Periodic(0.05, 2), Continuous(0.03f0), Periodic(0.05f0, 12),
                Continuous(Float16(0.03)), Periodic(Float16(0.05), 2), Continuous(1), Continuous(1 // 2),
            )
            printed = Core.eval(@__MODULE__, Meta.parse(repr(r)))
            @test typeof(printed) === typeof(r)
            @test printed ≈ r
        end
    end

    @testset "integer rate values" begin
        # Rate(1, Periodic(1)) — a 100% annual effective rate — previously threw
        # InexactError from converting the (irrational) continuous equivalent back
        # to the integer input type. The numeric parameter now follows the computed
        # continuous value instead.
        r = Rate(1, Periodic(1))
        @test r isa Rate{Float64, Periodic}
        @test rate(r) ≈ 1.0
        @test accumulation(r, 1) ≈ 2.0
        @test discount(r, 1) ≈ 0.5

        @test Periodic(1, 2) isa Rate{Float64, Periodic}
        @test Rate(2) isa Rate{Float64, Periodic}

        # a zero integer rate remains constructible
        @test rate(Rate(0, Periodic(4))) == 0.0

        # non-integer numeric types keep their type
        @test Rate(0.05f0, Periodic(2)) isa Rate{Float32, Periodic}
        @test Rate(big"0.05", Periodic(2)) isa Rate{BigFloat, Periodic}

        # integer-valued Continuous rates were already constructible; unchanged
        @test accumulation(Rate(1, Continuous()), 1) ≈ exp(1)
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

    @testset "conversion preserves the force of interest" begin
        originals = (
            Continuous(-40.0), Continuous(1000.0), Continuous(-0.0), Continuous(NaN), Continuous(Inf),
            Periodic(-0.9, 1), Periodic(0.05, 2), Periodic(0.07, 365), Rate(1, Periodic(1)),
            Continuous(0.03f0), Periodic(0.02f0, 12), Continuous(big"0.03"), Periodic(big"0.03", 4),
            Continuous(ForwardDiff.Dual(0.03, 1.0)), Periodic(ForwardDiff.Dual(0.03, 1.0), 2),
        )
        conventions = (Continuous(), Periodic(1), Periodic(2), Periodic(12), Periodic(365))
        for original in originals, convention in conventions
            converted = @inferred convert(convention, original)
            @test compounding(converted) == convention
            @test typeof(converted.continuous_value) === typeof(original.continuous_value)
            @test converted.continuous_value === original.continuous_value
            @test convention(original) === converted
            @test isequal(converted, original)
            @test hash(converted) == hash(original)
            @test isequal(discount(converted, 0.001), discount(original, 0.001))
            @test isequal(accumulation(converted, 0.001), accumulation(original, 0.001))
            @test isequal(convert(compounding(original), converted), original)
        end

        # Nominal quoting can saturate while the underlying force remains finite.
        negative = convert(Periodic(1), Continuous(-40.0))
        @test rate(negative) == -1.0
        @test discount(negative, 0.01) == exp(0.4)
        positive = convert(Periodic(1), Continuous(1000.0))
        @test rate(positive) == Inf
        @test discount(positive, 0.001) == exp(-1.0)

        # Conversion must retain AD partials, including when nominal quoting saturates.
        f(r) = discount(convert(Periodic(1), Continuous(r)), 0.01)
        @test ForwardDiff.derivative(f, -40.0) ≈ -0.01 * exp(0.4)
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

    @testset "nominal↔continuous round-trip precision" begin
        # The constructor stores n*log1p(r/n) and rate() inverts with n*expm1(cv/n),
        # so the nominal rate survives a construction round-trip to within a few ulps
        # even when r/n is small (log(1+x) alone loses ~x⁻¹·eps of relative precision).
        for f in (1, 2, 4, 12, 365), r in (1.0e-6, 1.0e-4, 0.01, 0.05, 0.5, -0.01, -0.2)
            @test rate(Periodic(r, f)) ≈ r rtol = 4 * eps()
        end

        # arithmetic in nominal space no longer accretes conversion noise
        @test rate(Periodic(0.01, 2) + Periodic(0.04, 2)) ≈ 0.05 rtol = 4 * eps()
        @test rate(Periodic(0.04, 2) - Periodic(0.01, 2)) ≈ 0.03 rtol = 4 * eps()

        # Float32 values stay Float32 and round-trip at Float32 precision
        r32 = Periodic(0.01f0, 12)
        @test rate(r32) isa Float32
        @test rate(r32) ≈ 0.01f0 rtol = 4 * eps(Float32)
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

    @testset "force-of-interest equality and hashing" begin
        p = Periodic(0.05, 2)
        c = convert(Continuous(), p)   # shares the internal continuous value exactly

        # == is force equality, consistent with <, >, and isapprox semantics
        @test p == c
        @test c == p
        @test isequal(p, c)
        @test hash(p) == hash(c)
        @test !(p < c) && !(p > c)   # equal force: neither ordering holds

        # same nominal rate, different frequency → different force
        @test Periodic(0.05, 2) != Periodic(0.05, 4)
        @test Continuous(0.03) != Continuous(0.04)

        # equality stays exact: economically equal but differently-rounded rates
        # are only ≈, never ==
        a = Periodic(0.02, 2)
        a_eq = Periodic((1 + 0.02 / 2)^2 - 1, 1)
        @test a != a_eq
        @test a ≈ a_eq

        # Dict/Set follow isequal/hash across compounding conventions
        @test length(Set([p, c])) == 1
        d = Dict(p => 1)
        @test d[c] == 1

        # mixed numeric types with exactly representable values
        @test Continuous(0.5) == Continuous(0.5f0)

        # NaN follows Base number semantics: == is false, isequal/hash agree
        n1 = Continuous(NaN)
        n2 = Continuous(NaN)
        @test n1 != n2
        @test isequal(n1, n2)
        @test hash(n1) == hash(n2)
    end

    @testset "numeric comparisons across compounding conventions" begin
        pairs = (
            (NaN, 0.03), (NaN, NaN), (-0.0, 0.0), (-Inf, Inf),
            (NaN32, 0.03), (big"NaN", 0.03f0), (-0.0f0, big"0.0"),
            (0.03f0, 0.04), (big"0.03", 0.04f0), (0.5f0, big"0.5"),
            (0, 1 // 2), (1 // 2, 0.5), (ForwardDiff.Dual(0.03, 1.0), 0.04),
            (-40.0, -41.0), (1000.0, 1001.0),
        )
        conventions = (Continuous(), Periodic(1), Periodic(12))
        # Conversion preserves the stored force and numeric type exactly, so the
        # raw seeds remain the comparison oracle under every compounding convention.
        for ca in conventions, cb in conventions, (x, y) in pairs
            a = convert(ca, Continuous(x))
            b = convert(cb, Continuous(y))
            for op in (<, >, <=, >=)
                @test op(a, b) == op(x, y)
                @test op(b, a) == op(y, x)
            end
            @test isless(a, b) == isless(x, y)
            @test isless(b, a) == isless(y, x)
        end

        # Compare forces even when nominal quotes have the opposite order.
        a = Periodic(0.05, 1)
        b = Continuous(0.049)
        @test rate(a) > rate(b)
        @test a < b
        @test b > a
        @test !(a > b)
        @test !(b < a)
    end

    @testset "isless and order-based Base functions" begin
        lo = Periodic(0.02, 2)
        hi = Continuous(0.05)

        # For ordinary finite values, isless agrees with numeric comparisons.
        @test isless(lo, hi)
        @test !isless(hi, lo)
        @test !isless(lo, lo)
        @test isless(lo, hi) == (lo < hi)
        # a periodic rate has a lower force than the same nominal rate compounded continuously
        @test isless(Periodic(0.03, 100), Continuous(0.03))
        @test !isless(Continuous(0.03), Periodic(0.03, 100))

        # order-based Base functions now work
        rs = [Continuous(0.05), Periodic(0.02, 2), Periodic(0.04, 12)]
        @test sort(rs) == [rs[2], rs[3], rs[1]]
        @test minimum(rs) == Periodic(0.02, 2)
        @test maximum(rs) == Continuous(0.05)
        @test extrema(rs) == (Periodic(0.02, 2), Continuous(0.05))
        @test min(lo, hi) == lo
        @test max(lo, hi) == hi
        @test clamp(Continuous(0.1), lo, hi) == hi
        @test clamp(Continuous(0.03), lo, hi) == Continuous(0.03)

        # mixed numeric types
        @test isless(Periodic(0.02f0, 2), Periodic(0.03, 2))

        # Sorting retains a total order: negative zero precedes positive zero,
        # and NaNs follow all other values, including infinity.
        ordered = [
            Continuous(-Inf), Periodic(-0.01f0, 12),
            convert(Periodic(1), Continuous(-0.0)), Continuous(0.0f0),
            Periodic(big"0.03", 2), Continuous(Inf),
            convert(Periodic(12), Continuous(NaN)),
        ]
        rs = ordered[[7, 4, 5, 1, 3, 6, 2]]
        @test isequal(sort(rs), ordered)
        @test isequal(sort(rs; rev = true), reverse(ordered))
        @test issorted(ordered)
        @test isequal(rs[sortperm(rs)], ordered)
    end

    @testset "mixed numeric type isapprox" begin
        # mixed numeric types previously recursed to a StackOverflowError
        @test Periodic(0.5f0, 2) ≈ Periodic(0.5, 2)
        @test Periodic(0.5, 2) ≈ Periodic(0.5f0, 2)
        @test Continuous(0.25f0) ≈ Continuous(0.25)
        @test Continuous(big"0.03") ≈ Continuous(0.03)
        @test Periodic(big"0.05", 2) ≈ Periodic(0.05, 2)
        # mixed numeric type and mixed compounding together
        @test convert(Continuous(), Periodic(0.5, 2)) ≈ Periodic(0.5f0, 2)
        @test Periodic(0.5f0, 2) ≈ convert(Continuous(), Periodic(0.5, 2))
        # still distinguishes genuinely different rates
        @test !(Periodic(0.05f0, 2) ≈ Periodic(0.06, 2))
        @test !(Continuous(0.03f0) ≈ Continuous(0.04))
    end

    @testset "Periodic frequency validation" begin
        # frequency 0 used to silently produce NaN rates (0 * log(Inf))
        @test_throws ArgumentError Periodic(0)
        @test_throws ArgumentError Periodic(-2)
        @test_throws ArgumentError Periodic(0.05, 0)
        @test_throws ArgumentError Periodic(0.05, -1)

        for frequency in (Int8(2), UInt16(2), Int32(2), big(2))
            @test Periodic(frequency) == Periodic(2)
            @test Rate(1, Periodic(frequency)) ≈ Periodic(1.0, 2)
            @test Periodic(Continuous(0.03), frequency) ≈ Periodic(Continuous(0.03), 2)
        end
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

        # a constant rate, given as a Rate or a number, discounts over `to - from`
        for r in (0.15, 3, 0.15f0, big"0.15", Periodic(0.15, 2), Continuous(0.15), ForwardDiff.Dual(0.15, 1.0))
            @test discount(r, from, to) == discount(r, to - from)
            @test accumulation(r, from, to) == accumulation(r, to - from)
            @test discount(r, 2.0, 1.0) == accumulation(r, 1.0, 2.0)
        end
        # any other model (a yield curve, say) defines its own interval, rather than falling back to
        # `to - from`, which is wrong unless the rate is constant
        @test discount(LinearDiscount(), 1.0) == 0.99
        @test_throws MethodError discount(LinearDiscount(), 1.0, 2.0)
        @test_throws MethodError accumulation(LinearDiscount(), 1.0, 2.0)
        @test_throws MethodError discount(Continuous(), from, to)

        # Only a number is taken as a rate, so anything else without its own method throws from
        # `discount` or `accumulation` itself. Before 3.0, it went to `Rate` and threw inside it.
        for f in (discount, accumulation), x in (Continuous(), "0.15", :rate)
            err = try
                f(x, 1.0)
            catch e
                e
            end
            @test err isa MethodError && err.f === f
        end
        for r in (0.15, 3, 0.15f0, big"0.15", 3 // 20, ForwardDiff.Dual(0.15, 1.0))
            @test discount(r, 2.0) == discount(Rate(r), 2.0)
            @test accumulation(r, 2.0) == accumulation(Rate(r), 2.0)
        end
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
