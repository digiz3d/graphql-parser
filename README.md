# GraphQL toolkit - gqlt

Extremely fast GraphQL parser and merger.

It can stitch and merge schema files together.

## Demo

Merging schema files:
![Demo showing usage of gqlt](./demo/demo.gif)

## Usage

`gqlt merge ./graphql/**/*.graphql ./combined.graphql`  
or even  
`gqlt merge ./file1.graphql ./file2.graphql ./combined.graphql`

The last path is the output file.

_note:  
Bash is also supported for recursive globs (path/\*\*/\*.gql) with `shopt -s globstar`_

## Install

`brew install digiz3d/tap/gqlt`

## Compile from source

Run `zig build`.  
gqlt will be compiled for your current platform here: `./zig-out/bin/gqlt`.

## Comparison with other tools

### gqlt

- fastest implementation 🚀 (see [benchmarks](./benchmark/README.md))
- lacking directives concatenation
- does not preserve comments (but keeps descriptions)
- does not order definitions

### [@graphql-tools/merge](https://www.npmjs.com/package/@graphql-tools/merge)

- much slower than gqlt
- complete implementation
- preseve comments
- can order definitions alphabetically

### [gqlmerge](https://github.com/mununki/gqlmerge)

- blazing fast, but slower than gqlt
- lacking features like object type merging or union merging or directives concatenation
- preserves comments
- does not order definitions

## Motivations

By doing this project, my goals were to

1. learn Zig
2. write my first complete parser
3. implement some benchmark

## Thanks to

- [gqlmerge](https://github.com/mununki/gqlmerge). Even if it did not work for my use case, it is a great tool for simpler projects. Learnt a lot from it !
- [astexplorer](https://github.com/fkling/astexplorer) for visual representation of the JS GraphQL parser output.
