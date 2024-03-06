var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = FinanceCore","category":"page"},{"location":"#FinanceCore","page":"Home","title":"FinanceCore","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for FinanceCore.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [FinanceCore]","category":"page"},{"location":"#FinanceCore.Timepoint","page":"Home","title":"FinanceCore.Timepoint","text":"Timepoint(a)\n\nSummary ≡≡≡≡≡≡≡≡≡\n\nTimepoint is a type alias for Union{T,Dates.Date} that can be used to represent a point in time. It can be either a Dates.Date or a Real number. If defined as a real number, the interpretation is the number of (fractional) periods since time zero.\n\nCurrently, the usage of Dates.Date is not well supported across the JuliaActuary ecosystem but this type is in place such that it can be built upon further.\n\nSupertype Hierarchy ≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡\n\nTimepoint{T} = Union{T,Dates.Date} <: Any\n\n\n\n\n\n","category":"type"},{"location":"#FinanceCore.Cashflow","page":"Home","title":"FinanceCore.Cashflow","text":"Cashflow(amount,time)\n\nA Cahflow{A,B} is a contract that pays an amount at time. \n\nCashflows can be:\n\nnegated with the unary - operator. \nadded/subtracted together but note that the time must be isapprox equal.\nmultiplied/divided by a scalar.\n\nSupertype Hierarchy ≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡\n\nCashflow{A<:Real, B<:Timepoint} <: FinanceCore.AbstractContract <: Any\n\n\n\n\n\n","category":"type"},{"location":"#FinanceCore.Composite","page":"Home","title":"FinanceCore.Composite","text":"Composite(A,B)\n\nSummary ≡≡≡≡≡≡≡≡≡\n\nstruct Composite{A, B}\n\nA Composite{A,B} is a contract that is composed of two other contracts of type A and type B.  The maturity of the composite is the maximum of the maturities of the two components. \n\nIt is used to assemble arbitrarily complex contracts from simpler ones.\n\nFields ≡≡≡≡≡≡≡≡\n\na :: A\nb :: B\n\nSupertype Hierarchy ≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡\n\nComposite{A, B} <: FinanceCore.AbstractContract <: Any\n\n\n\n\n\n","category":"type"},{"location":"#FinanceCore.Continuous","page":"Home","title":"FinanceCore.Continuous","text":"Continuous()\n\nA type representing continuous interest compounding frequency.\n\nExamples\n\njulia> Rate(0.01,Continuous())\nRate(0.01, Continuous())\n\nSee also: Periodic\n\n\n\n\n\n","category":"type"},{"location":"#FinanceCore.Continuous-Tuple{Any}","page":"Home","title":"FinanceCore.Continuous","text":"julia> Continuous(0.01)\nRate(0.01, Continuous())\n\nSee also: Periodic\n\n\n\n\n\n","category":"method"},{"location":"#FinanceCore.Periodic","page":"Home","title":"FinanceCore.Periodic","text":"Periodic(frequency)\n\nA type representing periodic interest compounding with the given frequency. \n\nfrequency will be converted to an Integer, and will round up to 8 decimal places (otherwise will throw an InexactError). \n\nExamples\n\nCreating a semi-annual bond equivalent yield:\n\njulia> Rate(0.01,Periodic(2))\nRate(0.01, Periodic(2))\n\nSee also: Continuous\n\n\n\n\n\n","category":"type"},{"location":"#FinanceCore.Periodic-Tuple{Any, Any}","page":"Home","title":"FinanceCore.Periodic","text":"Periodic(rate,frequency)\n\nA convenience constructor for Rate(rate,Periodic(frequency)).\n\nExamples\n\nCreating a semi-annual bond equivalent yield:\n\njulia> Periodic(0.01,2)\nRate(0.01, Periodic(2))\n\nSee also: Continuous\n\n\n\n\n\n","category":"method"},{"location":"#FinanceCore.Quote","page":"Home","title":"FinanceCore.Quote","text":"Quote(price,instrument)\n\nThe price(<:Real) is the observed value , and the instrument is the instrument/contract that the price is for.\n\nThis can be used, e.g., to calibrate a valuation model to prices for the given instruments - see FinanceModels.jl for more details.\n\n\n\n\n\n","category":"type"},{"location":"#FinanceCore.Rate-Tuple{Any}","page":"Home","title":"FinanceCore.Rate","text":"Rate(rate[,frequency=1])\nRate(rate,frequency::Frequency)\n\nRate is a type that encapsulates an interest rate along with its compounding frequency.\n\nPeriodic rates can be constructed via Rate(rate,frequency) or Rate(rate,Periodic(frequency)). If not given a second argument, Rate(rate) is equivalent to Rate(rate,Periodic(1)).\n\nContinuous rates can be constructed via Rate(rate, Inf) or Rate(rate,Continuous()).\n\nExamples\n\njulia> Rate(0.01,Continuous())\nRate(0.01, Continuous())\n\njulia> Continuous(0.01)\nRate(0.01, Continuous())\n\njulia> Continuous()(0.01)\nRate(0.01, Continuous())\n\njulia> Rate(0.01,Periodic(2))\nRate(0.01, Periodic(2))\n\njulia> Periodic(0.01,2)\nRate(0.01, Periodic(2))\n\njulia> Periodic(2)(0.01)\nRate(0.01, Periodic(2))\n\njulia> Rate(0.01)\nRate(0.01, Periodic(1))\n\njulia> Rate(0.01,2)\nRate(0.01, Periodic(2))\n\njulia> Rate(0.01,Periodic(4))\nRate(0.01, Periodic(4))\n\njulia> Rate(0.01,Inf)\nRate(0.01, Continuous())\n\n\n\n\n\n\n","category":"method"},{"location":"#Base.:*-Union{Tuple{T}, Tuple{N}, Tuple{Rate{N, T}, Real}} where {N, T<:Continuous}","page":"Home","title":"Base.:*","text":"*(Yields.Rate, T)\n*(T, Yields.Rate)\n\nThe multiplication of a Rate with a scalar will inherit the type of the Rate, or the first argument's type if both are Rates.\n\n\n\n\n\n","category":"method"},{"location":"#Base.:+-Union{Tuple{T}, Tuple{N}, Tuple{Rate{N, T}, Real}} where {N, T<:Continuous}","page":"Home","title":"Base.:+","text":"+(Yields.Rate, T<:Real)\n+(T<:Real, Yields.Rate)\n+(Yields.Rate,Yields.Rate)\n\nThe addition of a rate with a number will inherit the type of the Rate, or the first argument's type if both are Rates.\n\nExamples\n\njulia> Yields.Periodic(0.01,2) + Yields.Periodic(0.04,2)\nYields.Rate{Float64, Yields.Periodic}(0.05000000000000004, Yields.Periodic(2))\n\njulia> Yields.Periodic(0.04,2) + 0.01\nYields.Rate{Float64, Yields.Periodic}(0.05, Yields.Periodic(2))\n\n\n\n\n\n","category":"method"},{"location":"#Base.:--Union{Tuple{T}, Tuple{N}, Tuple{Rate{N, T}, Real}} where {N, T<:Continuous}","page":"Home","title":"Base.:-","text":"-(Yields.Rate, T<:Real)\n-(T<:Real, Yields.Rate)\n-(Yields.Rate, Yields.Rate)\n\nThe addition of a rate with a number will inherit the type of the Rate, or the first argument's type if both are Rates.\n\nExamples\n\njulia> Yields.Periodic(0.04,2) - Yields.Periodic(0.01,2)\nYields.Rate{Float64, Yields.Periodic}(0.030000000000000214, Yields.Periodic(2))\n\njulia> Yields.Periodic(0.04,2) - 0.01\nYields.Rate{Float64, Yields.Periodic}(0.03, Yields.Periodic(2))\n\n\n\n\n\n\n","category":"method"},{"location":"#Base.:/-Union{Tuple{T}, Tuple{N}, Tuple{Rate{N, T}, Real}} where {N, T<:Continuous}","page":"Home","title":"Base.:/","text":"/(x::Yields.Rate, y::Real)\n\nThe division of a Rate with a scalar will inherit the type of the Rate, or the first argument's type if both are Rates.\n\n\n\n\n\n","category":"method"},{"location":"#Base.:<-Union{Tuple{U}, Tuple{T}, Tuple{T, U}} where {T<:Rate, U<:Rate}","page":"Home","title":"Base.:<","text":"<(x::Rate,y::Rate)\n\nConvert the second argument to the periodicity of the first and compare the scalar rate values to determine if the first argument has a lower force of interest than the second.\n\nExamples\n\njulia> Yields.Periodic(0.03,100) < Yields.Continuous(0.03)\ntrue\n\n\n\n\n\n","category":"method"},{"location":"#Base.:>-Union{Tuple{U}, Tuple{T}, Tuple{T, U}} where {T<:Rate, U<:Rate}","page":"Home","title":"Base.:>","text":">(Rate,Rate)\n\nConvert the second argument to the periodicity of the first and compare the scalar rate values to determine if the first argument has a greater force of interest than the second.\n\nExamples\n\njulia> Yields.Periodic(0.03,100) > Yields.Continuous(0.03)\nfalse\n\n\n\n\n\n","category":"method"},{"location":"#Base.convert-Union{Tuple{T}, Tuple{T, Rate}} where T<:FinanceCore.Frequency","page":"Home","title":"Base.convert","text":"convert(cf::Frequency,r::Rate)\n\nReturns a Rate with an equivalent discount but represented with a different compounding frequency.\n\nExamples\n\njulia> r = Rate(Periodic(12),0.01)\nRate(0.01, Periodic(12))\n\njulia> convert(Periodic(1),r)\nRate(0.010045960887181016, Periodic(1))\n\njulia> convert(Continuous(),r)\nRate(0.009995835646701251, Continuous())\n\n\n\n\n\n","category":"method"},{"location":"#FinanceCore.amount-Tuple{C} where C<:Cashflow","page":"Home","title":"FinanceCore.amount","text":"amount(x)\n\nIf is an object with an amount component (e.g. a Cashflow), will retrun that amount component, otherwise just x.\n\nExamples\n\njulia> FinanceCore.amount(Cashflow(1.,3.))\n1.0\n\njulia> FinanceCore.amount(1.)\n1.0\n\n\n\n\n\n","category":"method"},{"location":"#FinanceCore.internal_rate_of_return-Tuple{Any}","page":"Home","title":"FinanceCore.internal_rate_of_return","text":"internal_rate_of_return(cashflows::vector)::Rate\ninternal_rate_of_return(cashflows::Vector, timepoints::Vector)::Rate\n\nCalculate the internalrateof_return with given timepoints. If no timepoints given, will assume that a series of equally spaced cashflows, assuming the first cashflow occurring at time zero and subsequent elements at time 1, 2, 3, ..., n. \n\nReturns a Rate type with periodic compounding once per period (e.g. annual effective if the timepoints given represent years). Get the scalar rate by calling Yields.rate() on the result.\n\nExample\n\njulia> internal_rate_of_return([-100,110],[0,1]) # e.g. cashflows at time 0 and 1\n0.10000000001652906\njulia> internal_rate_of_return([-100,110]) # implied the same as above\n0.10000000001652906\n\nSolver notes\n\nWill try to return a root within the range [-2,2]. If the fast solver does not find one matching this condition, then a more robust search will be performed over the [.99,2] range.\n\nThe solution returned will be in the range [-2,2], but may not be the one nearest zero. For a slightly slower, but more robust version, call ActuaryUtilities.irr_robust(cashflows,timepoints) directly.\n\n\n\n\n\n","category":"method"},{"location":"#FinanceCore.irr","page":"Home","title":"FinanceCore.irr","text":"irr(cashflows::vector)\nirr(cashflows::Vector, timepoints::Vector)\n\nAn alias for `internal_rate_of_return`.\n\n\n\n\n\n","category":"function"},{"location":"#FinanceCore.present_value-Tuple{Any, Any, Any}","page":"Home","title":"FinanceCore.present_value","text":"present_value(yield_model, cashflows[, timepoints=pairs(cashflows)])\n\nDiscount the cashflows vector at the given yield_model,  with the cashflows occurring at the times specified in timepoints. If no timepoints given, assumes that cashflows happen at the indices of the cashflows.\n\nIf your timepoints are dates, you can convert them into a floating point representation of the time interval using DayCounts.jl.\n\nExamples\n\njulia> present_value(0.1, [10,20],[0,1])\n28.18181818181818\njulia> present_value(Continuous(0.1), [10,20],[0,1])\n28.096748360719193\njulia> present_value(Continuous(0.1), [10,20],[1,2])\n25.422989241919232\njulia> present_value(Continuous(0.1), [10,20])\n25.422989241919232\n\n\n\n\n\n","category":"method"},{"location":"#FinanceCore.rate-Tuple{Rate}","page":"Home","title":"FinanceCore.rate","text":"rate(r::Rate)\n\nReturns the untyped scalar interest rate represented by the Rate.\n\nExamples\n\njulia> r =Continuous(0.03)\nYields.Rate{Float64, Continuous}(0.03, Continuous())\n\njulia> rate(r)\n0.03\n\n\n\n\n\n","category":"method"},{"location":"#FinanceCore.timepoint-Union{Tuple{C}, Tuple{C, Any}} where C<:Cashflow","page":"Home","title":"FinanceCore.timepoint","text":"timepoint(x,t)\n\nIf x is an object with a defined time component (e.g. a Cashflow), will return that time component, otherwise will return t. This is useful in handling situations where you want to handle either Cashflows or separate amount and time vectors.\n\nExample\n\njulia> FinanceCore.timepoint(Cashflow(1.,3.),\"ignored\")\n3.0\n\njulia> FinanceCore.timepoint(1.,4.)\n4.0\n\n\n\n\n\n","category":"method"}]
}
