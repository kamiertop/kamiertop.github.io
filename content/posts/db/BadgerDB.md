---
title: 自顶向下探究 BadgerDB 实现
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

## `Overview`

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

```go {hl_lines=[8,11,15]}
func (db *DB) Update(fn func(txn *Txn) error) error {
	if db.IsClosed() {             // 如果已经关闭, 直接返回错误
		return ErrDBClosed
	}
	if db.opt.managedTxns {        // 如果处于自动模式, 直接panic, 因为 Update 方法只能在自动模式下使用
		panic("Update can only be used with managedDB=false.")
	}
	txn := db.NewTransaction(true)  // 新建事务
	defer txn.Discard()

	if err := fn(txn); err != nil { // 执行用户逻辑
		return err
	}

	return txn.Commit()             // 提交事务
}
```

### `View`

> [!NOTE] BadgerDB 通过 `View` 方法进行**读数据**


```go {hl_lines=[5,11,13]}
func (db *DB) View(fn func(txn *Txn) error) error {
	if db.IsClosed() {             // 如果已经关闭, 直接返回错误
		return ErrDBClosed
	}
	var txn *Txn
	if db.opt.managedTxns {        // 如果处于自动模式, 调用 `NewTransactionAt` 创建**只读事务**
		txn = db.NewTransactionAt(math.MaxUint64, false)
	} else {                      // 如果处于手动模式, 调用 `NewTransaction` 创建**只读事务**
		txn = db.NewTransaction(false)
	}
	defer txn.Discard()

	return fn(txn)                // 执行用户逻辑
}
```

> [!NOTE] 只读事务中只能进行读操作, 不能进行写操作

## `Txn`

```go {name="https://github.com/dgraph-io/badger/blob/main/txn.go"}
type Txn struct {
	readTs   uint64  // 定义了事务能"看到"的数据版本范围, 确保事务读取的是一致的快照
	commitTs uint64
	size     int64
	count    int64
	db       *DB

	reads []uint64 // contains fingerprints of keys read.
	
	conflictKeys map[uint64]struct{} // 保存写入的key的指纹, 用来做冲突检测.
	readsLock    sync.Mutex // guards the reads slice. See addReadKey.
   
	pendingWrites   map[string]*Entry // 缓存待提交的数据.
	duplicateWrites []*Entry          // Used in managed mode to store duplicate entries.

	numIterators atomic.Int32
	discarded    bool   // 事务是否被丢弃
	doneRead     bool
	update       bool   // 区分读写事务还是只读事务, 控制写入权限
}
```

### `txn.Get`

```go
func (txn *Txn) Get(key []byte) (item *Item, rerr error) {
	// 是否为空
	// 是否已经被丢弃
	// 是否被禁用
	item = new(Item)
	if txn.update {
	    // 如果是更新事务, 先检查是否在缓存中, 如果在缓存中并且命中
		if e, has := txn.pendingWrites[string(key)]; has && bytes.Equal(key, e.Key) {
			if isDeletedOrExpired(e.meta, e.ExpiresAt) { // 如果缓存中的值已经过期/或者被删除, 直接返回错误
				return nil, ErrKeyNotFound
			}
			// 设置item的一些属性然后返回
			return item, nil
		}
		txn.addReadKey(key) // 将key添加到reads中, 用于冲突检测
	}
    // 构造查询key, 从数据库中查找这个 key 在 readTs 时间点的最新有效版本
    // 确保事务内的所有读取都基于同一个时间点的快照
	seek := y.KeyWithTs(key, txn.readTs)
	vs, err := txn.db.get(seek) // 从db中查找
	// 判断err, vs的一些状态
	
    // 构造item, 设置属性并返回
	
	return item, nil
}
```

### `txn.Set` / `txn.SetEntry`

> 调用关系: `Set(key, val []byte) -> SetEntry(e *Entry) -> modify(e *Entry)`

> [!INFO] 实现逻辑如下, 主要分为前置条件检查和缓冲区写入

```go
func (txn *Txn) modify(e *Entry) error {
	const maxKeySize = 65000

    // 一系列检测: 是否是更新事务, 是否被丢弃, key的长度为否为0, 是否大于maxKeySize, value的大小是否大于配置
	// txn.db.isBanned(e.Key), txn.checkSize(e)

	if txn.db.opt.DetectConflicts { // 如果开启冲突检测, 则记录下当前写入的key的指纹, 比较轻量
		fp := z.MemHash(e.Key) // Avoid dealing with byte arrays.
		txn.conflictKeys[fp] = struct{}{}
	}
	// 如果当前事务中已经存在了相同key的entry, 并且版本不同, 则将旧的entry添加到duplicateWrites中
	if oldEntry, ok := txn.pendingWrites[string(e.Key)]; ok && oldEntry.version != e.version {
		txn.duplicateWrites = append(txn.duplicateWrites, oldEntry)
	}
	txn.pendingWrites[string(e.Key)] = e // 将entry写入到pendingWrites中
	return nil
}

```
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

```go {title="Txn.Commit"}
func (txn *Txn) Commit() error {
	// 关闭冲突检测时, conflictKeys为空, 还要检测这个pendingWrites, 索性直接检测 pendingWrites 是否为空
	if len(txn.pendingWrites) == 0 {
		// pendingWrites 为空, 说明当前事务没有进行任何写操作, 可能是读事务或者没有操作, 直接释放资源就可以.
		txn.Discard()
		return nil
	}
	// 检查是否被丢弃, 或者在自动模式下是否正确设置了时间戳
	if err := txn.commitPrecheck(); err != nil {
		return err
	}
	defer txn.Discard()
   
	txnCb, err := txn.commitAndSend()
	if err != nil {
		return err
	}
	// If batchSet failed, LSM would not have been updated. So, no need to rollback anything.

	// TODO: What if some of the txns successfully make it to value log, but others fail.
	// Nothing gets updated to LSM, until a restart happens.
	return txnCb()
}
```

```go {title="Txn.commitAndSend"}
func (txn *Txn) commitAndSend() (func() error, error) {
	orc := txn.db.orc
	orc.writeChLock.Lock() // 加锁, 确保事务获取提交时间戳的顺序与被推送到写入通道中的顺序一样
	defer orc.writeChLock.Unlock()

	commitTs, conflict := orc.newCommitTs(txn)  // 检查之前看过的数据是否仍然有效
	if conflict {
		return nil, ErrConflict
	}

	keepTogether := true
	setVersion := func(e *Entry) {
		if e.version == 0 {
			e.version = commitTs
		} else {
			keepTogether = false
		}
	}
	// 给所有待写入的数据分配版本号
	for _, e := range txn.pendingWrites {
		setVersion(e)
	}
	// The duplicateWrites slice will be non-empty only if there are duplicate
	// entries with different versions.
	for _, e := range txn.duplicateWrites {
		setVersion(e)
	}

	entries := make([]*Entry, 0, len(txn.pendingWrites)+len(txn.duplicateWrites)+1)

	processEntry := func(e *Entry) {
		// Suffix the keys with commit ts, so the key versions are sorted in
		// descending order of commit timestamp.
		e.Key = y.KeyWithTs(e.Key, e.version)
		// Add bitTxn only if these entries are part of a transaction. We
		// support SetEntryAt(..) in managed mode which means a single
		// transaction can have entries with different timestamps. If entries
		// in a single transaction have different timestamps, we don't add the
		// transaction markers.
		if keepTogether {
			e.meta |= bitTxn
		}
		entries = append(entries, e)
	}

	// The following debug information is what led to determining the cause of
	// bank txn violation bug, and it took a whole bunch of effort to narrow it
	// down to here. So, keep this around for at least a couple of months.
	// var b strings.Builder
	// fmt.Fprintf(&b, "Read: %d. Commit: %d. reads: %v. writes: %v. Keys: ",
	// 	txn.readTs, commitTs, txn.reads, txn.conflictKeys)
	for _, e := range txn.pendingWrites {
		processEntry(e)
	}
	for _, e := range txn.duplicateWrites {
		processEntry(e)
	}

	if keepTogether {
		// CommitTs should not be zero if we're inserting transaction markers.
		y.AssertTrue(commitTs != 0)
		e := &Entry{
			Key:   y.KeyWithTs(txnKey, commitTs),
			Value: []byte(strconv.FormatUint(commitTs, 10)),
			meta:  bitFinTxn,
		}
		entries = append(entries, e)
	}
    // 从一个requestPool中获取一个请求, 将entries放入req中, 最后将req发送到通道 writeCh 中
	req, err := txn.db.sendToWriteCh(entries)   
	if err != nil {
		orc.doneCommit(commitTs)
		return nil, err
	}
	ret := func() error {
		err := req.Wait()
		// Wait before marking commitTs as done.
		// We can't defer doneCommit above, because it is being called from a
		// callback here.
		orc.doneCommit(commitTs)
		return err
	}
	return ret, nil
}
```

## `DB`

上面写了读写数据的API, 接下来分析如何从DB的结构以及如何从中读写数据.