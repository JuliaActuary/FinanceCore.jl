using FinanceCore
using Documenter

DocMeta.setdocmeta!(FinanceCore, :DocTestSetup, :(using FinanceCore); recursive=true)

makedocs(;
    modules=[FinanceCore],
    authors="alecloudenback <alecloudenback@users.noreply.github.com> and contributors",
    repo=Remotes.GitHub("JuliaActuary", "FinanceCore.jl"),
    sitename="FinanceCore.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JuliaActuary.github.io/FinanceCore.jl",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
    ]
)

deploydocs(;
    repo="github.com/JuliaActuary/FinanceCore.jl",
    devbranch="main"
)
