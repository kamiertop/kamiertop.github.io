---
title: Go sync.WaitGroup 源码解读
date: 2026-07-07T13:03:26+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
toc: true
lastmod: 2026-07-07T13:03:26+08:00
math: true
lightgallery: false
summary: "sync.WaitGroup 用于等待一组goroutine完成"
collections:
  - sync
categories:
  - Go
tags:
  - Go
---

> [!abstract] version: `go1.26` 
> `sync.WaitGroup` 用于等待一组goroutine完成，使用简单方便，本文简单介绍使用方法以及源码实现

## 使用方法

WaitGroup 的使用非常简单，新建变量，使用wg.Go传入一个闭包函数，然后使用wg.Wait()等待所有goroutine完成即可

```go
package main

import (
	"fmt"
	"sync"
	"time"
)

func main() {
    var wg sync.WaitGroup
    fmt.Println("main goroutine start, time:", time.Now().Unix())
    wg.Go(func() {
        time.Sleep(time.Second)
        fmt.Println("goroutine1 sleep finished, time:", time.Now().Unix())
    })
    wg.Go(func() {
        time.Sleep(time.Second*2)
        fmt.Println("goroutine2 sleep finished, time:", time.Now().Unix())
    })
    wg.Wait()
    fmt.Println("main goroutine end, time:", time.Now().Unix())
}
```

## 源码实现

### `WaitGroup`

结构体如下

```go
type WaitGroup struct {
	// 禁止复制
	noCopy noCopy

	// Bits (high to low):
	//   bits[0:32]  counter
	//   bits[32]    flag: synctest bubble membership
	//   bits[33:64] wait count
	state atomic.Uint64
	sema  uint32
}
```

### `Go(f func())` 方法

### `Add(delta int)` 方法

### `Done()` 方法

### `Wait()` 方法