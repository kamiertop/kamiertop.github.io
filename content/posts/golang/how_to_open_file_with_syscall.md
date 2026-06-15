---
title: Go中如何使用 syscall 处理文件相关操作
date: 2026-05-26T17:13:28+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
toc: true
lastmod: 2026-05-26T17:13:28+08:00
math: true
lightgallery: false
summary: "使用os包处理文件操作非常简单，不过关于底层如何做的还是需要学习实践一下"
categories:
  - Go
---

使用 `os` 包处理文件操作非常简单，标准库封装了 `File` 类型和相关方法，使得文件操作非常方便

{{< image src="/golang/File.png" caption="`File的方法列表`" >}}

细读源码发现底层是通过 `syscall` 包来实现的，`syscall` 包提供了对底层操作系统调用的访问，可以直接使用系统调用来进行文件操作，下面使用 `syscall` 包来实现一个简单的文件打开和读取的例子

- {{< link "https://man7.org/linux/man-pages/man2/open.2.html" >}}
- {{< link "https://man7.org/linux/man-pages/man2/write.2.html" >}}
- {{< link "https://man7.org/linux/man-pages/man2/close.2.html" >}}

```go {hl_lines=[13,20,29,23]}
package main

import (
	"fmt"
	"syscall"
)

func main() {
	path := "/tmp/syscall_demo.txt"
	data := []byte("hello from syscall\n")

	// 1. open/creat — O_CREAT|O_WRONLY|O_TRUNC, 权限 0644
	fd, err := syscall.Open(path, syscall.O_WRONLY|syscall.O_TRUNC, 0644)
	if err != nil {
		fmt.Println("open error:", err)
		return
	}

	// 2. write — 把数据写入文件描述符
	n, err := syscall.Write(fd, data)
	if err != nil {
		fmt.Println("write error:", err)
		syscall.Close(fd)
		return
	}
	fmt.Printf("wrote %d bytes to %s (fd=%d)\n", n, path, fd)

	// 3. close — 关闭文件描述符
	if err := syscall.Close(fd); err != nil {
		fmt.Println("close error:", err)
		return
	}

	fmt.Println("done")
}

```

上面的例子中，使用系统调用的方式打开一个文件，获取到文件描述符后，使用 `syscall.Write` 将数据写入文件，最后关闭文件描述符。不过相比使用标准库，我们失去了方法调用的便捷性和错误处理的抽象以及一些安全性检查，因此在实际开发中，除非有特殊需求，否则建议使用 `os` 包来处理文件操作
