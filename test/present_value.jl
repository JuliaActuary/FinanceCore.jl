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

    @testset "vectors of amounts and times pair by index" begin
        # different lengths throw; 2.x dropped the extra entries
        r = Continuous(0.03)
        @test_throws DimensionMismatch pv(r, [1.0, 2.0, 3.0], [1.0, 2.0])
        @test_throws DimensionMismatch pv(r, [1.0, 2.0], [1.0, 2.0, 3.0])
        @test_throws DimensionMismatch pv(0.05, [1.0, 2.0], 1:3)
        @test_throws DimensionMismatch pv(r, [Cashflow(1.0, 1.0), Cashflow(2.0, 2.0)], [1.0])

        # Valid vectors give the bits of the index-range reduction this replaced (feb655e).
        index_range_sum(r, x, t) = mapreduce(
            k -> FinanceCore._present_value_at(r, x[firstindex(x) + k], t[firstindex(t) + k]), +,
            0:(min(length(x), length(t)) - 1)
        )
        same(a, b) = typeof(a) === typeof(b) && isequal(a, b)
        amounts(T, n) = [T(100 * sin(k)) for k in 1:n]
        for (r, x, t) in (
                (Continuous(0.03), amounts(Float64, 40), [k / 3 for k in 1:40]),
                (Periodic(0.04, 2), amounts(Float64, 2000), 1:2000),
                (Continuous(0.03f0), amounts(Float32, 40), Float32[k / 3 for k in 1:40]),
                (Periodic(big"0.05", 1), amounts(BigFloat, 20), 0.5:0.5:10),
                (Continuous(0.03), [Cashflow(100 * sin(k), k / 3) for k in 1:40], 1:40),
            )
            @test same(pv(r, x, t), index_range_sum(r, x, t))
        end
        x = amounts(Float64, 40)
        @test same(pv(0.05, x, 1:40), index_range_sum(Rate(0.05), x, 1:40))
    end

    @testset "amounts are paid at their times, Cashflows at their own" begin
        r = Continuous(0.03)
        # an amount in a collection is paid at its key
        @test pv(r, [10, 20]) == 10 * discount(r, 1) + 20 * discount(r, 2)
        @test pv(r, [10, 20]) == pv(r, [10, 20], [1, 2])
        @test pv(r, Dict(1.5 => 10.0)) == 10.0 * discount(r, 1.5)
        # a Cashflow's own time wins over the paired time
        cfs = [Cashflow(10.0, 0.5), Cashflow(20.0, 2.5)]
        @test pv(r, cfs, [1, 2]) == pv(r, [10.0, 20.0], [0.5, 2.5])
        @test pv(r, cfs, [1, 2]) == pv(r, cfs)
        @test pv(0.05, cfs, [1, 2]) == pv(0.05, [10.0, 20.0], [0.5, 2.5])
        # a number is paid at its key, and a Cashflow at its time
        @test pv(r, Any[10, Cashflow(5, 3.5)]) == 10 * discount(r, 1) + 5 * discount(r, 3.5)
        # a Cashflow carries its time, so there is no time to pass with it
        @test_throws MethodError pv(r, Cashflow(1.0, 3.0), 1.0)
        @test_throws MethodError pv(0.05, Cashflow(1.0, 3.0), 1.0)
    end

    @testset "collections of contracts are valued linearly" begin
        a, b, c = Cashflow(10.0, 1.5), Cashflow(-4.0, 0.25), Cashflow(7, 3)
        for r in (0.05, Periodic(0.04, 2), Continuous(0.03), Continuous(0.03f0))
            # a collection of one contract is that contract
            @test pv(r, [a]) === pv(r, a)
            @test pv(r, (a,)) === pv(r, a)
            @test pv(r, Any[a]) === pv(r, a)
            # linearity, whatever the order
            @test pv(r, [a, b]) ≈ pv(r, a) + pv(r, b)
            @test pv(r, [a, b]) ≈ pv(r, [b, a])
            @test pv(r, [a, b, c]) ≈ pv(r, [c, a, b])
            # tuples, Dicts and nested collections
            @test pv(r, (a, b, c)) ≈ pv(r, [a, b, c])
            @test pv(r, Dict(:a => a, :b => b, :c => c)) ≈ pv(r, [a, b, c])
            @test pv(r, Any[a, [b, c]]) ≈ pv(r, a) + pv(r, [b, c])
            @test pv(r, Any[[a], (b, Any[c])]) ≈ pv(r, [a, b, c])
            # a nested collection of amounts is paid at its own keys
            @test pv(r, Any[a, [10, 20]]) ≈ pv(r, a) + pv(r, [10, 20])
            # Composite
            @test pv(r, Composite(a, b)) ≈ pv(r, a) + pv(r, b)
            @test pv(r, Composite(Composite(a, b), c)) ≈ pv(r, Composite(a, Composite(b, c)))
            @test pv(r, Composite(Composite(a, b), c)) ≈ pv(r, [a, b, c])
            @test pv(r, [Composite(a, b), c]) ≈ pv(r, [a, b, c])
        end
        # derivatives are linear too
        d(x) = ForwardDiff.derivative(r -> pv(Continuous(r), x), 0.03)
        @test d([a, b]) ≈ d(a) + d(b)
        @test d(Composite(a, b)) ≈ d(a) + d(b)
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
        # collections of contracts, empty or holding empty collections
        for x in (FinanceCore.AbstractContract[], Cashflow[], Any[], Any[Any[], Cashflow[]])
            @test pv(0.05, x) === 0.0
            @test pv(Continuous(0.05), x) === 0.0
            @test pv(0.05f0, x) === 0.0f0
            @test pv(Periodic(0.05f0, 1), x) === 0.0f0
            @test pv(big"0.05", x) isa BigFloat
            @test iszero(pv(big"0.05", x))
            @test pv(ForwardDiff.Dual(0.05, 1.0), x) isa ForwardDiff.Dual
            @test iszero(ForwardDiff.derivative(r -> pv(Continuous(r), x), 0.05))
        end
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
