# nota

`nota` parses a custom syntax for expressing *nodes.*

![GIF](./nota.gif)

Licensed under [GPL-3.0](./LICENCE). To get `nota`,
[download the latest release](https://github.com/felix-u/nota/releases/tag/v0.1) or follow the
[compilation instructions](#building).

### Summary

Nodes are declared using the `@` character and can contain a number of information fields. Syntax is not
whitespace-sensitive, and the order of these fields is irrelevant - but the body *must* come last. The following are
nodes' possible fields and their respective delimiters:

| Node        | Delimiters | Requirement |
| :---------- | :--------: | :---------- |
| Name        | N/A        | optional    |
| Description | `()`         | optional    |
| Date        | `[]`         | optional    |
| Tags        | `<>`         | optional    |
| Body        | `{}`         | mandatory   |

The simplest possible node is the empty node, holding no optional fields and an empty body: `@{}`.

### Examples

A more productive setup, however, could look as follows:

`~/Desktop/notafile`
```
@Work(Programming) {
    @Task(URGENT)[2023-01-20] <x> {
        Release nota
    }
    @Task[2023-03-01 12:30] < > {
        Work on refactoring nota
    }
}

@Work(Job) {
    @Task(URGENT) [2023-02-01] < > {
        Soul-crushing drudgery
    }
}

@Booklist {
    @Book(The Pickwick Papers) [1836-12-31] <x> {}
    @Book(David Copperfield) <p> {}
    @Book(Great Expectations) < > {}
}
```

Running `nota ~/Desktop/notafile` will spit out our structure as-is, nicely formatted and with syntax highlighting
(not visible on GitHub):
```
Work | Programming
	x  Task | URGENT | 2023-01-20
	Release nota

	Task | 2023-03-01 12:30
	Work on refactoring nota

Work | Job
	Task | URGENT | 2023-02-01
	Soul-crushing drudgery

Booklist
	x  Book | The Pickwick Papers | 1836-12-31

	Book | David Copperfield

	Book | Great Expectations
```

For now, I'm only interested in my upcoming tasks.
I'll run:
```sh
$ nota ~/Desktop/notafile --after --date now --sort ascending --node Task
```
```
 x  Task | URGENT | 2023-01-20
Release nota

Task | URGENT | 2023-02-01
Soul-crushing drudgery

Task | 2023-03-01 12:30
Work on refactoring nota
```
That was a lot. I can omit `--date now`, since `--after` and `--before` use the current date anyway, if no other date
is passed. Now we have `--after --sort ascending`; I anticipated this being a common use case, so `--upcoming`, or `-u`
in short form, is exactly equivalent. Running `nota ~/Desktop/notafile -u --node Task`, or
`nota ~/Desktop/notafile -un Task`, results in exactly the same output as above.

I've already done my first task, and tagged it with `<x>` - the default tag character. I only want to see what I've not
done yet, so I'll add the `--not-tagged` option. Also, I'll limit my search to tasks with the description `URGENT` by
adding the `--desc URGENT` option. The final command, using short-form flags where applicable, is:
```sh
$ nota ~/Desktop/notafile -un Task --not-tagged --desc URGENT
```
```
Task | URGENT | 2023-02-01
Soul-crushing drudgery
```
Perfect.

I can apply much the same workflow to my `@Booklist`. The default `tagchar` is `x`, which I used to mark books I
finished, but I also used `p` to denote in-progress readings. I can get what I'm looking for using:
```sh
$ nota ~/Desktop/notafile --node Book --tagged --tagchar p
```
```
 p  Book | David Copperfield
```

### Usage
```
nota <OPTION>... <FILE>

OPTIONS:
  -a, --after
	narrows selection to nodes after given date(s), or after 'now' if none are specified
  -b, --before
	narrows selection to nodes before given date(s), or before 'now' if none are specified
  -d, --date <STR>
	narrows selection by given date: <ISO 8601>, <NUM>, 'now'/'n'.
	Flags that rely on a date use 'now' if the user does not specify one
      --desc <STR>
	narrows selection by given description
  -n, --node <STR>
	narrows selection by given node name(s)
      --tagchar <STR>
	provides tag character
  -t, --tagged
	limits selection to tagged nodes (default tag character: 'x')
      --not-tagged
	limits selection to nodes NOT tagged (default tag character: 'x')
  -s, --sort <STR>
	sorts by: 'descending'/'d', 'ascending'/'a'
  -u, --upcoming
	equivalent to '--after --sort ascending'
      --no-colour
	disables colour in output. This will also occur if TERM=dumb, NO_COLO(U)R or NOTA_NO_COLO(U)R is set, or
	the output is piped to a file
      --no-color
	equivalent to the above
  -h, --help
	display this help and exit
      --version
	output version information and exit
```

### Building

These dependencies are likely already present on any UNIX-like OS:

- `git`
- a C99 compiler, such as `gcc` or `clang`
- a `make` implementation, such as `gnumake`

Using `git`, clone the source code and navigate to the desired release, where `X.X` is the version number. Building
from the `master` branch is highly discouraged.
```sh
$ git clone https://github.com/felix-u/nota
$ git checkout vX.X
```

To compile an optimised binary at `./nota` relative to this repository's root directory, run:
```sh
$ make release
```

To compile this binary *and* copy it to `~/.local/bin`, run:
```sh
$ make install
```
