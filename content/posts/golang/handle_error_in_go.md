---
title: 在Go中优雅地处理defer中的err
subtitle: ""
date: 2026-05-26T17:31:19+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-05-26T17:31:19+08:00
math: true
lightgallery: false
summary: "如何在函数中优雅的处理defer中的错误"
categories:
  - Go
---

处理一个错误非常简单

```go
package main

func main() {
    var err error
    if err != nil {
        // 处理错误
    }
}
````

在一个返回错误的函数中处理也很简单

```go {hl_lines=[8]}
package main
import "os"
func doSomething() error {
    fd,err := os.Open("file.txt")
    if err != nil {
        return err
    }
    defer fd.Close()
    // 对文件读写操作
    
    return nil
}
```

> [!warning] 但上面的处理方式有些问题
> defer后面的文件关闭操作有可能会出错，此时调用方完全不知道发生了什么

更好的做法，参考知名项目的做法，例如 [kubebuilder](https://github.com/kubernetes-sigs/kubebuilder/blob/e6b337e1bbdc9f36d3e87eed67daf08bc7851600/pkg/machinery/scaffold.go#L343)

返回值使用命名返回值，确保defer 中可以覆盖err

```go {hl_lines=[8,9]}
func (s Scaffold) loadModelFromFile(path string) (f *File, err error) {
	reader, err := s.fs.Open(path)
	if err != nil {
		return nil, OpenFileError{err}
	}
	defer func() {
	  // 只有在函数主体正常，并且关闭文件错误时才会覆盖err
		if closeErr := reader.Close(); err == nil && closeErr != nil {
			err = CloseFileError{closeErr}
		}
	}()

	content, err := afero.ReadAll(reader)
	if err != nil {
		return nil, ReadFileError{err}
	}

	return &File{Path: path, Contents: string(content)}, nil
}
```

更加完善的错误方式，可以在defer中使用 `errors.Join` 来合并错误

```go {noClasses=true style="emacs"}
package main
import (
    "errors"
    "fmt"
    "os"    
)
func doSomething() (err error) {
	err = os.ErrExist
	defer func() {
		// a new error occurred during cleanup
		cleanupErr := os.ErrClosed
		// var cleanupErr error = nil 即使是nil，也不影响原来的错误
		// combine the original error with the cleanup error
		err = errors.Join(err, cleanupErr)
	}()

	return err
}

func main() {
	err := doSomething()
	// 使用errors.Is来判断错误
	// 或者使用 errors.As
	// 或者使用 errors.AsType
	if errors.Is(err, os.ErrExist) {
		fmt.Println("original error: os.ErrExist")
	}
	if errors.Is(err, os.ErrClosed) {
		fmt.Println("original error: os.ErrClosed")
	}
}

```
