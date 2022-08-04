# ActuaryCore

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://alecloudenback.github.io/ActuaryCore.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://alecloudenback.github.io/ActuaryCore.jl/dev)
[![Build Status](https://github.com/alecloudenback/ActuaryCore.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/alecloudenback/ActuaryCore.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/alecloudenback/ActuaryCore.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/alecloudenback/ActuaryCore.jl)


This repository contains foundational types and routines that are used in other packages. Users should generally prefer to use other JuliaActuary packages which will re-export the ActuaryCore data/methods as necessary.

If you are extending a function or type as a user or developer, then it would be a good idea to import/use this package directly.

## ActuaryCore contents

### Reexported by ActuaryUtilities.jl
- IRR (reexported by ActuaryUtilities)

### Reexported by Yields.jl
- `AbstractYield`
- `Rate`s and `CompoundingFrequency`s 
- `discount`, `accumulation`, and `forward` functions

### Used by multiple packages
- `cashflows` and `timepoints` functions

# TODO
- What's the best pattern for exports? Should this package export anything and have dependent packages @reexport? Does that make it so users would still see `Yields.Rate`?
- Should this package precompile anything, or let the downstream packages do that? Or do it here unless the downstream extend the types and/or methods?