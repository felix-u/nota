# nota

`nota` parses a custom syntax for expressing *nodes.*

*GIF should go here*

Licensed under [GPL-3.0](./LICENCE).

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

Running `nota ~/Desktop/notafile` will spit out the node structure:
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
