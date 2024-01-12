# Testing

Here are all the tests you need to pass to get a full score in lab2: 

 - args-none
 - args-many
 - open-create
 - open-rdwr
 - open-trunc
 - open-many
 - read-zero
 - read-normal
 - write-zero
 - write-normal
 - close-normal
 - exec-once
 - exec-multiple
 - exec-arg
 - wait-simple
 - wait-twice
 - exit
 - halt
 - rox-simple
 - rox-child
 - rox-multichild
 - close-stdio
 - close-badfd
 - close-twice
 - read-badfd
 - read-stdout
 - write-badfd
 - write-stdin
 - boundary-normal
 - boundary-bad
 - open-invalid
 - sc-bad-sp
 - sc-bad-args
 - exec-invalid
 - wait-badpid
 - wait-killed
 - bad-load
 - bad-store
 - bad-jump
 - bad-load2
 - bad-store2
 - bad-jump2

These test cases are recorded in `tool/bookmarks/lab2.toml`, and you can test the whole lab by
```sh
# under tool/
cargo tt -b lab2
```
To check the expected grade of your current codes, use
```sh
# under tool/
cargo grade -b lab2
```
