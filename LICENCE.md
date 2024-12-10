# Licence

- SPDX-License-Identifier: [Apache-2.0][apache-2]

`Prosody` is copyright 2025 Austin Ziegler and is licensed under the
[Apache License, version 2.0](licences/APACHE-2.0.txt).

## Developer Certificate of Origin

All contributors **must** certify they are willing and able to provide their
contributions under the terms of this project's licences with the certification
of the [Developer Certificate of Origin (Version 1.1)](licences/dco.txt).

Such certification is provided by ensuring that a `Signed-off-by`
[commit trailer][trailer] is present on every commit:

    Signed-off-by: FirstName LastName <email@example.org>

The `Signed-off-by` trailer can be automatically added by git with the `-s` or
`--signoff` option on `git commit`:

```sh
git commit --signoff
```

## Test Fixtures

To ensure that word counting algorithms work properly, the following public
domain works have been added under `test/support/fixtures/en`:

- _A Modest Proposal_ by Jonathan Swift (1729)
- _Alice's Adventures in Wonderland_ by Lewis Carroll (1865)
- _Frankenstein_ by Mary Wollstonecraft Shelley (1818)
- _The Adventure of the Three Students_ by Arthur Conan Doyle (1904)
- _The Black Cat_ by Edgar Allan Poe (1843)
- _The Pit and the Pendulum_ by Edgar Allan Poe (1842)
- _The Time Machine_ by H.G. Wells (1895)

To ensure that code counting algorithms work properly, the following programs
from various repositories under [TheAlgorithms][alg] have been included under
`test/support/fixtures/code`. All of the samples chosen are licensed under the
[MIT licence](licences/algorithms-mit.txt).

- [`test/support/fixtures/code/bubble_sort.cpp`][cpp]
- [`test/support/fixtures/code/bubble_sort.ex`][ex]
- [`test/support/fixtures/code/bubblesort.go`][go]
- [`test/support/fixtures/code/bubble_sort.py`][py]
- [`test/support/fixtures/code/bubble_sort.rs`][rs]
- [`test/support/fixtures/code/bubbleSort.zig`][zig]

[alg]: https://github.com/TheAlgorithms
[apache-2]: https://spdx.org/licenses/Apache-2.0.html
[cpp]: https://github.com/TheAlgorithms/C-Plus-Plus/blob/master/sorting/bubble_sort.cpp
[elixir]: https://github.com/elixir-lang/elixir
[ex]: https://github.com/TheAlgorithms/Elixir/blob/master/lib/sorting/bubble_sort.ex
[go]: https://github.com/TheAlgorithms/Go/blob/master/sort/bubblesort.go
[py]: https://github.com/TheAlgorithms/Python/blob/master/sorts/bubble_sort.py
[rs]: https://github.com/TheAlgorithms/Rust/blob/master/src/sorting/bubble_sort.rs
[trailer]: https://git-scm.com/docs/git-interpret-trailers
[zig]: https://github.com/TheAlgorithms/Zig/blob/main/sort/bubbleSort.zig
