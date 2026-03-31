p(rate) = Periodic(rate, 1)

@testset "irr_checked basic" begin
    v = [-70000, 12000, 15000, 18000, 21000, 26000]

    @test isapprox(irr_checked(v[1:2]), p(-0.8285714285714), atol = 0.001)
    @test isapprox(irr_checked(v[1:3]), p(-0.4435069413346), atol = 0.001)
    @test isapprox(irr_checked(v[1:4]), p(-0.1821374641455), atol = 0.001)
    @test isapprox(irr_checked(v[1:5]), p(-0.0212448482734), atol = 0.001)
    @test isapprox(irr_checked(v[1:6]), p(0.0866309480365), atol = 0.001)
    @test_throws MethodError irr_checked("hello")

    cfs = [t % 10 == 0 ? -10 : 1.5 for t in 0:99]
    @test isapprox(irr_checked(cfs), p(0.06463163963925866), atol = 0.001)

    @test irr_checked([-100, 100]) ≈ p(0.0)
    @test isnothing(irr_checked([100, 100]))
    @test isnothing(irr_checked([-1.0e8, 0.0, 0.0, 0.0], 0:3))
end

@testset "irr_checked convergence flag catches bad Newton results" begin
    # Newton converges to degenerate rate ≈ -1.0 without convergence flag;
    # irr_checked should fall back to robust and find the correct root.
    cfs = Float64.([-1000, 1, 1, 1, 1, 1])
    result = irr_checked(cfs)
    @test result !== nothing
    @test isapprox(rate(result), -0.7327681430926347, atol = 0.001)

    # Verify NPV ≈ 0 at the returned rate
    r = rate(result)
    npv = sum(cf / (1 + r)^t for (cf, t) in zip(cfs, 0:5))
    @test abs(npv) < 1e-6
end

@testset "irr_checked fractional time" begin
    irr1 = irr_checked([-10, 5, 5, 5], [0, 1, 2, 3])
    @test irr1 ≈ irr_checked([-10, 5, 5, 5])
    irr2 = irr_checked([-10, 5, 5, 5], [0, 1, 2, 3] ./ 2)
    @test (1 + rate(irr1))^2 - 1 ≈ rate(irr2)
end

@testset "irr_checked numpy examples" begin
    @test isapprox(irr_checked([-150000, 15000, 25000, 35000, 45000, 60000]), p(0.0524), atol = 1.0e-4)
    @test isapprox(irr_checked([-100, 0, 0, 74]), p(-0.0955), atol = 1.0e-4)
    @test isapprox(irr_checked([-100, 39, 59, 55, 20]), p(0.28095), atol = 1.0e-4)
    @test isapprox(irr_checked([-100, 100, 0, -7]), p(-0.0833), atol = 1.0e-4)
    @test isapprox(irr_checked([-100, 100, 0, 7]), p(0.06206), atol = 1.0e-4)
    @test isapprox(irr_checked([-5, 10.5, 1, -8, 1]), p(0.0886), atol = 1.0e-4)
end

@testset "irr_checked xirr with float times" begin
    @test isapprox(irr_checked([-100, 100], [0, 1]), p(0.0), atol = 0.001)
    @test isapprox(irr_checked([-100, 110], [0, 1]), p(0.1), atol = 0.001)
end

@testset "irr_checked with cashflows" begin
    c = Cashflow.([-10, 0, 0, 15], [0, 1, 2, 3])
    @test irr_checked(c) ≈ Periodic((15 / 10)^(1 / 3) - 1, 1)

    # issue #28
    cfs = [-8.728037307132952e7, 3.043754023830998e7, 2.963004184784189e7, 2.8803030748755097e7, 2.7956912111811966e7, 2.7092182051244527e7, 2.6209069543806538e7, 2.5307964329840004e7, 2.438961041057478e7, 2.3455084653011695e7, 2.2505925520018265e7, 2.154395414765592e7, 2.0571076113065004e7, 1.958930608135183e7, 1.8600627464895025e7, 1.7606980923262402e7, 1.661046149512893e7, 1.561312825963898e7, 1.461760481586352e7, 1.3626801207410209e7, 1.2644733969499402e7, 1.1675393687299855e7, 1.0722720151658386e7, 9.79075673433771e6, 8.883278741880089e6, 8.004445298876338e6, 7.1588010859461725e6, 6.351121678665243e6, 5.585860320479795e6, 4.8673895159943625e6, 4.19908059495347e6, 3.583538247530099e6, 3.022766488834396e6, 2.5181072324190177e6, 2.0701053881076649e6, 1.6782921224664208e6, 1.3410605489291362e6, 1.0556643097527474e6, 818348.5357315112, 624147.9373214925, 467849.788997191, 344241.752520618, 248285.65630649775, 175235.5475426321, 120677.87174498942, 80759.09804678289, 52186.83400936739, 32211.057718402008, 18589.51907385164, 9540.782278174447, 3688.4015341755294]
    @test irr_checked(Cashflow.(cfs, 0:50)) ≈ p(0.3176680627111823)

    # FinanceCore issue #22
    cfs2 = fill(-10.0, 50 * 12 + 1)
    cfs2[1] = 3000.0
    @test irr_checked(cfs2, ((0 // 12):(1 // 12):50)) ≈ Periodic(0.0323124165683919, 1)

    cfs3 = Cashflow.(cfs2, (0 // 12):(1 // 12):50)
    @test irr_checked(cfs3) ≈ Periodic(0.0323124165683919, 1)
end

@testset "irr_checked robust fallback: nearest to zero" begin
    # When robust solver finds multiple roots, should return the one nearest zero.
    # Directly test the internal robust function.
    import FinanceCore: _irr_checked_robust

    # [-5, 10.5, 1, -8, 1] has roots near -0.87, 0.089, 0.71
    # Nearest to zero is 0.089
    result = _irr_checked_robust([-5.0, 10.5, 1.0, -8.0, 1.0], 0:4)
    @test result !== nothing
    @test isapprox(rate(result), 0.0886, atol = 0.001)
end

@testset "irr_checked Cashflow robust fallback" begin
    # Verify the Cashflow version of robust fallback doesn't crash
    import FinanceCore: _irr_checked_robust

    cfs = Cashflow.([-10.0, 0.0, 0.0, 15.0], [0, 1, 2, 3])
    result = _irr_checked_robust(cfs)
    @test result !== nothing
    @test isapprox(result, Periodic((15 / 10)^(1 / 3) - 1, 1), atol = 0.001)
end
