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

WaitGroup 的使用非常简单，新建变量，使用`wg.Go`传入一个闭包函数，然后使用`wg.Wait()`等待所有goroutine完成即可

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
	// 每个传递给 wg.Go 的函数都会运行在一个新的 goroutine 中
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

上面是一个简单的例子，可以将多个顺序耗时的任务并行执行，执行时间约为耗时最长的那个goroutine的时间

## 源码实现

### `WaitGroup`

```go
// WaitGroup 第一次使用之后禁止复制
type WaitGroup struct {
	// 禁止复制
	noCopy noCopy

	state atomic.Uint64
	// 信号量
	sema  uint32
}
```

state是多个字段的复合体，是一个原子类型的Uint64类型，好处是在并发访问的情况下不需要使用锁，直接使用原子操作即可，state的结构如下：

```text
[ counter 32位 ] [ bubble 1位 ] [ waiters 31位 ]
  bits 63..32       bit 31       bits 30..0
```

也可以从低位到高位理解：

```text
bits 0..30   waiter count，共 31 位，表示阻塞在 Wait() 上的 goroutine 数量
bit  31      bubble flag，synctest 使用的标志位，正常阅读源码时可以先忽略
bits 32..63  counter，共 32 位，按 int32 解释，表示未完成的任务数量
```

源码里对应的取值方式是：

```go
v := int32(state >> 32)         // counter
w := uint32(state & 0x7fffffff) // waiters
```

`counter` 虽然占 32 位，但是会被转换成 `int32`，所以最大正常值是 `2^31-1`。如果变成负数，`Add` 会直接 panic。`waiters` 是低 31 位的无符号计数，最大值也是 `2^31-1`。

`sema` 是运行时信号量。`Wait()` 发现 counter 不为 0 时，会阻塞在 `sema` 上；最后一个 `Done()` 把 counter 减到 0 时，会通过 `sema` 唤醒所有等待的 goroutine。


### `Go(f func())` 方法

> 新版本提供的封装，推荐使用

> [!warning] // The function f must not panic.
> **f函数不能panic**
> 关于为什么在这里使用recover()捕获可能的panic然后又重新panic，在新的文章中讲述 [通过sync.WaitGroup学习defer, recover, panic]({{% relref "posts/golang/defer_panic_recover" %}})

```go
func (wg *WaitGroup) Go(f func()) {
	// 新增一个任务，计数器加1
	wg.Add(1)
	// 开启一个新的goroutine执行f函数
	go func() {
		defer func() {
			// 这里的处理很有意思，看新的文章即可
			if x := recover(); x != nil {
				panic(x)
			}
			// 任务完成，计数器减1
			wg.Done()
		}()
		f()
	}()
}
```

`Go` 方法本质上就是帮我们封装了常见写法：先 `Add(1)`，然后启动 goroutine，函数正常结束时再 `Done()`。这样可以减少把 `Add(1)` 写进 goroutine 内部导致的错误。

### `Add(delta int)` 方法

> [!note] `Add` 将 WaitGroup 的任务计数器增加 delta
> 这里我们先跳过synctest相关的内容，移除race和synctest相关的代码，简化后的Add方法如下：

```go
func (wg *WaitGroup) Add(delta int) {
	state := wg.state.Add(uint64(delta) << 32)
	v := int32(state >> 32)
	w := uint32(state & 0x7fffffff)

	if v < 0 {
		panic("sync: negative WaitGroup counter")
	}
	if w != 0 && delta > 0 && v == int32(delta) {
		panic("sync: WaitGroup misuse: Add called concurrently with Wait")
	}
	if v > 0 || w == 0 {
		return
	}

	if wg.state.Load() != state {
		panic("sync: WaitGroup misuse: Add called concurrently with Wait")
	}

    // 如果走到这里，v == 0 && w != 0
	// 说明这一轮的最后一个 Done() 已经把 counter 减到 0，并且有 goroutine 正在 Wait()，所以要唤醒它们
	wg.state.Store(0)
	for ; w != 0; w-- {
		runtime_Semrelease(&wg.sema, false, 0)
	}
}
```

这段代码可以分成三层来看：

```text
第一层：更新并拆解 state
第二层：检查 WaitGroup 的错误用法
第三层：如果 counter 归零，唤醒所有 waiter
```

#### 第一层：更新并拆解 state

最重要的是这一次原子加法：

```go
state := wg.state.Add(uint64(delta) << 32)
```

因为 counter 存在高 32 位，所以 `delta` 左移 32 位之后再加到 `state` 上。这样做只会改变高 32 位的 counter，不会影响低 31 位的 waiters。

例如 `Add(1)`：

```text
uint64(1)       = 0x0000_0000_0000_0001
uint64(1) << 32 = 0x0000_0001_0000_0000
```

如果 `state` 原来是 0，那么执行 `Add(1)` 之后：

```text
state = 0x0000_0001_0000_0000
```

也就是 counter 从 0 变成 1。

`Add(-1)` 也能工作，是因为负数转成 `uint64` 后是补码形式：

```text
uint64(-1)       = 0xffff_ffff_ffff_ffff
uint64(-1) << 32 = 0xffff_ffff_0000_0000
```

把这个值加到 `state` 上，效果就是高 32 位 counter 减 1，低 32 位保持不变。因此 `Done()` 可以直接实现为 `Add(-1)`。

然后取出 counter 和 waiters：

```go
v := int32(state >> 32)
w := uint32(state & 0x7fffffff)
```

`state >> 32` 会把高 32 位移动到低 32 位，得到 counter。再转换成 `int32`，就可以判断 counter 是否小于 0。

`0x7fffffff` 是低 31 位全 1、其他位全 0 的掩码：

```text
0x00000000_7fffffff
```

所以 `state & 0x7fffffff` 会清掉高 32 位 counter 和 bit 31 的 bubble flag，只保留低 31 位 waiters。

经过这一层之后，后面的逻辑只关心两个变量：

```text
v = counter，未完成任务数
w = waiters，正在 Wait() 里阻塞的 goroutine 数量
```

#### 第二层：检查错误用法

接下来这个判断用于防止 counter 被减成负数：

```go
if v < 0 {
    panic("sync: negative WaitGroup counter")
}
```

比如没有先 `Add(1)` 就直接 `Done()`：

```go
var wg sync.WaitGroup
wg.Done()
```

`Done()` 等价于 `Add(-1)`，counter 会从 0 变成 -1，于是 panic。

-----------------------

下面这个判断是 `Add` 里最容易误解的一段：

```go
if w != 0 && delta > 0 && v == int32(delta) {
    panic("sync: WaitGroup misuse: Add called concurrently with Wait")
}
```

三个条件分别表示：

- `w != 0`：已经有 goroutine 在 `Wait()` 里登记为 waiter
- `delta > 0`：这次调用是在新增任务
- `v == int32(delta)`：本次 `Add(delta)` 之前 counter 是 0，因为加完后的 counter 正好等于 delta

合起来就是：已经有人开始 `Wait()`，另一个 goroutine 又从 counter 为 0 的状态开始 `Add(正数)` 新增任务。这是 WaitGroup 的误用。

错误写法如下：

```go
var wg sync.WaitGroup

go func() {
    wg.Add(1)
    defer wg.Done()
    work()
}()

wg.Wait()
```

这里 `wg.Wait()` 可能先执行，看到 counter 是 0，就直接返回。随后 goroutine 才执行 `Add(1)`，这个任务就没有被等待。

正确写法是先 `Add(1)`，再启动 goroutine：

```go
var wg sync.WaitGroup

wg.Add(1)
go func() {
    defer wg.Done()
    work()
}()

wg.Wait()
```

需要注意，源码并不是说所有 `Add` 都必须发生在 `Wait` 之前。更准确的规则是：当 counter 为 0 时，正数 `Add` 必须发生在 `Wait` 之前。如果 counter 已经大于 0，那么正数 `Add` 可以和 `Wait` 并发；负数 `Add`，也就是 `Done()`，本来就经常和 `Wait()` 并发。

#### 第三层：决定是否唤醒 waiter

接下来这个分支是快速返回：

```go
if v > 0 || w == 0 {
    return
}
```

如果 `v > 0`，说明还有任务没完成，不能唤醒 `Wait()`。如果 `w == 0`，说明没有 goroutine 正在等待，也不需要唤醒。只有一种情况会继续往下走：

```text
v == 0 && w > 0
```

也就是这次 `Add(-1)`，通常是 `Done()`，刚好把 counter 减到 0，并且有 goroutine 正在 `Wait()`。

这时当前 goroutine 就是最后一个完成任务的 goroutine，它负责唤醒所有等待者：

```go
if wg.state.Load() != state {
    panic("sync: WaitGroup misuse: Add called concurrently with Wait")
}

wg.state.Store(0)

for ; w != 0; w-- {
    runtime_Semrelease(&wg.sema, false, 0)
}
```

当前 goroutine 已经把 counter 设置成 0，并且 waiter 数量大于 0。此时按照正确用法，不应该再有别的 goroutine 修改 `state`：

- 新的 `Add(正数)` 不能和当前这一轮 `Wait` 并发
- `Wait()` 如果看到 counter 已经是 0，也不会再增加 waiter

所以 `wg.state.Load() != state` 是一次便宜的安全检查。如果读到的状态和刚才不一样，说明中间有人并发修改了 `state`，属于 WaitGroup 误用。

检查通过后，`wg.state.Store(0)` 把 counter 和 waiters 都清零。然后根据之前记录的 `w`，释放 `w` 次信号量，唤醒所有阻塞在 `Wait()` 里的 goroutine。

所以 `Add` 的整体逻辑可以概括为：

```text
1. 原子更新 counter
2. counter 小于 0，panic
3. 检测 counter 为 0 时 Add(正数) 和 Wait 并发的误用
4. 如果还有任务没完成，或者没人等待，直接返回
5. 如果 counter 归零且有人等待，清空 state，唤醒所有 waiter
```

### `Done()` 方法

> [!note] `Done()` 将 WaitGroup 的任务计数器减 1，本质是调用 `Add(-1)`，表示一个任务完成了，非常简单（早年刚学习时有教程让用`wg.Add(-1)`，虽然没错，但是面试时被人笑话了，明显是要用 `wg.Done()`，语义更强）

```go
package sync
func (wg *WaitGroup) Done() {
	wg.Add(-1)
}
```

`Done()` 没有额外逻辑，它只是给 `Add(-1)` 一个更明确的语义：当前任务完成了。

### `Wait()` 方法

> [!note] `Wait()` 阻塞当前 goroutine，直到 WaitGroup 的任务计数器为 0，表示所有任务都完成了

```go
func (wg *WaitGroup) Wait() {
	for {
		state := wg.state.Load()
		v := int32(state >> 32)
		w := uint32(state & 0x7fffffff)
		if v == 0 {
			// counter 已经是 0，说明没有任务需要等待，直接返回。
			return
		}
		// counter 不为 0，说明还有任务没完成，把当前 goroutine 登记为 waiter。
		if wg.state.CompareAndSwap(state, state+1) {
			runtime_SemacquireWaitGroup(&wg.sema, false)
			isReset := wg.state.Load() != 0
			if isReset {
				panic("sync: WaitGroup is reused before previous Wait has returned")
			}
			return
		}
	}
}
```

`Wait()` 是一个循环，因为读取 `state` 之后，到登记 waiter 之前，可能有别的 goroutine 修改了 `state`。所以它使用 CAS：

```go
wg.state.CompareAndSwap(state, state+1)
```

这里的 `state+1` 很巧妙。waiters 存在低 31 位，所以 `state+1` 就是在不影响 counter 的情况下，把 waiter count 加 1。

`Wait()` 的逻辑分两种情况。

第一种，counter 已经是 0：

```go
if v == 0 {
    return
}
```

说明没有任务需要等待，直接返回。

第二种，counter 大于 0：

```go
if wg.state.CompareAndSwap(state, state+1) {
    runtime_SemacquireWaitGroup(&wg.sema, false)
    ...
    return
}
```

这时 `Wait()` 要先通过 CAS 把 waiter count 加 1。CAS 成功之后，当前 goroutine 会阻塞在 `sema` 上，等待最后一个 `Done()` 唤醒它。

如果 CAS 失败，说明刚才读取的 `state` 已经过期了，可能 counter 已经变化，也可能 waiters 已经变化。此时重新进入循环，再读一次最新状态。

被唤醒之后还有一个检查：

```go
isReset := wg.state.Load() != 0
if isReset {
    panic("sync: WaitGroup is reused before previous Wait has returned")
}
```

正常情况下，最后一个 `Done()` 会先执行：

```go
wg.state.Store(0)
```

然后再释放信号量唤醒所有 waiter。所以 waiter 醒来之后，应该看到 `state == 0`。如果醒来后发现 `state != 0`，说明这个 WaitGroup 在上一批 `Wait()` 还没完全返回之前就被重新 `Add` 复用了，这是错误用法。

## 总结

`WaitGroup` 的核心是一个 64 位原子状态和一个运行时信号量：

- `state` 的高 32 位是 counter，记录未完成任务数
- `state` 的低 31 位是 waiters，记录阻塞在 `Wait()` 上的 goroutine 数量
- `sema` 用来让 `Wait()` 睡眠，并在 counter 归零时唤醒它们

使用时最重要的规则是：

- `Done()` 必须和之前的 `Add(1)` 配对，否则 counter 可能变成负数
- counter 为 0 时，新的 `Add(正数)` 必须发生在 `Wait()` 之前
- 如果要复用 WaitGroup，必须等上一轮所有 `Wait()` 都返回之后，再开始下一轮 `Add()`

因此，最推荐的写法是使用 `wg.Go`。如果手动写 `Add` 和 `Done`，就把 `Add(1)` 放在启动 goroutine 之前：

```go
wg.Add(1)
go func() {
    defer wg.Done()
    work()
}()
wg.Wait()
```

## 扩展

> [!tip] 我们可以简单扩展下 `WaitGroup`，获取当前的计数器值以及当前的等待者数量，方便调试和监控(虽然也有其他方式，比如手动维护一个计数器，或者使用 `sync/atomic` 的 `AddInt32` 来维护一个计数器)

{{< link href="https://github.com/kamiertop/syncx" content="syncx" card=true >}}
