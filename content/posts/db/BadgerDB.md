---
title: 自顶向下阅读 BadgerDB 源码
subtitle: ""
date: 2026-01-11T20:27:34+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: "为SSD优化的纯Go编写的嵌入式键值存储数据库 BadgerDB 源码阅读"
toc: true
lastmod: 2026-01-11T20:27:34+08:00
math: true
lightgallery: false
summary: ""
categories:
  - DB
  - Go
tags:
  - Go
  - DB
---

<!--more-->

> [!abstract] 前言
> - [BadgerDB](https://github.com/dgraph-io/badger) 是一个为 SSD 优化的基于事务的纯 `Go` 编写的嵌入式键值存储数据库。用法可以参考[文档](https://dgraph-io.github.io/badger/quickstart.html)
> - 作为一个菜鸡, 来阅读下 `BadgerDB` 的源码, 大概了解下它的实现原理

## `DB`

### Open

> 初始化配置和资源, 返回一个 `DB` 对象

```go {hl_lines=[8]}
package main

import (
    "github.com/dgraph-io/badger/v4"
)

func main() {
    db, err := badger.Open(badger.DefaultOptions("/tmp/badger_db"))
    if err != nil {
        panic(err)
    }

    defer db.Close()
}
```

#### 流程分析

1. 检查和设置选项
2. 目录创建与锁定
3. 初始化 `DB` 结构体
4. 根据配置初始化块缓存和索引缓存
5. 启动后台任务: 
   - `monitorCache`
   - `updateSize`
   - 非只读情况下启动 `flushMemtable`
   - `doWrites`
   - `listenForValueThresholdUpdate`
   - 非内存模式下启动 `waitOnGC`
   - `listenForupdates`

### `Update`

> [!NOTE] BadgerDB 通过 `Update` 方法进行**写新数据**/**更新已有数据**/**删除数据**

#### 使用示例 

> `Update` 方法接受一个 `func(txn *badger.Txn) error` 类型的参数, 用于在事务中进行写操作

```go {hl_lines=[3,7]}
func update(db *badger.DB) error {
    return db.Update(func(txn *badger.Txn) error {
        err := txn.Delete([]byte("delete_key"))
        if err != nil {
            return err
        }
        return txn.Set([]byte("insert_or_update_key"),[]byte("value"))
    })
}
```

#### 流程分析

```go {hl_lines=[8,11,15]}
func (db *DB) Update(fn func(txn *Txn) error) error {
	if db.IsClosed() {
		return ErrDBClosed
	}
	if db.opt.managedTxns {
		panic("Update can only be used with managedDB=false.")
	}
	txn := db.NewTransaction(true)
	defer txn.Discard()

	if err := fn(txn); err != nil {
		return err
	}

	return txn.Commit()
}
```

1. 检查是否 `db` 是否已经关闭
2. 如果处于托管事务模式, 直接panic, 因为 `Update` 方法只能在 非托管模式下使用
3. 创建`非只读事务` `txn`
4. 执行 `fn(txn *badger.Txn) error` 函数
5. 提交事务

### `View`

> [!NOTE] BadgerDB 通过 `View` 方法进行**读数据**

#### 使用示例

```go
func view(db *badger.DB, key []byte) error {
    return db.View(func(txn *badger.Txn) error {
        _, err := txn.Get(key)
        if err != nil {
            return err
        }

        return nil
    })
}
```

#### 流程分析

```go {hl_lines=[5,11,13]}
func (db *DB) View(fn func(txn *Txn) error) error {
	if db.IsClosed() {
		return ErrDBClosed
	}
	var txn *Txn
	if db.opt.managedTxns {
		txn = db.NewTransactionAt(math.MaxUint64, false)
	} else {
		txn = db.NewTransaction(false)
	}
	defer txn.Discard()

	return fn(txn)
}
```

1. 检查是否 `db` 是否已经关闭
2. 检查是否处于托管模式
   - 托管事务: 调用 `NewTransactionAt` 创建**只读事务**
   - 非托管事务: 调用 `NewTransaction` 创建**只读事务**
3. 执行 `fn(txn *badger.Txn) error` 函数

> [!NOTE] 只读事务中只能进行读操作, 不能进行写操作

## `Txn`

```go {name="https://github.com/dgraph-io/badger/blob/main/txn.go"}
type Txn struct {
	readTs   uint64
	commitTs uint64
	size     int64
	count    int64
	db       *DB

	reads []uint64 // contains fingerprints of keys read.
	// contains fingerprints of keys written. This is used for conflict detection.
	conflictKeys map[uint64]struct{}
	readsLock    sync.Mutex // guards the reads slice. See addReadKey.

	pendingWrites   map[string]*Entry // cache stores any writes done by txn.
	duplicateWrites []*Entry          // Used in managed mode to store duplicate entries.

	numIterators atomic.Int32
	discarded    bool   // 事务是否被丢弃
	doneRead     bool
	update       bool   // 区分读写事务还是只读事务, 控制写入权限
}
```

### `txn.Get`

方法签名: `func (txn *Txn) Get(key []byte) (item *Item, rerr error)`

1. 使用 `len(key) == 0` 一并处理 `[]byte{}` 和 `nil` 这两种情况
2. 如果事务被丢弃, 返回 `ErrDiscardedTxn` 错误
3. 判断key是否是被ban掉的key: `bannedNsKey  = []byte("!badger!banned")`
4. 如果事务是可写事务, 
   1. 如果在写缓存 `pendingWrites`中查找相同的key, 并且相等
      1. 如果已经被删除或过期, 返回 `ErrKeyNotFound` 错误
      2. 构造`item`并返回. 值得注意的是这里标记了一个状态: `item.status = prefetched`
   2. 记录这次读操作
5. 将 `key` 构造为内部带时间戳的查找key, 从存储层db中查找
   1. 如果获取失败, 返回错误
   2. 如果获取成功, 判断下是否已经被删除或过期
6. 构造 `item` 并返回

### `txn.Set` / `txn.SetEntry`

> 调用关系: `Set(key, val []byte) -> SetEntry(e *Entry) -> modify(e *Entry)`

> [!INFO] 实现逻辑如下, 主要分为前置条件检查和缓冲区写入

1. 判断当前事务类型, 是否是更新事务
2. 判断当前事务是否已经被丢弃
3. 判断插入的`key`是否为空, 从这里可以看出<u>不能**Set空的key**</u>
4. 判断当前`key`是否包含内置的 `badgerPrefix`
5. 判断当前`key`的大小是否大于`maxKeySize=65000`(写死的). 这个值是否有特殊含义尚不清楚
6. 判断`value`的大小是否超过`ValueLogFileSize`
7. 检查在**内存模式**下, `value`的大小是否超过了`value`的阈值
8. 如果开启**冲突检测**, 记录`key`的哈希到`conflictKeys`这个集合中
9. 如果当前key存在, 已经被写入过一次了, 并且旧版本和新版本不同(ManagedMode, 用户可以手动指定每一条写入的版本号, 这个是合法的), 将旧的entry保存到`duplicateWrites`中 
10. 如果不存在或已经存在, 但是版本号相同, 将当前`key` 和 `entry` 写入缓冲区中(直接覆盖)

> [!WARNING] 为了性能, 使用的是key和value的引用, 事务结束之前不能修改底层数组

### `txn.Delete`

> 调用链: `Delete(key []byte) -> modify(e *Entry)`

```go {lineNos=false}
func (txn *Txn) Delete(key []byte) error {
	e := &Entry{
		Key:  key,
		meta: bitDelete,   // 通过标记位来表示已被删除
	}
	return txn.modify(e)
}
```

`Delete`操作比较简单, 需要注意的是注释中的一些点:

- 在此时间戳之前的读取不受影响. 旧事务可以读到被删除之前的旧值, 新的读事务遇到这个带有`bitDelete`标记的最新版本也能知道被删除
- 为了性能优化, 当前事务并没有复制 `key`, 而是持有引用, 所以当前事务结束之前, 不能修改key的底层数组 


### `txn.Commit`

[Update](#update) 和 [View](#view) 都是先创建事务, 然后执行`Set`,`Delete`,`Get`等, 最后提交事务. 接下来我们分析下如何创建, 销毁, 提交事务.

