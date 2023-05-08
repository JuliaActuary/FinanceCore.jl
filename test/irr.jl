#convenience function to wrap scalar into default Rate type
p(rate) = Periodic(rate,1)

@testset "irr" begin

    v = [-70000,12000,15000,18000,21000,26000]
    
    # per Excel (example comes from Excel help text)
    @test isapprox(irr(v[1:2]), p(-0.8285714285714), atol = 0.001)
    @test isapprox(irr(v[1:2]), p(-0.8285714285714), atol = 0.001)
    @test isapprox(irr(v[1:3]), p(-0.4435069413346), atol = 0.001)
    @test isapprox(irr(v[1:4]), p(-0.1821374641455), atol = 0.001)
    @test isapprox(irr(v[1:5]), p(-0.0212448482734), atol = 0.001)
    @test isapprox(irr(v[1:6]),  p(0.0866309480365), atol = 0.001)
    @test_throws MethodError irr("hello") 


    # much more challenging to solve b/c of the overflow below zero
    cfs = [t % 10 == 0 ? -10 : 1.5 for t in 0:99]

    @test isapprox(irr(cfs), p(0.06463163963925866), atol = 0.001)

    # issue #28
    cfs = [-8.728037307132952e7, 3.043754023830998e7, 2.963004184784189e7, 2.8803030748755097e7, 2.7956912111811966e7, 2.7092182051244527e7, 2.6209069543806538e7, 2.5307964329840004e7, 2.438961041057478e7, 2.3455084653011695e7, 2.2505925520018265e7, 2.154395414765592e7, 2.0571076113065004e7, 1.958930608135183e7, 1.8600627464895025e7, 1.7606980923262402e7, 1.661046149512893e7, 1.561312825963898e7, 1.461760481586352e7, 1.3626801207410209e7, 1.2644733969499402e7, 1.1675393687299855e7, 1.0722720151658386e7, 9.79075673433771e6, 8.883278741880089e6, 8.004445298876338e6, 7.1588010859461725e6, 6.351121678665243e6, 5.585860320479795e6, 4.8673895159943625e6, 4.19908059495347e6, 3.583538247530099e6, 3.022766488834396e6, 2.5181072324190177e6, 2.0701053881076649e6, 1.6782921224664208e6, 1.3410605489291362e6, 1.0556643097527474e6, 818348.5357315112, 624147.9373214925, 467849.788997191, 344241.752520618, 248285.65630649775, 175235.5475426321, 120677.87174498942, 80759.09804678289, 52186.83400936739, 32211.057718402008, 18589.51907385164, 9540.782278174447, 3688.4015341755294]
    @test irr(cfs,0:50) ≈ p(0.3176680627111823)


    @test irr([-100,100]) ≈ p(0.)
    @test isnothing(irr([100,100])) # answer is -1, but search range won't find it
    
    # test the unsolvable
    @test isnothing(irr([-1e8,0.,0.,0.],0:3))

end

@testset "irr with fractional time" begin
    irr1 = irr([-10,5,5,5],[0,1,2,3])
    @test irr1 ≈ irr([-10,5,5,5])
    irr2 = irr([-10,5,5,5],[0,1,2,3] ./ 2)

    @test (1+rate(irr1))^2-1 ≈ rate(irr2)

end

@testset "numpy examples" begin

    @test isapprox(irr([-150000, 15000, 25000, 35000, 45000, 60000]),  p(0.0524),     atol = 1e-4)
    @test isapprox(irr([-100, 0, 0, 74]), p(-0.0955),     atol = 1e-4)
    @test isapprox(irr([-100, 39, 59, 55, 20]),  p(0.28095),    atol = 1e-4)
    @test isapprox(irr([-100, 100, 0, -7]), p(-0.0833),     atol = 1e-4)
    @test isapprox(irr([-100, 100, 0, 7]),  p(0.06206),    atol = 1e-4)

    # this has multiple roots, of which 0.709559 and 0.0886. Want to find the one closer to zero
    @test isapprox(irr([-5, 10.5, 1, -8, 1]),  p(0.0886),     atol = 1e-4)
end

@testset "xirr with float times" begin


    @test isapprox(irr([-100,100], [0,1]), p(0.0), atol = 0.001)
    @test isapprox(irr([-100,110], [0,1]), p(0.1), atol = 0.001)

end

@testset "xirr with real dates" begin

    v = [-70000,12000,15000,18000,21000,26000]
    dates = Date(2019, 12, 31):Year(1):Date(2024, 12, 31)
    times = map(d->DayCounts.yearfrac(dates[1], d, DayCounts.Thirty360()), dates)
# per Excel (example comes from Excel help text)
    @test isapprox(irr(v[1:2], times[1:2]), p(-0.8285714285714), atol = 0.001)
    @test isapprox(irr(v[1:3], times[1:3]), p(-0.4435069413346), atol = 0.001)
    @test isapprox(irr(v[1:4], times[1:4]), p(-0.1821374641455), atol = 0.001)
    @test isapprox(irr(v[1:5], times[1:5]), p(-0.0212448482734), atol = 0.001)
    @test isapprox(irr(v[1:6], times[1:6]),  p(0.0866309480365), atol = 0.001)

end