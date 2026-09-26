module FinanceCoreForwardDiffExt

using FinanceCore
using ForwardDiff

# The IRR fallback solves on primal values and propagates dual partials afterwards with
# one implicit-function step; these hooks strip and count dual layers.
FinanceCore._primal(x::ForwardDiff.Dual) = FinanceCore._primal(ForwardDiff.value(x))
FinanceCore._ad_depth(::Type{<:ForwardDiff.Dual{T, V}}) where {T, V} = 1 + FinanceCore._ad_depth(V)
FinanceCore._is_exact_zero(x::ForwardDiff.Dual) =
    FinanceCore._is_exact_zero(ForwardDiff.value(x)) && all(FinanceCore._is_exact_zero, ForwardDiff.partials(x))

end
