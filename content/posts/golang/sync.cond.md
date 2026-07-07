---
title: Go sync.Cond 源码解读
date: 2026-07-06T14:23:12+08:00
draft: false
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
toc: true
lastmod: 2026-07-06T14:23:12+08:00
math: true
lightgallery: false
summary: "`sync.Cond` 用于让一组 goroutine 等待某个共享状态满足条件，适合表达可重复发生的状态变化"
collections:
  - sync
categories:
  - Go
tags:
  - Go
---

>[!abstract] **version**：`go1.26`
> `sync.Cond` 是条件变量（Condition Variable），用于让 goroutine 在某个共享状态不满足条件时等待，在状态变化后由其他 goroutine 唤醒它们。它不是 channel 的替代品，而是更适合表达「共享状态 + 条件等待 + 可重复通知」的同步原语。

## `Cond` 使用场景

`sync.Cond` 的核心作用是：**等待某个条件成立**。

比如：

- 队列为空时，消费者等待「队列里有数据」
- 队列满了时，生产者等待「队列有空位」
- 系统暂停时，工作 goroutine 等待「系统恢复运行」
- 配置版本没变化时，监听者等待「配置发生变化」

它和 `Mutex` 配合使用。`Mutex` 保护共享状态，`Cond` 负责让 goroutine 在条件不满足时睡眠，并在条件可能满足时被唤醒。

源码里的结构如下：

```go
type Cond struct {
	noCopy noCopy

	// L is held while observing or changing the condition
	L Locker

	notify  notifyList
	checker copyChecker
}
```

其中最重要的是 `L Locker`。调用方必须用这把锁保护条件变量依赖的共享状态。

典型写法是：

```go
c.L.Lock()
for !condition() {
	c.Wait()
}
// 使用已经满足条件的共享状态
c.L.Unlock()
```

这里必须用 `for`，不能用 `if`。因为 `Wait` 返回后，只能说明当前 goroutine 被唤醒了，只代表“有人通知你状态可能变了”，不代表“你要等的条件现在一定成立”

## 通过两个示例学习

> 之前从未用过这个，让AI生成了两个示例进行学习理解

### 配置中心

假设有一个配置中心，多个 goroutine 会读取同一份配置。配置可能被后台线程更新，所有监听者都需要在配置版本变化后被唤醒，然后读取最新配置。

这个场景里，goroutine 等待的不是一条消息，而是一个共享状态发生变化：

```go
store.version != seenVersion
```

`version` 是配置的版本号，`seenVersion` 是当前 goroutine 已经看到的版本号。如果两个版本一样，说明配置没有变化，当前 goroutine 就可以睡眠等待。

```go
package main

import (
	"fmt"
	"maps"
	"sync"
	"time"
)

// ConfigStore 用一个配置中心的例子演示 sync.Cond。
//
// 多个 watcher 会等待“配置版本号发生变化”这个条件。
// Update 修改版本号后用 Broadcast 唤醒所有 watcher。
type ConfigStore struct {
	mu      sync.Mutex
	cond    *sync.Cond
	config  map[string]string
	version int
	closed  bool
}

func NewConfigStore(config map[string]string) *ConfigStore {
	s := &ConfigStore{
		config:  copyConfig(config),
		version: 1,
	}
	s.cond = sync.NewCond(&s.mu)
	return s
}

// Snapshot 返回当前配置和版本号。
//
// 返回 map 的副本，避免调用方绕过锁直接修改 s.config。
func (s *ConfigStore) Snapshot() (map[string]string, int) {
	s.mu.Lock()
	defer s.mu.Unlock()

	return copyConfig(s.config), s.version
}

// Watch 阻塞等待配置版本变化。
//
// seenVersion 是调用方已经看过的版本号。
// 返回 ok=false 表示 ConfigStore 已关闭，调用方应该退出。
func (s *ConfigStore) Watch(watcherID, seenVersion int) (map[string]string, int, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Cond 不是用来“等通知”的，而是用来“等某个条件变成 true”。
	// 这里的条件是：s.version != seenVersion || s.closed。
	//
	// 必须用 for，而不是 if：
	// 1. 被唤醒后要重新检查条件，因为拿回锁之前状态可能又变了。
	// 2. Broadcast 会叫醒所有 watcher，但每个 watcher 都要基于当前状态自己判断。
	for !s.closed && s.version == seenVersion {
		fmt.Printf("watcher %d: version %d is current, waiting\n", watcherID, seenVersion)

		// Wait 要在持有 s.mu 时调用。
		// 它会原子地做两件事：
		// 1. 解锁 s.mu，让 Update/Close 有机会修改状态。
		// 2. 挂起当前 goroutine。
		//
		// Wait 返回前会重新锁住 s.mu，所以循环里再次读取 s.version/s.closed 是安全的。
		s.cond.Wait()

		fmt.Printf("watcher %d: woke up, rechecking condition\n", watcherID)
	}

	if s.closed {
		return nil, 0, false
	}

	return copyConfig(s.config), s.version, true
}

// Update 修改配置和版本号，并唤醒所有等待版本变化的 watcher。
func (s *ConfigStore) Update(config map[string]string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.config = copyConfig(config)
	s.version++
	fmt.Println("===========================")
	fmt.Printf("store: updated to version %d, broadcasting\n", s.version)
	fmt.Println("===========================")

	// 修改条件对应的状态后，再唤醒等待者。
	// Broadcast 会唤醒所有等待者；Signal 只唤醒一个。
	// 配置更新通常要让所有订阅者都看到，所以这里用 Broadcast。
	s.cond.Broadcast()
}

// Close 关闭 ConfigStore，唤醒所有正在 Watch 中等待的 goroutine。
func (s *ConfigStore) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.closed = true
	fmt.Println("store: closed, broadcasting")
	s.cond.Broadcast()
}

func copyConfig(src map[string]string) map[string]string {
	dst := make(map[string]string, len(src))
	maps.Copy(dst, src)
	return dst
}

func runWatcher(id int, store *ConfigStore, wg *sync.WaitGroup) {
	defer wg.Done()

	_, version := store.Snapshot()
	fmt.Printf("watcher %d: start at version %d\n", id, version)

	for {
		config, nextVersion, ok := store.Watch(id, version)
		if !ok {
			fmt.Printf("watcher %d: store closed, exit\n", id)
			return
		}

		version = nextVersion
		fmt.Printf("watcher %d: observed version %d config=%v\n", id, version, config)
	}
}

func main() {
	store := NewConfigStore(map[string]string{
		"log_level": "info",
	})

	var wg sync.WaitGroup
	for i := range 3 {
		wg.Add(1)
		go runWatcher(i, store, &wg)
	}

	time.Sleep(100 * time.Millisecond)
	store.Update(map[string]string{
		"log_level": "debug",
	})

	time.Sleep(100 * time.Millisecond)
	store.Update(map[string]string{
		"log_level": "error",
	})

	time.Sleep(100 * time.Millisecond)
	store.Close()
	wg.Wait()
}

```

这个例子里有几个关键点：

- `version` 是真正的条件状态
- `cond` 只负责让 goroutine 等待和唤醒
- `Watch` 里用 `for s.version == seenVersion` 判断是否需要继续等待
- `Update` 修改配置和版本号后调用 `Broadcast`，唤醒所有监听者
- `Close` 也调用 `Broadcast`，避免还有 goroutine 永久阻塞在 `Wait`

`Cond` 不保存「配置是否变化」这个状态。状态保存在 `ConfigStore` 里，也就是 `config`、`version`、`closed`。`Cond` 只负责等待和通知。

### 连接池：等待一个空闲连接

上面的配置更新例子只用了 `Broadcast`，因为配置变化后所有 watcher 都应该被唤醒

`Signal` 适合另一类场景：**只产生了一个可用资源，只需要唤醒一个等待者**

比如一个连接池里没有空闲连接时，调用方需要等待。某个连接被归还后，只多出来一个空闲连接，所以唤醒一个等待者就够了

```go
package main

import (
	"fmt"
	"sync"
	"time"
)

// Pool 用连接池演示 sync.Cond.Signal。
//
//   - 配置更新要让所有 watcher 都醒来，所以用 Broadcast。
//   - 连接池每次 Put 只新增 1 个可用连接，所以只需要 Signal 唤醒 1 个等待者。
type Pool struct {
	mu     sync.Mutex
	cond   *sync.Cond
	idle   []Conn
	closed bool
}

type Conn struct {
	ID int
}

func NewPool(conns []Conn) *Pool {
	p := &Pool{
		idle: append([]Conn(nil), conns...),
	}
	p.cond = sync.NewCond(&p.mu)
	return p
}

// Get 获取一个连接。
//
// 如果当前没有空闲连接，就阻塞等待 Put 放回连接，或者 Close 关闭连接池。
func (p *Pool) Get() (Conn, bool) {
	p.mu.Lock()
	defer p.mu.Unlock()

	// 等待的条件是：len(p.idle) > 0 || p.closed。
	//
	// 仍然必须用 for：
	// 1. Signal 只表示“可能有资源了”，不表示当前 goroutine 一定能拿到资源。
	// 2. 被唤醒后，要在锁保护下重新检查 len(p.idle) 和 p.closed。
	for !p.closed && len(p.idle) == 0 {
		fmt.Println("pool: no idle connection, waiting")
		p.cond.Wait()
		fmt.Println("pool: woke up, rechecking idle connections")
	}

	if p.closed {
		return Conn{}, false
	}

	n := len(p.idle) - 1
	conn := p.idle[n]
	p.idle = p.idle[:n]
	return conn, true
}

// Put 归还一个连接。
func (p *Pool) Put(conn Conn) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.closed {
		fmt.Printf("pool: already closed, drop conn %d\n", conn.ID)
		return
	}

	p.idle = append(p.idle, conn)
	fmt.Printf("pool: put conn %d, signaling one waiter\n", conn.ID)

	// 这里只增加了 1 个连接，唤醒 1 个等待者就够了。
	// 如果用 Broadcast，所有等待者都会醒来抢同一个连接，最后大多数还得继续睡。
	p.cond.Signal()
}

// Close 关闭连接池。
//
// 关闭时要用 Broadcast，因为所有正在 Get 里等待的 goroutine 都需要醒来并退出。
func (p *Pool) Close() {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.closed = true
	fmt.Println("pool: closed, broadcasting to all waiters")
	p.cond.Broadcast()
}

func main() {
	pool := NewPool([]Conn{{ID: 1}})

	var wg sync.WaitGroup
	for i := range 4 {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()

			conn, ok := pool.Get()
			if !ok {
				fmt.Printf("worker %d: pool closed, exit\n", workerID)
				return
			}

			fmt.Printf("worker %d: got conn %d\n", workerID, conn.ID)
			time.Sleep(100 * time.Millisecond)

			fmt.Printf("worker %d: put conn %d back\n", workerID, conn.ID)
			pool.Put(conn)
		}(i)
	}

	time.Sleep(250 * time.Millisecond)
	pool.Close()
	wg.Wait()
}
```

这里的两个通知动作语义不同：

- `Put` 只归还了一个连接，所以用 `Signal` 唤醒一个等待者
- `Close` 会让所有等待者都不能继续等待，所以用 `Broadcast` 唤醒全部 goroutine 退出

## 源码解读

### `Cond`

```go
type Cond struct {
	// 编译时辅助 vet 工具检查是否被复制
	noCopy noCopy

	// L 一般是 Mutex 或 RWMutex，也可以是实现 Locker 接口的其他类型，在检查或修改条件时需要持有锁
	L Locker
	// notify runtime 内部维护的等待队列
	notify  notifyList
	// 运行时检查 Cond 是否被复制
	checker copyChecker
}

type notifyList struct {
	wait   uint32
	notify uint32
	lock   uintptr // key field of the mutex
	head   unsafe.Pointer
	tail   unsafe.Pointer
}
```

### `Wait`

> [!important] 使用 `Wait` 前必须加锁
> 因为 `Wait` 等的不是通知本身，而是某个共享条件变成 `true`。这把锁保护的是共享条件的状态

```go
func (c *Cond) Wait() {
	// 检查 Cond 是否被复制
	c.checker.check()
	// 将调用者添加到通知列表中，以便它可以接收通知 runtime/sema.go:
	// notifyListAdd func notifyListAdd(l *notifyList) uint32 { return l.wait.Add(1) - 1}
	// 每有一个 goroutine 调用 Wait，就会在 notifyList 中增加一个等待者，返回一个唯一的标识 t，有了这个 t 才能在后续的 Signal 或 Broadcast 中唤醒这个等待者
	t := runtime_notifyListAdd(&c.notify)
	// 解锁，其他 goroutine 就可以修改共享状态了。所以调用 Wait 前必须持有锁，Wait 内部会解锁
	c.L.Unlock()
	// runtime/sema.go: notifyListWait
	// 等待通知，如果已经有了通知立即返回，否则挂起当前 goroutine，直到被唤醒
	runtime_notifyListWait(&c.notify, t)
	// Wait() 返回之后，马上就要继续读取或者修改那个共享条件，而这个共享状态必须在锁的保护下才能安全访问，所以 Wait() 返回前会重新加锁
	c.L.Lock()
}
```

### `Signal` 和 `Broadcast`

`Signal` 唤醒一个等待者（没有顺序保证啥的），代码很简单，不涉及锁

```go
func (c *Cond) Signal() {
	c.checker.check()
	runtime_notifyListNotifyOne(&c.notify)
}
```

适合「只需要一个 goroutine 继续工作」的场景，例如连接池归还了一个连接。

`Broadcast` 唤醒所有等待者，从函数名上可以清晰直观地看出它的语义

```go
func (c *Cond) Broadcast() {
	c.checker.check()
	runtime_notifyListNotifyAll(&c.notify)
}
```

适合「全局状态变化，所有等待者都应该重新检查条件」的场景，例如恢复运行、配置更新、关闭系统。

调用 `Signal` 和 `Broadcast` 时，官方允许不持有 `c.L`。但实际代码里，如果唤醒和共享状态变化有关，通常建议在持有同一把锁时修改状态并发出通知。这样更容易保证状态变化和通知动作在代码结构上绑定在一起。

## 使用规则

`sync.Cond` 的规则可以总结成几条：

- `Cond` 必须和一把锁一起使用
- 条件依赖的共享状态必须由这把锁保护
- 调用 `Wait` 前必须持有锁
- `Wait` 必须放在 `for !condition()` 循环里
- 修改条件状态后，再调用 `Signal` 或 `Broadcast`
- `Signal` 唤醒一个等待者，`Broadcast` 唤醒全部等待者
- `Cond` 不能在首次使用后被复制

什么时候用 `Cond`：

- 等待的是共享状态，而不是单个消息
- 条件会重复变成 true / false
- 需要唤醒一个或全部等待者
- 用 channel 会引入额外的状态同步和 channel 生命周期管理

什么时候不用 `Cond`：

- 只是传递任务或数据，用 channel
- 只是通知退出，用 `close(done)`
- 只是等待一组 goroutine 完成，用 `sync.WaitGroup`
- 只是限制并发数量，用带缓冲 channel 或 semaphore

简单说：**channel 适合传递数据和一次性通知，`sync.Cond` 适合等待共享状态满足条件。**

## `copyChecker` 的原理

> [!info] 检查 `sync.Cond` 第一次使用之后是否被复制
> 核心原理是：<span style="color: red; font-weight:bold;">如果 Cond 在使用之后被复制了，那么 checker 保存的值不会变，仍然是原对象里的 checker 地址。复制后的 checker 位于新的内存地址，所以保存的旧地址和当前地址不一样，就能判断 Cond 被复制了</span>

```go
type copyChecker uintptr

func (c *copyChecker) check() {
	// 检查分为三步：
	// 1. uintptr(*c) != uintptr(unsafe.Pointer(c))：检查 copyChecker 保存的地址和当前 copyChecker 的地址是否相同，如果不同，说明 Cond 被复制了
	// 如果不相等，有两种情况
	// 第一种是第一次使用，还是初始值 0
	// 第二种是 Cond 被复制了，checker 保存的是旧地址，还不能立刻 panic
	if uintptr(*c) != uintptr(unsafe.Pointer(c)) &&
		// 如果当前值是 0，说明是第一次使用 Cond，尝试将 copyChecker 的值设置为当前 Cond 的地址，然后如果设置失败，说明 Cond 被复制了
		// CAS 失败有两种可能：另一个 goroutine 已经初始化成功了；或者这个对象是复制出来的，里面不是 0，所以要再次检查
		!atomic.CompareAndSwapUintptr((*uintptr)(c), 0, uintptr(unsafe.Pointer(c))) &&
		// 保存的地址 != 当前自己的地址，在这里已经排除“第一次使用还没初始化”的情况，还不相等，就说明保存的是旧对象的地址，但自己已经在另一个新地址上
		uintptr(*c) != uintptr(unsafe.Pointer(c)) {

		panic("sync.Cond is copied")
	}
}
```

这段代码在第一次执行时会把 `copyChecker` 的值设置为当前 `Cond` 的地址，之后每次调用 `check()` 时都会比较保存的地址和当前 `Cond` 的地址是否相同，如果不相同就说明 `Cond` 被复制了，触发 panic。

- 核心是比较保存的地址和当前 Cond 的地址是否相同
  - `uintptr(*c)`: `c` 是指针类型，`*c` 表示指针指向的值，`uintptr(*c)` 表示将这个值转换为 `uintptr` 类型，表示保存下来的地址
  - `uintptr(unsafe.Pointer(c))`: 把 `*copyChecker` 指针转成通用指针，然后再转成 `uintptr` 类型，表示 `copyChecker` 本身的内存地址
