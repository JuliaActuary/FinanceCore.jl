# Test deflator implementing only the required `factor(p, from, to)` primitive
# and erroring on fractional time arguments. Used to verify that the
# abstraction is genuinely discretization-neutral and that errors propagate
# cleanly through composites.
struct DiscreteDecrement <: AbstractDeflator
    qs::Vector{Float64}   # qs[i] is the decrement rate in year i (1-indexed)
end

function FinanceCore.factor(d::DiscreteDecrement, from, to)
    (isinteger(from) && isinteger(to)) ||
        throw(ArgumentError("DiscreteDecrement requires integer time arguments; got ($from, $to)"))
    f, t = Int(from), Int(to)
    return prod(1 - d.qs[k] for k in (f + 1):t; init = 1.0)
end
# Deliberately no `intensity` method: discrete decrement has no instantaneous force.

@testset "AbstractDeflator" begin
    @testset "Rate <: AbstractDeflator and primitives" begin
        r = Continuous(0.03)
        @test r isa AbstractDeflator
        @test Rate <: AbstractDeflator

        # factor matches discount on Rate
        @test factor(r, 5) ≈ discount(r, 5)
        @test factor(r, 5) ≈ exp(-0.03 * 5)
        @test factor(r, 1, 6) ≈ discount(r, 1, 6)
        @test factor(r, 1, 6) ≈ exp(-0.03 * 5)

        # Periodic round-trips through factor
        p = Periodic(0.04, 2)
        @test factor(p, 5) ≈ discount(p, 5)
        @test factor(p, 1, 6) ≈ discount(p, 1, 6)

        # intensity for Rate
        @test intensity(r, 0.0) == 0.03
        @test intensity(r, 100.0) == 0.03
        @test intensity(p, 0.0) ≈ 2 * log(1 + 0.04 / 2)
    end

    @testset "Generic plumbing: discount, accumulation, forward, zero" begin
        r = Continuous(0.03)

        @test discount(r, 5) ≈ factor(r, 5)
        @test accumulation(r, 5) ≈ inv(factor(r, 5))
        @test discount(r, 1, 6) ≈ factor(r, 1, 6)
        @test accumulation(r, 1, 6) ≈ inv(factor(r, 1, 6))

        # forward and zero on Rate dispatch to existing Rate-specific methods
        # (which preserve the original Rate object)
        @test forward(r, 1, 6) === r
        @test zero(r, 5) === r
    end

    @testset "compose: flattening and equivalence" begin
        i = Continuous(0.03)
        μ = Continuous(0.012)
        λ = Continuous(0.07)
        ν = Continuous(0.005)

        # Two-component composite
        c2 = compose(i, μ)
        @test c2 isa CompositeDeflator
        @test length(components(c2)) == 2
        @test factor(c2, 5) ≈ factor(i, 5) * factor(μ, 5)
        @test factor(c2, 1, 6) ≈ factor(i, 1, 6) * factor(μ, 1, 6)

        # Three-component composite, three associativity forms — all flatten to length 3
        # and produce the same factor
        c_left  = compose(compose(i, μ), λ)
        c_right = compose(i, compose(μ, λ))
        c_flat  = compose(i, μ, λ)
        @test length(components(c_left))  == 3
        @test length(components(c_right)) == 3
        @test length(components(c_flat))  == 3
        @test factor(c_left, 5)  ≈ factor(c_flat, 5)
        @test factor(c_right, 5) ≈ factor(c_flat, 5)

        # Three-level deep nesting flattens to a single 4-component tuple —
        # exercises _flatten_impl recursion past the 2-level case
        c_deep = compose(compose(compose(i, μ), λ), ν)
        @test length(components(c_deep)) == 4
        @test factor(c_deep, 5) ≈ factor(i, 5) * factor(μ, 5) * factor(λ, 5) * factor(ν, 5)
        # Two equivalent deeper nestings produce equal factors
        c_deep_alt = compose(i, compose(μ, compose(λ, ν)))
        @test length(components(c_deep_alt)) == 4
        @test factor(c_deep, 5) ≈ factor(c_deep_alt, 5)

        # Single-arg compose returns the deflator itself
        @test compose(i) === i

        # Empty compose throws
        @test_throws ArgumentError compose()
    end

    @testset "Default-flavored example (doubles as docstring)" begin
        # Yield + zero-recovery default: pv of $1 paid in 5 years contingent on
        # the credit not defaulting.
        yield = Continuous(0.03)
        λ_d   = Continuous(0.012)

        deflator = compose(yield, λ_d)
        @test discount(deflator, 5) ≈ exp(-0.042 * 5)
        @test pv(deflator, [Cashflow(1.0, 5.0)]) ≈ exp(-0.042 * 5)
        @test intensity(deflator, 1.0) ≈ 0.042
    end

    @testset "Three-decrement: yield × default × mortality × lapse" begin
        i   = Continuous(0.05)
        λ_d = Continuous(0.001)
        μ   = Continuous(0.01)
        λ_l = Continuous(0.07)

        d = compose(i, λ_d, μ, λ_l)
        @test length(components(d)) == 4
        @test factor(d, 10) ≈ exp(-(0.05 + 0.001 + 0.01 + 0.07) * 10)
        @test intensity(d, 0) ≈ 0.131
    end

    @testset "Discrete component: integer grid and error propagation" begin
        q = DiscreteDecrement([0.012, 0.014, 0.016, 0.019])

        # Integer-grid factor matches manual prod(1 - q[k])
        @test factor(q, 0, 0) ≈ 1.0
        @test factor(q, 0, 3) ≈ (1 - 0.012) * (1 - 0.014) * (1 - 0.016)
        @test factor(q, 1, 4) ≈ (1 - 0.014) * (1 - 0.016) * (1 - 0.019)

        # Fractional time raises ArgumentError
        @test_throws ArgumentError factor(q, 0.5, 3)
        @test_throws ArgumentError factor(q, 0, 3.5)

        # Composite containing discrete works on integer grid
        yield = Continuous(0.03)
        combined = compose(yield, q)
        @test factor(combined, 0, 3) ≈ factor(yield, 0, 3) * factor(q, 0, 3)

        # Fractional endpoints propagate the discrete error through the composite
        @test_throws ArgumentError factor(combined, 0.5, 3.0)
    end

    @testset "intensity: sum on continuous-only, MethodError on mixed" begin
        i   = Continuous(0.03)
        λ_d = Continuous(0.012)
        q   = DiscreteDecrement([0.01, 0.02, 0.03])

        # Continuous-only composite: sum
        @test intensity(compose(i, λ_d), 1.0) ≈ 0.042

        # DiscreteDecrement deliberately has no intensity method — the
        # composite intensity raises through the sum.
        @test_throws MethodError intensity(q, 1.0)
        @test_throws MethodError intensity(compose(i, q), 1.0)
    end

    @testset "Type stability for tuple composite" begin
        i = Continuous(0.03)
        μ = Continuous(0.012)
        c = compose(i, μ)

        @inferred factor(c, 0.0, 5.0)
        @inferred factor(c, 5.0)
        @inferred discount(c, 0.0, 5.0)
        @inferred intensity(c, 1.0)
    end

    @testset "DynamicCompositeDeflator" begin
        i = Continuous(0.03)
        μ = Continuous(0.012)

        # Same numerical answer as compose for a fixed shape
        c_static  = compose(i, μ)
        c_dynamic = dynamic_composite(AbstractDeflator[i, μ])
        @test factor(c_dynamic, 5) ≈ factor(c_static, 5)
        @test factor(c_dynamic, 1, 6) ≈ factor(c_static, 1, 6)
        @test intensity(c_dynamic, 1.0) ≈ intensity(c_static, 1.0)
        @test components(c_dynamic) isa AbstractVector

        # Heterogeneous mix evaluates on integer grid
        q = DiscreteDecrement([0.012, 0.014, 0.016, 0.019])
        c_mixed = dynamic_composite(AbstractDeflator[i, q])
        @test factor(c_mixed, 0, 3) ≈ factor(i, 0, 3) * factor(q, 0, 3)

        # Empty vector: domain-meaningful error matching compose() behavior
        @test_throws ArgumentError dynamic_composite(AbstractDeflator[])
    end

    @testset "compose with cashflows via pv" begin
        # Verify the deflator integrates with the existing pv/Cashflow machinery.
        yield = Continuous(0.03)
        μ     = Continuous(0.012)
        deflator = compose(yield, μ)

        cashflows = [Cashflow(100.0, t) for t in 1.0:5.0]
        expected = sum(100.0 * exp(-0.042 * t) for t in 1.0:5.0)
        @test pv(deflator, cashflows) ≈ expected
    end

    @testset "pv on long Cashflow vector via deflator" begin
        # Locks in numerical correctness at scale; integration exercise for
        # the deflator + pv + Cashflow composition.
        yield = Continuous(0.03)
        μ     = Continuous(0.012)
        deflator = compose(yield, μ)

        n = 1_000
        amounts = [100.0 + i for i in 1:n]    # deterministic, non-zero
        cashflows = [Cashflow(amounts[i], float(i)) for i in 1:n]
        expected = sum(amounts[i] * exp(-0.042 * i) for i in 1:n)
        @test pv(deflator, cashflows) ≈ expected rtol = 1.0e-12
    end

    @testset "Hot-path allocation regression" begin
        # The Rate factor/discount/intensity bodies and the pv-on-Cashflow
        # path at pv.jl:33 must allocate zero on calls. This test locks that
        # invariant in so a future refactor that adds dispatch overhead
        # (e.g. redirecting discount through factor through some helper) is
        # caught at PR time. The IRR Newton/robust paths use raw exp(-r*t)
        # inline and don't go through these methods, so no IRR-specific
        # allocation test is needed here.
        r = Continuous(0.03)

        # Warm up to compile.
        factor(r, 5.0); factor(r, 1.0, 6.0); discount(r, 5.0)
        accumulation(r, 5.0); intensity(r, 5.0)

        @test (@allocations factor(r, 5.0)) == 0
        @test (@allocations factor(r, 1.0, 6.0)) == 0
        @test (@allocations discount(r, 5.0)) == 0
        @test (@allocations discount(r, 1.0, 6.0)) == 0
        @test (@allocations accumulation(r, 5.0)) == 0
        @test (@allocations intensity(r, 5.0)) == 0

        # pv on a single Cashflow goes through discount(::Rate, t) at pv.jl:33
        cf = Cashflow(100.0, 5.0)
        pv(r, cf)    # warm up
        @test (@allocations pv(r, cf)) == 0
    end

    @testset "components accessor" begin
        i = Continuous(0.03)
        μ = Continuous(0.012)
        c = compose(i, μ)

        @test components(c) === c.components
        @test components(c) isa Tuple

        d = dynamic_composite(AbstractDeflator[i, μ])
        @test components(d) === d.components
        @test components(d) isa AbstractVector
    end

    @testset "show: round-trips through the constructor expression" begin
        i = Continuous(0.03)
        μ = Continuous(0.012)
        c = compose(i, μ)
        @test repr(c) == "compose(Continuous(0.03), Continuous(0.012))"

        d = dynamic_composite(AbstractDeflator[i, μ])
        @test repr(d) == "dynamic_composite([Continuous(0.03), Continuous(0.012)])"
    end

    @testset "broadcastable" begin
        i = Continuous(0.03)
        μ = Continuous(0.012)
        c = compose(i, μ)
        # Broadcasting treats the deflator as scalar
        @test factor.(c, [1.0, 2.0, 3.0]) == [factor(c, 1.0), factor(c, 2.0), factor(c, 3.0)]
    end
end
