# Testing

To get a full score in lab3, you need to pass all the tests in `lab2.toml` and `lab3.toml`.

To run the tests in lab2, use

```sh
# under tool/
cargo tt -b lab2
```

To run the tests in lab3, use

```sh
# under tool/
cargo tt -b lab3
```

To get the expected score, run `cargo grade -b lab2` and `cargo grade -b lab3` together. Let `A` be the grade of `cargo grade -b lab2`, and `B` be the grade of `cargo grade -b lab3`, your final score in lab3 = `0.4 * A + 0.6 * B`
