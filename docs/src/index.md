```@meta
CurrentModule = FinanceCore
```

# FinanceCore

Documentation for [FinanceCore](https://github.com/JuliaActuary/FinanceCore.jl).

## Optional IRR vectorization

Loading [LoopVectorization.jl](https://github.com/JuliaSIMD/LoopVectorization.jl)
enables an optimized inner kernel for compatible [`irr`](@ref) inputs. Backend
selection depends only on the arguments to each call; loading LoopVectorization
does not change a process-global FinanceCore setting.

The current public IRR solver uses the optimized kernel for dense `Float64`
cashflow vectors when timepoints are either a dense `Float64` vector or the
integer range created by `irr(cashflows)`. Integer, mixed-type, custom-number,
and `Cashflow` inputs use FinanceCore's base SIMD kernel.

The optimized and base kernels are numerically equivalent within floating-point
precision. Reassociated operations and LoopVectorization's exponential
implementation can produce differences near the last bit; pin the package
environment and use tolerance-based comparisons when exact reproducibility is
required across environments.

```@index
```

```@autodocs
Modules = [FinanceCore]
```
