---
title: BadgerDB
subtitle: ""
date: 2026-01-11T20:27:34+08:00
draft: true
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

- `BadgerDB` 是一个为 SSD 优化的基于事务的纯 `Go` 编写的嵌入式键值存储数据库。用法可以参考官方文档: [BadgerDB](https://github.com/dgraph-io/badger)
- 作为一个菜鸡, 来阅读下 `BadgerDB` 的源码, 大概了解下它的实现原理

## Open

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

### 流程分析

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

## `Update`

> [!NOTE] BadgerDB 通过 `Update` 方法进行**写新数据**/**更新已有数据**/**删除数据**

### 使用示例 

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

### 流程分析

```go
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

## `View`

> [!NOTE] BadgerDB 通过 `View` 方法进行**读数据**

### 使用示例

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

### 流程分析

```go
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

### `txn.Set`

### `txn.Delete`

