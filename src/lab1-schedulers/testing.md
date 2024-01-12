# Testing

Here are all the tests you need to pass to get a full score in lab1: 

 - alarm-zero
 - alarm-negative
 - alarm-simultaneous
 - alarm-single
 - alarm-multiple
 - priority-alarm
 - priority-change
 - priority-condvar
 - priority-fifo
 - priority-preempt
 - priority-sema
 - donation-chain
 - donation-lower
 - donation-nest
 - donation-one
 - donation-sema
 - donation-two
 - donation-three

These test cases are recorded in `tool/bookmarks/lab1.toml`, and you can test the whole lab by
```sh
# under tool/
cargo tt -b lab1
```
To check the expected grade of your current codes, use
```sh
# under tool/
cargo grade -b lab1
```