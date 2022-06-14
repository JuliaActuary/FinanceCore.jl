using ActuaryCore
using Documenter

DocMeta.setdocmeta!(ActuaryCore, :DocTestSetup, :(using ActuaryCore); recursive=true)

makedocs(;
    modules=[ActuaryCore],
    authors="alecloudenback <alecloudenback@users.noreply.github.com> and contributors",
    repo="https://github.com/alecloudenback/ActuaryCore.jl/blob/{commit}{path}#{line}",
    sitename="ActuaryCore.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://alecloudenback.github.io/ActuaryCore.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/alecloudenback/ActuaryCore.jl",
    devbranch="main",
)
