#convenience function to wrap scalar into default Rate type
p(rate) = Periodic(rate, 1)

@testset "irr" begin

    v = [-70000, 12000, 15000, 18000, 21000, 26000]

    # per Excel (example comes from Excel help text)
    @test isapprox(irr(v[1:2]), p(-0.8285714285714), atol = 0.001)
    @test isapprox(irr(v[1:2]), p(-0.8285714285714), atol = 0.001)
    @test isapprox(irr(v[1:3]), p(-0.4435069413346), atol = 0.001)
    @test isapprox(irr(v[1:4]), p(-0.1821374641455), atol = 0.001)
    @test isapprox(irr(v[1:5]), p(-0.0212448482734), atol = 0.001)
    @test isapprox(irr(v[1:6]), p(0.0866309480365), atol = 0.001)
    @test_throws MethodError irr("hello")


    # much more challenging to solve b/c of the overflow below zero
    cfs = [t % 10 == 0 ? -10 : 1.5 for t in 0:99]

    @test isapprox(irr(cfs), p(0.06463163963925866), atol = 0.001)

    # issue #28
    cfs = [-8.728037307132952e7, 3.043754023830998e7, 2.963004184784189e7, 2.8803030748755097e7, 2.7956912111811966e7, 2.7092182051244527e7, 2.6209069543806538e7, 2.5307964329840004e7, 2.438961041057478e7, 2.3455084653011695e7, 2.2505925520018265e7, 2.154395414765592e7, 2.0571076113065004e7, 1.958930608135183e7, 1.8600627464895025e7, 1.7606980923262402e7, 1.661046149512893e7, 1.561312825963898e7, 1.461760481586352e7, 1.3626801207410209e7, 1.2644733969499402e7, 1.1675393687299855e7, 1.0722720151658386e7, 9.79075673433771e6, 8.883278741880089e6, 8.004445298876338e6, 7.1588010859461725e6, 6.351121678665243e6, 5.585860320479795e6, 4.8673895159943625e6, 4.19908059495347e6, 3.583538247530099e6, 3.022766488834396e6, 2.5181072324190177e6, 2.0701053881076649e6, 1.6782921224664208e6, 1.3410605489291362e6, 1.0556643097527474e6, 818348.5357315112, 624147.9373214925, 467849.788997191, 344241.752520618, 248285.65630649775, 175235.5475426321, 120677.87174498942, 80759.09804678289, 52186.83400936739, 32211.057718402008, 18589.51907385164, 9540.782278174447, 3688.4015341755294]
    @test irr(cfs, 0:50) ≈ p(0.3176680627111823)


    @test irr([-100, 100]) ≈ p(0.0) atol = eps()
    @test rate(FinanceCore._periodic_from_force(1.0e-16)) == 1.0e-16
    @test rate(irr([-1.0, 1.0 + 1.0e-10])) ≈ 1.0e-10 rtol = 1.0e-6
    @test isnothing(irr([100, 100])) # answer is -1, but search range won't find it
    @test isnothing(irr([100.0, 100.0], [1.0, 1.0]))
    @test isnothing(irr([-100.0, -100.0], [1.0, 1.0]))
    @test isnothing(irr(Cashflow.([100.0, 100.0], [1.0, 1.0])))

    # A common shift in time does not change the IRR. In particular, it must not
    # let the robust solver mistake simultaneous underflow for a finite root.
    @test irr([-100.0, 110.0], [1000.0, 1001.0]) ≈ p(0.1)

    # test the unsolvable
    @test isnothing(irr([-1.0e8, 0.0, 0.0, 0.0], 0:3))

    # all-zero or near-zero cashflows should return nothing, not throw
    @test isnothing(irr([0.0, 0.0, 0.0]))
    @test isnothing(irr([0.0, 0.0, 0.0], 0:2))
    @test isnothing(irr([1.0e-50, 1.0e-50, 1.0e-50]))
    @test isnothing(irr([1.0e-300, 1.0e-300, 1.0e-300], 0:2))

end

@testset "irr with fractional time" begin
    irr1 = irr([-10, 5, 5, 5], [0, 1, 2, 3])
    @test irr1 ≈ irr([-10, 5, 5, 5])
    irr2 = irr([-10, 5, 5, 5], [0, 1, 2, 3] ./ 2)

    @test (1 + rate(irr1))^2 - 1 ≈ rate(irr2)

end

@testset "numpy examples" begin

    @test isapprox(irr([-150000, 15000, 25000, 35000, 45000, 60000]), p(0.0524), atol = 1.0e-4)
    @test isapprox(irr([-100, 0, 0, 74]), p(-0.0955), atol = 1.0e-4)
    @test isapprox(irr([-100, 39, 59, 55, 20]), p(0.28095), atol = 1.0e-4)
    @test isapprox(irr([-100, 100, 0, -7]), p(-0.0833), atol = 1.0e-4)
    @test isapprox(irr([-100, 100, 0, 7]), p(0.06206), atol = 1.0e-4)

    # this has multiple roots, of which 0.709559 and 0.0886. Want to find the one closer to zero
    @test isapprox(irr([-5, 10.5, 1, -8, 1]), p(0.0886), atol = 1.0e-4)
end

@testset "xirr with float times" begin


    @test isapprox(irr([-100, 100], [0, 1]), p(0.0), atol = 0.001)
    @test isapprox(irr([-100, 110], [0, 1]), p(0.1), atol = 0.001)

end

@testset "xirr with real dates" begin

    v = [-70000, 12000, 15000, 18000, 21000, 26000]
    dates = Date(2019, 12, 31):Year(1):Date(2024, 12, 31)
    times = map(d -> DayCounts.yearfrac(dates[1], d, DayCounts.Thirty360()), dates)
    # per Excel (example comes from Excel help text)
    @test isapprox(irr(v[1:2], times[1:2]), p(-0.8285714285714), atol = 0.001)
    @test isapprox(irr(v[1:3], times[1:3]), p(-0.4435069413346), atol = 0.001)
    @test isapprox(irr(v[1:4], times[1:4]), p(-0.1821374641455), atol = 0.001)
    @test isapprox(irr(v[1:5], times[1:5]), p(-0.0212448482734), atol = 0.001)
    @test isapprox(irr(v[1:6], times[1:6]), p(0.0866309480365), atol = 0.001)

end

@testset "irr with cashflows" begin
    c = Cashflow.([-10, 0, 0, 15], [0, 1, 2, 3])
    @test irr(c) ≈ Periodic((15 / 10)^(1 / 3) - 1, 1)
    @test irr(@view(c[begin:end])) ≈ Periodic((15 / 10)^(1 / 3) - 1, 1)

    # issue #28
    cfs = [-8.728037307132952e7, 3.043754023830998e7, 2.963004184784189e7, 2.8803030748755097e7, 2.7956912111811966e7, 2.7092182051244527e7, 2.6209069543806538e7, 2.5307964329840004e7, 2.438961041057478e7, 2.3455084653011695e7, 2.2505925520018265e7, 2.154395414765592e7, 2.0571076113065004e7, 1.958930608135183e7, 1.8600627464895025e7, 1.7606980923262402e7, 1.661046149512893e7, 1.561312825963898e7, 1.461760481586352e7, 1.3626801207410209e7, 1.2644733969499402e7, 1.1675393687299855e7, 1.0722720151658386e7, 9.79075673433771e6, 8.883278741880089e6, 8.004445298876338e6, 7.1588010859461725e6, 6.351121678665243e6, 5.585860320479795e6, 4.8673895159943625e6, 4.19908059495347e6, 3.583538247530099e6, 3.022766488834396e6, 2.5181072324190177e6, 2.0701053881076649e6, 1.6782921224664208e6, 1.3410605489291362e6, 1.0556643097527474e6, 818348.5357315112, 624147.9373214925, 467849.788997191, 344241.752520618, 248285.65630649775, 175235.5475426321, 120677.87174498942, 80759.09804678289, 52186.83400936739, 32211.057718402008, 18589.51907385164, 9540.782278174447, 3688.4015341755294]
    @test irr(Cashflow.(cfs, 0:50)) ≈ p(0.3176680627111823)

    # FinanceCore issue #22

    cfs = fill(-10.0, 50 * 12 + 1)
    cfs[1] = 3000.0
    @test irr(cfs, ((0 // 12):(1 // 12):50)) ≈ Periodic(0.0323124165683919, 1)

    cfs = Cashflow.(cfs, (0 // 12):(1 // 12):50)
    @test irr(cfs) ≈ Periodic(0.0323124165683919, 1)


end

@testset "irr numeric types" begin
    cfs = Float32[-100, 110]
    times = Float32[0, 1]
    result = FinanceCore.__pv_div_pv′(FinanceCore.SimdBackend(), 0.1f0, cfs, times)
    @test result isa Float32

    cashflows = Cashflow.(cfs, times)
    cashflow_result = FinanceCore.__pv_div_pv′(
        FinanceCore.SimdBackend(),
        0.1f0,
        cashflows,
    )
    @test cashflow_result isa Float32

    dual_cfs = [
        ForwardDiff.Dual{Nothing}(-100.0, 1.0),
        ForwardDiff.Dual{Nothing}(110.0, 0.0),
    ]
    dual_result = @inferred FinanceCore.__pv_div_pv′(
        FinanceCore.SimdBackend(),
        0.1,
        dual_cfs,
        0:1,
    )
    @test dual_result isa ForwardDiff.Dual

    f(x) = rate(irr(x))
    @test ForwardDiff.gradient(f, [-100.0, 110.0]) ≈ [0.011, 0.01]
end

@testset "IRR input representations share solver behavior" begin
    cases = (
        # Newton converges for ordinary numeric types and fractional timepoints.
        ([-100, 110], [0, 1], 0.1),
        (Float32[-100, 110], Float32[0, 1], 0.1),
        (BigFloat[-100, 110], BigFloat[0, 1], 0.1),
        ([-100.0, 121.0], [0 // 1, 1 // 2], 0.4641),
        # Newton cannot finish these; the normalized fallback recovers the root.
        ([-100.0, 110.0], [1000.0, 1001.0], 0.1),
        ([-1.0e-300, 1.1e-300], [1.0e6, 1.0e6 + 1], 0.1),
        ([-1.0e300, 1.1e300], [1000.0, 1001.0], 0.1),
        # Multiple fallback roots: choose the one nearest zero in force space.
        ([-100.0, 230.0, -132.0], [1000.0, 1001.0, 1002.0], 0.1),
        # One-sign, all-zero, and mixed-sign streams without a root.
        ([100.0, 100.0], [1.0, 1.0], nothing),
        ([-100.0, -100.0], [1.0, 1.0], nothing),
        ([0.0, 0.0], [0.0, 1.0], nothing),
        ([-100.0, 100.0, -100.0], [0.0, 1.0, 2.0], nothing),
    )
    for (amounts, times, expected) in cases
        flows = Cashflow.(amounts, times)
        results = (
            irr(amounts, times), irr(flows),
            irr(@view(amounts[:]), @view(times[:])), irr(@view(flows[:])),
        )
        for result in results
            if isnothing(expected)
                @test isnothing(result)
            else
                @test rate(result) ≈ expected rtol = 1.0e-6
            end
        end
    end

    # Exact-zero amounts neither set the fallback's time origin nor enter its terms: a zero far
    # from the other cashflows would otherwise evaluate as 0 * Inf.
    for (amounts, times) in (
            ([0.0, -100.0, 110.0], [0.0, 1000.0, 1001.0]),
            ([-100.0, 0.0, 110.0, 0.0], [1000.0, 1000.5, 1001.0, 3000.0]),
            ([0.0, -100.0, 0.0, 110.0, 0.0], [0.0, 1000.0, 1000.5, 1001.0, 5000.0]),
        )
        @test irr(amounts, times) ≈ Periodic(0.1, 1)
        @test irr(Cashflow.(amounts, times)) ≈ Periodic(0.1, 1)
    end

    # Extra timepoints have always been ignored; they must not shift the fallback's origin.
    @test irr([-100.0, 110.0], [1000.0, 1001.0, -1.0e6]) ≈ Periodic(0.1, 1)
    @test_throws AssertionError irr([-100.0, 110.0], [0.0])

    # AD must agree through both public input representations.
    amounts = [-100.0, 110.0]
    times = [0.0, 1.0]
    numeric = ForwardDiff.gradient(a -> rate(irr(a, times)), amounts)
    wrapped = ForwardDiff.gradient(a -> rate(irr(Cashflow.(a, times))), amounts)
    @test numeric ≈ [0.011, 0.01]
    @test wrapped ≈ numeric
end

@testset "irr derivatives through the fallback solver" begin
    # Newton cannot finish these cashflows (every discount factor underflows from its
    # starting point), so the fallback solves on primal values and one implicit-function
    # step gives the root its partials.
    times = [1000.0, 1001.0]
    f(a) = rate(irr(a, times))
    h = 1.0e-4
    central = [
        (f([-100 + h, 110]) - f([-100 - h, 110])) / 2h,
        (f([-100, 110 + h]) - f([-100, 110 - h])) / 2h,
    ]
    @test ForwardDiff.gradient(f, [-100.0, 110.0]) ≈ central rtol = 1.0e-8
    @test ForwardDiff.gradient(f, [-100.0, 110.0]) ≈ [0.011, 0.01]    # 110/100², 1/100
    @test ForwardDiff.gradient(a -> rate(irr(Cashflow.(a, times))), [-100.0, 110.0]) ≈ [0.011, 0.01]
    # the value is the primal root exactly
    dual = rate(irr(ForwardDiff.Dual.([-100.0, 110.0], 1.0), times))
    @test ForwardDiff.value(dual) === rate(irr([-100.0, 110.0], times))

    # A dual time: the force is log(1.1) / (1 + τ), so d(rate)/dτ = -1.1 log(1.1) at τ = 0.
    @test ForwardDiff.derivative(τ -> rate(irr([-100.0, 110.0], [1000.0, 1001.0 + τ])), 0.0) ≈
        -1.1 * log(1.1)
    @test ForwardDiff.derivative(τ -> rate(irr(Cashflow.([-100.0, 110.0], [1000.0, 1001.0 + τ]))), 0.0) ≈
        -1.1 * log(1.1)

    # Two roots, the one nearest zero chosen; compared with central differences.
    g(a) = rate(irr(a, [1000.0, 1001.0, 1002.0]))
    a3 = [-100.0, 230.0, -132.0]
    central3 = [(g(a3 .+ 1.0e-5 .* (1:3 .== i)) - g(a3 .- 1.0e-5 .* (1:3 .== i))) / 2.0e-5 for i in 1:3]
    @test ForwardDiff.gradient(g, a3) ≈ central3 rtol = 1.0e-6

    # A zero amount that carries partials still moves the root: d(rate)/da₀ = -(1 + i) / PV′(r).
    # It is enormous here because the other cashflows sit 1000 years later.
    grad0 = ForwardDiff.gradient(a -> rate(irr(a, [0.0, 1000.0, 1001.0])), [0.0, -100.0, 110.0])
    expected0 = setprecision(256) do
        r = log(big"1.1")
        dpv = 100 * 1000 * exp(-1000r) - 110 * 1001 * exp(-1001r)
        Float64(-exp(r) / dpv)
    end
    @test grad0[1] ≈ expected0 rtol = 1.0e-10
    @test grad0[2:3] ≈ [0.011, 0.01]

    # Nested dual numbers and a repeated root have no first-order implicit step: both throw.
    @test_throws ArgumentError ForwardDiff.hessian(f, [-100.0, 110.0])
    @test_throws ArgumentError ForwardDiff.gradient(
        a -> rate(irr(a, [5000.0, 5001.0, 5002.0])), [-100.0, 210.0, -110.25]
    )
end

@testset "irr derivatives through the Newton solver" begin
    # Newton solves on primal values too, and the same implicit-function step gives its root the
    # partials. The gradients equal those of differentiating through the Newton iterations
    # (the previous mechanism, pinned below) and central differences.
    cases = (
        ([-100.0, 5.0, 5.0, 105.0], [0.0, 1.0, 2.0, 3.0], [0.003672085646312451, 0.0034972244250594756, 0.0033306899286280737, 0.0031720856463124504]),
        ([-1000.0, 300.0, 400.0, 500.0], [0.0, 0.5, 1.5, 2.5], [0.0007013988920219666, 0.0006632635211485001, 0.0005931003571143857, 0.0005303593856633244]),
        ([100.0, -30.0, -40.0, -50.0], [0.0, 1.0, 2.0, 3.0], [-0.005156799362453198, -0.004735512127940115, -0.004348642159155063, -0.003993377720818277]),
        ([-50.0, 20.0, 20.0, 20.0], [0.0, 1.0, 2.0, 3.0], [0.011318939027688985, 0.010317988324450113, 0.009405553188603512, 0.008573806056168835]),
    )
    for (amounts, times, previous) in cases
        f(a) = rate(irr(a, times))
        gradient = ForwardDiff.gradient(f, amounts)
        central = [(f(amounts .+ 1.0e-5 .* (eachindex(amounts) .== i)) - f(amounts .- 1.0e-5 .* (eachindex(amounts) .== i))) / 2.0e-5 for i in eachindex(amounts)]
        @test gradient ≈ previous rtol = 1.0e-12
        @test gradient ≈ central rtol = 1.0e-6
        @test ForwardDiff.gradient(a -> rate(irr(Cashflow.(a, times))), amounts) ≈ previous rtol = 1.0e-12
        # with respect to the timepoints as well
        g(t) = rate(irr(amounts, t))
        central_t = [(g(times .+ 1.0e-6 .* (eachindex(times) .== i)) - g(times .- 1.0e-6 .* (eachindex(times) .== i))) / 2.0e-6 for i in eachindex(times)]
        @test ForwardDiff.gradient(g, times) ≈ central_t rtol = 1.0e-6
        # the value is the primal IRR exactly
        @test ForwardDiff.value(rate(irr(ForwardDiff.Dual.(amounts, 1.0), times))) === rate(irr(amounts, times))
    end
    # range timepoints (the one-argument form) keep the primal kernel
    @test ForwardDiff.gradient(a -> rate(irr(a)), [-100.0, 110.0]) ≈ [0.011, 0.01]
    @test ForwardDiff.value(rate(irr(ForwardDiff.Dual.([-100.0, 5.0, 105.0], 1.0)))) === rate(irr([-100.0, 5.0, 105.0]))

    # A repeated root (-100 + 210v - 110.25v² = -(10 - 10.5v)²) has no derivative; Newton reaches
    # it, and differentiating through its iterations used to return partials of about -1.5e6.
    for times in ([0.0, 1.0, 2.0], [1000.0, 1001.0, 1002.0])
        @test !isnothing(irr([-100.0, 210.0, -110.25], times))
        @test_throws ArgumentError ForwardDiff.gradient(a -> rate(irr(a, times)), [-100.0, 210.0, -110.25])
    end
    # first-order only: second derivatives through either stage throw
    @test_throws ArgumentError ForwardDiff.hessian(a -> rate(irr(a, [0.0, 1.0])), [-100.0, 110.0])
    # dual inputs without an IRR still return nothing
    @test isnothing(irr(ForwardDiff.Dual.([100.0, 100.0], 1.0)))
end

@testset "irr of empty cashflows" begin
    # Like an all-zero stream, an empty stream has no identifiable IRR: every rate solves its
    # identically zero pricing equation.
    @test isnothing(irr(Float64[]))
    @test isnothing(irr(Float64[], Float64[]))
    @test isnothing(irr(Cashflow{Float64, Float64}[]))
end
