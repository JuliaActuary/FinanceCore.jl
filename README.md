# FinanceCore

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaActuary.github.io/FinanceCore.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaActuary.github.io/FinanceCore.jl/dev)
[![Build Status](https://github.com/JuliaActuary/FinanceCore.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaActuary/FinanceCore.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaActuary/FinanceCore.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaActuary/FinanceCore.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)


This repository contains foundational types and routines that are used in other packages. Users should generally prefer to use other JuliaActuary packages which will re-export the FinanceCore data/methods as necessary.

If you are extending a function or type as a user or developer, then it would be a good idea to import/use this package directly.

## FinanceCore contents

- `Rate`s and `Frequency`s (`Periodic`, `Continuous`)
- `discount`, `accumulation`, and `forward` functions
- `Cashflow`, `Quote`, and `Composite` contracts with the `amount`/`timepoint`/`maturity` accessors
- `irr`/`internal_rate_of_return` and `pv`/`present_value`

FinanceCore exports these names, and downstream packages (FinanceModels.jl via `@reexport`, ActuaryUtilities.jl selectively) re-export them — so `using FinanceModels` or `using ActuaryUtilities` brings the FinanceCore API into scope without loading FinanceCore directly.

## Upgrading to v3

`internal_rate_of_return`/`irr` now return `Periodic(NaN, 1)` instead of `nothing` when no root is found, so the return type is always a `Rate`. Replace `isnothing(irr(cfs))` checks with `isnan(rate(irr(cfs)))`.
