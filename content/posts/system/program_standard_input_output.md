---
title: 程序的标准输入输出流
date: 2026-07-02T20:26:18+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-07-02T20:26:18+08:00
math: true
lightgallery: false
summary: "通过 Go 语言学习程序的标准输入输出流"
categories:
  - system
  - Go
tags:
  - Go
  - system
---

使用一些 CLI 工具时经常会搭配 `|` 管道符和 `>` 重定向符。比如：`cat file.txt | rg "pattern"` 或 `echo "hello" > out.txt`。
以前只是会用，没有深究它们背后的机制。之前只知道 `fmt.Scanln()` 可以从标准输入读取字符，直到最近才发现也可以用管道来给程序提供输入，比如：`echo 'hello' | ./binary`，然后在程序里使用 `fmt.Scanln()` 读取到的就是 `hello`。

**这篇文章来学习一下程序的标准输入输出流**

程序启动后通常会继承 3 个已经打开的文件描述符：标准输入、标准输出和标准错误输出。它们在 Go 里分别对应 `os.Stdin`、`os.Stdout` 和 `os.Stderr`。

本文从 `fmt.Println` 开始，顺着 Go 标准库源码看一下标准输入输出流在程序里是什么，以及为什么 `shell` 重定向能单独处理正常输出和错误输出。

## `fmt.Println` 在做什么

```go
package main

import "fmt"

func main() {
	fmt.Println("result")
}
```

查看 `fmt.Println` 的源码，可以看到它最终是向 `os.Stdout` 写入数据。

```go
func Println(a ...any) (n int, err error) {
	return Fprintln(os.Stdout, a...)
}
```

继续看 `os.Stdout`，会发现 `Stdin`、`Stdout`、`Stderr` 都是 `*os.File` 类型的变量。

```go
package os

var (
	Stdin  = NewFile(uintptr(syscall.Stdin), "/dev/stdin")
	Stdout = NewFile(uintptr(syscall.Stdout), "/dev/stdout")
	Stderr = NewFile(uintptr(syscall.Stderr), "/dev/stderr")
)
```

这里的 `NewFile` 不是重新打开 `/dev/stdout` 这个路径，而是把已经存在的文件描述符包装成一个 `*os.File`。第二个参数只是这个 `*os.File` 的名字，用于调试、错误信息或调用 `Name()` 时返回。

## 为什么是 `*os.File` 类型

在 Unix-like 系统里，文件描述符不仅可以指向普通文件，也可以指向终端、管道、socket 等对象。Go 用 `*os.File` 包装这些文件描述符，这样标准输入输出就能复用标准库里基于 `io.Reader` 和 `io.Writer` 的 API。

需要注意的是，`*os.File` 提供了 `Read` 和 `Write` 方法，但具体能不能读写取决于底层文件描述符的打开方式。一般来说：

- `os.Stdin` 通常用于读。
- `os.Stdout` 通常用于写。
- `os.Stderr` 通常用于写错误或诊断信息。

## `syscall` 中的 `Stdin`、`Stdout`、`Stderr` 是什么

`syscall.Stdin`、`syscall.Stdout`、`syscall.Stderr` 是文件描述符编号。

```go
package syscall

const (
	Stdin  = 0
	Stdout = 1
	Stderr = 2
)
```

文件描述符可以理解为进程打开文件表中的一个整数索引。按照约定：

- fd 0 是标准输入。
- fd 1 是标准输出。
- fd 2 是标准错误输出。

这 3 个文件描述符通常由父进程准备好，然后被当前程序继承。比如在 shell 里启动一个程序时，shell 会先设置好 fd 0、1、2，再创建子进程执行你的程序。如果使用了重定向，shell 就会在启动程序前把对应的 fd 指向文件、管道或其它目标。

详细信息可以通过 `man 3 stdio` 查看。

## `/dev/stdin`、`/dev/stdout`、`/dev/stderr` 是什么

`/dev/stdin`、`/dev/stdout`、`/dev/stderr` 通常不是真正的普通文件，而是指向当前进程文件描述符的链接。

```text
$ ls -l /dev/stdin /dev/stdout /dev/stderr
lrwxrwxrwx. root root 15 B Sun Jun 28 22:45:40 2026  /dev/stderr ⇒ /proc/self/fd/2
lrwxrwxrwx. root root 15 B Sun Jun 28 22:45:40 2026  /dev/stdin ⇒ /proc/self/fd/0
lrwxrwxrwx. root root 15 B Sun Jun 28 22:45:40 2026  /dev/stdout ⇒ /proc/self/fd/1
```

`/proc/self/fd/` 里面是当前进程打开的文件描述符映射。`self` 是 `/proc/[当前进程 PID]` 的快捷方式，谁访问它，看到的就是自己的 fd 表。

## 如何使用

### 向标准输出写数据

```go
package main

import (
	"bufio"
	"fmt"
	"os"
)

func main() {
	// 直接使用 fmt.Println 向标准输出写数据
	fmt.Println("result")

	// 使用 bufio.NewWriter 向标准输出写数据
	buf := bufio.NewWriter(os.Stdout)
	_, _ = buf.WriteString("write to stdout\n")
	_ = buf.Flush()

	// 使用 os.Stdout.Write 向标准输出写数据
	_, _ = os.Stdout.Write([]byte("write to stdout\n"))
}
```

### 从标准输入读数据

```go
package main

import (
	"fmt"
)

func main() {
	var s string
	_, _ = fmt.Scanln(&s)
	fmt.Println(s)
}
```

使用 `go run main.go` 运行程序后，输入 `hello`，按回车，就会输出 `hello`，不过我们也可以从标准输入读取管道传来的数据，比如：

```bash
echo 'hello' | go run main.go
```
因为 `fmt.Scanln` 是从标准输入读取数据的，所以管道里的 `hello` 会被读取到。源码如下：

```go
package fmt

func Scanln(a ...any) (n int, err error) {
	return Fscanln(os.Stdin, a...)
}
```

### 标准错误输出

```go
package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Fprintln(os.Stderr, "this is an error message")
}
```

## 标准错误输出和标准输出的区别

`Stdout` 是正常输出通道，`Stderr` 是错误或诊断信息的独立通道。

```go
package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Println("this is a normal message")
	fmt.Fprintln(os.Stderr, "this is an error message")
}
```

- 正常运行没区别，会在终端上同时显示正常信息和错误信息。
- 如果使用重定向就能看到区别：
  - `go run main.go > out.txt`
    - 终端只能看到：`this is an error message`
    - 文件 `out.txt` 只能看到：`this is a normal message`
  - `go run main.go 2> err.txt`
    - 终端只能看到：`this is a normal message`
    - 文件 `err.txt` 只能看到：`this is an error message`
  - `go run main.go > out.txt 2> err.txt`
    - 正常输出进入 `out.txt`
    - 错误输出进入 `err.txt`
  - `go run main.go > all.txt 2>&1`
    - 标准输出和标准错误输出都会进入 `all.txt`

这也是为什么命令行程序通常会把机器可读的结果写到 `Stdout`，把日志、告警、错误信息写到 `Stderr`。这样用户在管道或重定向输出时，可以单独处理真正的结果数据。
