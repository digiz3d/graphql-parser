# GraphQL toolkit - gqlt

Extremely fast GraphQL parser and merger.

It can stitch and merge schema files together.

## Demo

Merging schema files:
![Demo showing usage of gqlt](./demo/demo.gif)

## Usage

`gqlt merge ./file1.graphql ./file2.graphql ./combined.graphql`  
or even, when your shell (e.g. zsh) supports it:  
`gqlt merge ./graphql/**/*.graphql ./combined.graphql`

The last path is the output file.

_note: bash is also supported for recursive globs (path/\*\*/\*.gql) with `shopt -s globstar`_

## Install

`brew install digiz3d/tap/gqlt`

## Stack

Made 100% with [Zig](https://ziglang.org).  
No dependencies.

## Compile from source

Run `zig build`.  
gqlt will be compiled for your current platform here: `./zig-out/bin/gqlt`.

## Comparison with other tools

Tools we compare **gqlt** with:  
[@graphql-tools/merge](https://www.npmjs.com/package/@graphql-tools/merge)  
[gqlmerge](https://github.com/mununki/gqlmerge)

|                                    | gqlt                                          | @graphql-tools/merge) | gqlmerge                                                                                           |
| ---------------------------------- | --------------------------------------------- | --------------------- | -------------------------------------------------------------------------------------------------- |
| **Speed**                          | fastest 🚀                                    | slow                  | fast                                                                                               |
| **Limitations**                    | <ul><li>no directives concatenation</li></ul> | none                  | <ul><li>no object/input/union/interface/enum merging</li><li>no directives concatenation</li></ul> |
| **Indentation**                    | ✅                                            | ✅                    | ❌ inconsistent                                                                                    |
| **Order definitions**              | ❌                                            | ✅                    | ❌                                                                                                 |
| **Descriptions**                   | ✅                                            | ✅                    | ✅                                                                                                 |
| **Comments**                       | ❌                                            | ❌                    | ✅                                                                                                 |
| **Double quotes in block strings** | ✅                                            | ✅                    | ❌                                                                                                 |

see [benchmarks](./benchmark/README.md)

## Motivations

By doing this project, my goals were to

1. learn Zig
2. write my first, real parser
3. implement some benchmark

## Thanks to

- [gqlmerge](https://github.com/mununki/gqlmerge). Even if it did not work for my use case, it is a great tool for simpler projects. Learnt a lot from it !
- [astexplorer](https://github.com/fkling/astexplorer) for visual representation of the JS GraphQL parser output.
- [GraphQL specification](https://spec.graphql.org/draft/) for the grammar and the syntax.
