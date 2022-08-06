using FinanceCore
using Documenter

DocMeta.setdocmeta!(FinanceCore, :DocTestSetup, :(using FinanceCore); recursive=true)

makedocs(;
    modules=[FinanceCore],
    authors="alecloudenback <alecloudenback@users.noreply.github.com> and contributors",
    repo="https://github.com/alecloudenback/FinanceCore.jl/blob/{commit}{path}#{line}",
    sitename="FinanceCore.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://alecloudenback.github.io/FinanceCore.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/alecloudenback/FinanceCore.jl",
    devbranch="main",
)
