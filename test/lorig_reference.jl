# M. Lorig, An Introduction to Financial Derivatives: Open Lecture Notes (2026),
# arXiv:2611.01355v1. Parameters below are chosen to exercise the cited results.
@testset "Lorig: compounding and certain cashflows" begin
    @testset "compounding over a fixed horizon" begin
        # Section 2.3, Eq. (2.1): m counts all compoundings over t, whereas
        # Periodic takes the frequency per unit time, so its frequency is m/t.
        # https://arxiv.org/html/2611.01355v1#Ch2.S3
        for (r, t, m) in ((0.1, 2.0, 4), (0.07, 2.5, 5), (0.03, 0.25, 3))
            periodic = Periodic(r, Int(m / t))
            compound = accumulation(periodic, t)
            continuous = accumulation(Continuous(r), t)
            @test compound ≈ (1 + r * t / m)^m
            @test 1 + r * t < compound < continuous
            @test continuous ≈ exp(r * t)
            @test discount(periodic, t) ≈ (1 + r * t / m)^(-m)
        end
    end

    @testset "a fair exchange of two cashflows" begin
        # Exercise 2.2 and its solution, Eqs. (A.38)-(A.42).
        # Receive CF1 at t1 and V0 now; pay CF2 at t2. Both sides must have equal PV.
        # https://arxiv.org/html/2611.01355v1#Ch2.Thmexercise2
        r, t1, t2, cf2 = 0.05, 0.5, 2.0, 100.0
        threshold = exp(-r * (t2 - t1))
        for ratio in (threshold / 2, threshold, 2threshold, -0.5)
            cf1 = ratio * cf2
            expected = cf2 * exp(-r * t2) - cf1 * exp(-r * t1)
            flows = [Cashflow(-cf1, t1), Cashflow(cf2, t2)]
            v0 = pv(Continuous(r), flows)
            @test v0 ≈ expected atol = 1.0e-12
            @test pv(Continuous(r), [Cashflow(-v0, 0.0); flows]) ≈ 0 atol = 1.0e-12
            if ratio == threshold
                @test abs(v0) <= 1.0e-12
            else
                @test (v0 > 0) == (ratio < threshold)
            end
        end
    end
end
