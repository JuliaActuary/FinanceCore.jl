using PrecompileTools: @setup_workload, @compile_workload

@setup_workload begin
    fcfs = [-100.0, 10.0, 10.0, 110.0]
    icfs = [-100, 10, 10, 110]
    ftimes = [0.0, 1.0, 2.0, 3.0]
    @compile_workload begin
        irr(fcfs); irr(icfs)
        irr(fcfs, ftimes); irr(icfs, ftimes)
        irr(Cashflow.(fcfs, ftimes))
        for r in (0.05, Periodic(0.05, 1), Continuous(0.05))
            pv(r, fcfs); pv(r, icfs); pv(r, fcfs, ftimes); pv(r, icfs, ftimes)
            pv(r, Cashflow.(fcfs, ftimes))
            discount(r, 2.0); accumulation(r, 2.0)
        end
        convert(Periodic(1), Rate(0.05, Periodic(12))); convert(Continuous(), Periodic(0.05, 1))
        Periodic(0.05, 2) + Periodic(0.01, 2)
        repr("text/plain", Periodic(0.05, 2)); repr("text/plain", Continuous(0.05))
    end
end
