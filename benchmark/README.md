# gqlt benchmark

Keep in mind that the graphql files are simple and do not represent a real-world scenario.  
Performances vary per platform.

Example of results:

On my personal computer

```
Summary
  zig ran
    1.28 ± 0.57 times faster than go
    7.34 ± 2.33 times faster than bun
```

On Github Action - ubuntu-latest

```
Summary
  zig ran
    1.45 ± 0.18 times faster than go
   25.26 ± 3.87 times faster than bun
```

## Run the benchmark

```
mise install
mise run bench
```
