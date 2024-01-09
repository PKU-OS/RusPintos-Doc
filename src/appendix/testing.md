# Testing

For your convenience during the labs, we've provided a set of tools. They are in `./tool/` directory. In the rest of this section, we'll use `./tool/` as the directory of the tools, and `./` as the directory of the OS. 

> To use the tools you'll need to set your working directory under `./tool/` but not `./`, because the rust toolchain used by the tools (i.e., x86) is different from that by the OS itself (i.e., RISC-V).

For the usage of the toolset, you can run this command under `./tool/` for help information:
```sh
cargo h
```
Such command is an alias of a more complicated command. For its original version (and other aliases) please refer to `./tool/.cargo/config.toml`. 

In the rest of this section, we'll introduce the functions of the toolset.

## Build

Basically, you can build the OS manually by running `cargo` under `./`. However, to correctly run and test your OS, there are some other building works, including building user programs and the disk image. Since these peripheral parts ar not written in Rust, building them manually is less convenient, and the building order makes the works more confusing. 

In the toolset, we've provided a build tool. Run `cargo h build` for the usage (the alias of build tool is `cargo bd`):
```
Build the project

Usage: tool build [OPTIONS]

Options:
  -c, --clean    Clean
  -r, --rebuild  Clean and rebuild. `--clean` will be ignored
  -v, --verbose  Show the build process
  -h, --help     Print help information
```

You can simply build the whole project, including OS, user programs and disk image by `cargo bd`. Also, you can clean or rebuild the project by specifying the `-c` and `-r` arguments. By the `-v` you can see the output of the building process (though they might not be helpful, just for fun).

To manually build the OS, you can run `cargo` under `./`. In this way you can control the features you want to include. Existing feathres are listed in `./Cargo.toml`. 

To manually build use programs, you can run `make` under `./`. All of the user programs are written in C and located under `./user/`. If you want to write your own user programs, you can add `*.c` files under `./user/userprogs/` or `./user/vm/`. If you need to add a new sub-directory, like `./user/yours/`, you'll need to add `user/yours` to the `SRC_DIRS` in `./user/utests.mk`, otherwise your new program will not be added into disk image and your OS will not find it.

To manually build the disk image, uses `make build/disk.img` under `./`.

We do not recommend you to use these two way (`./tool/` & `./`) simultaneously, for the grading process is based on `./tool/`. In essential, we do not recommend you to change any of the config files (`Cargo.toml`, `makefile` and `config.toml`). If you need to change them, please contact the TA and clarify your special testing methods.

## Test

The toolset also provides a tool to test your OS for the test cases that are included in the grading process. Run `cargo h test` for the usage (the alias of test tool is `cargo tt`):
```
Specify and run test cases

Usage: tool test [OPTIONS]

Options:
  -c, --cases <CASES>
          The test cases to run. Only the name of test case is required.
          
          Example: `tool test -c args-none` , `tool test -c args-none,args-many`

  -b, --books <BOOKS>
          Load specified bookmarks and add to the test suite

  -p, --previous-failed
          Add test cases that failed in previous run to the test suite

      --dry
          Only show the command line to run, without starting it

      --gdb
          Run in gdb mode. Only receive single test case

  -g, --grade
          Grading after test

  -v, --verbose
          Verbose mode without testing. Suppress `--gdb` and `--grade`

  -h, --help
          Print help information (use `-h` for a summary)
```

The test tool has several ways to use. 

**The first way** is to test one or a few specified cases. The usage is `cargo tt -c <args>`. An example is `cargo tt -c args-none,args-many`, which specifies the `args-none` and `args-many` cases. Some test cases need to pass special arguments to the OS through QEMU (like `args-many`), but you'll not need to pass it manulally. The test tool takes over it.

The first way is not convenient when your are testing too many cases. **The second way**, specified by `-b`, is introduced to solve this problem. In this way, the tool receive a set of toml files which specify the test cases and the arguments, then run them in one shot. For example, if you want to test the entire lab1 and lab2, you can run `cargo tt -b lab1,lab2`. The specified toml files are called "bookmarks". They must locate in `./tool/bookmarks/`. We've provided four of them with the code base: lab1, lab2, lab3 and unit. You cannot change these files, but you can create your own bookmarks.

**The thrid way** allows you to test the cases that you've just failed. Whenever the test tool run, it records the failed test cases in a bookmark called `previous-failed.toml`. To only test these cases in your next run, you can use this bookmark. We've also provided an argument, `-p`, as an alias.

**The fourth way** is the grading mode. You can use the `-g, --grade` addon argument, or use the alias `cargo grade`. This is similar to test mode (ways 1-3), except the tool will show the grade of your OS when the test ends. We also uses this way to grade your submission.

**The fifth way** is the gdb mode, specified by an addon argument `--gdb` (example: `cargo tt -c args-none --gdb`). An alias is also provided: `cargo gdb`. In this way, the test tool will start a background gdb process, which you can attach to via another gdb client. This is to help you to debug your OS in gdb without writing confusing QEMU cmds. Please note that in this mode, only one test case can be passed to the test tool. Bookmarks or more than one cases will be rejected. 

**The sixth way** is dry run mode, specified by `--dry`, which is an addon argument. In the dry run mode, the test tool will not really start your OS, but show the commands for each test cases. These commands can be used under `./`. For example, if we run `cargo tt -c args-many --dry`, the outpout will be:
```
Command for args-many:
cargo run -r -q -F test-user -- -append "args-many a b c d e f g h i j k l m n o p q r s t u v"
```
You can use the shown command under `./` to test the `args-many` case. In this way, you can see the entire log info of your OS. In default way, the test tool will only report the last 10 lines. You can also use `-v` for the entire output, however, the grading will not function under verbose mode.

## Bookmark

In the test section, we said that the test tool can receive a bookmark in `./tool/bookmarks/`, and you can build your own bookmarks for convenience. The bookmark tool is provided to let you build your bookmarks. Run `cargo h book` to see the usage (the alias of bookmark tool is `cargo bk`):
```
Remember specific test cases

Usage: tool book [OPTIONS] --name <NAME>

Options:
  -n, --name <NAME>
          The name of the bookmark.
          
          Bookmark will be saved in `/bookmarks/<name>.json`

  -d, --del
          Delete mode. Turn 'add' into 'delete' in other options.
          
          If no test cases are specified, delete the whole bookmark (with its file!).

  -c, --cases <CASES>
          Test cases to add in this bookmark

  -b, --books <BOOKS>
          Bookmarks to load and add to this bookmark

  -p, --previous-failed
          Add test cases that failed in previous run to the bookmark

  -h, --help
          Print help information (use `-h` for a summary)
```
In essential, the bookmarks record the name, arguments and grade of each test case. Some of the arguments are complex, and the grade is not that important for creating bookmarks. So the bookmark tool is to provide a way that only creates bookmarks by the name. 

An example usage, which create a bookmark named `mybk.toml` and including `args-none, args-many` test cases are:
```sh
cargo bk -n mybk -c args-none,args-many
```

The usage and meaning of bookmark tool is quite similar to the test tool. The `-c` is used to add specified cases. The `-b` is used to add all the cases in another bookmark (example: `cargo bk -n mylab2 -b lab2`). The `-p` is used to add the failed test cases in your last run (example: `cargo bk -n failed-in-run-87 -p`).

The tool also provide `-d` for delete mode. For example, if the `args-none` is ensured to be passable, and you do not care about it anymore, you can delete it from `mybk` by running `cargo bk -n mybk -d -c args-none`. This mode can also receive `-b` and `-p`. You may want to keep a backup of your important bookmarks when using this mode!
