---
title: BadgerDB系列1：如何使用 Badger DB
subtitle: ""
date: 2026-05-30T19:38:54+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-05-30T19:38:54+08:00
math: true
lightgallery: false
summary: "BadgerDB系列第一期：如何使用BadgerDB"
categories:
  - BadgerDB
  - db
---

[BadgerDB](https://github.com/dgraph-io/badger)是一个Go语言编写、支持事务的、可嵌入持久化的快速键值数据库。本系列用来学习BadgerDB的使用，以及BadgerDB的底层实现原理

## 安装

- 库：`go get github.com/dgraph-io/badger/v4`
- CLI工具：`go install github.com/dgraph-io/badger/v4/badger@latest`

## 打开或创建一个数据库

> BadgerDB会获取数据库的锁，确保只有一个进程可以访问数据库

### 持久化数据库

>[!warning] 使用持久化数据库时，`DefaultOptions` 中的路径必须是一个有效的目录，否则会panic

```go
package main

import (
	"log"

	"github.com/dgraph-io/badger/v4"
)

func main(){
    db, err := badger.Open(badger.DefaultOptions("/tmp/badger"))
    if err != nil {
        panic(err)
    }
    defer func() {
        if err = db.Close(); err != nil {
            log.Printf("close db error: %v", err)
        }
    }()
    // do something with db
}
```

使用 badger.Open 打开一个持久化数据库之后，只有一个进程/Goroutine 可以访问这个数据库，如果另一个进程/Goroutine 试图打开同一个数据库，就会报错，提示数据库被锁定了

```go {hl_lines=["21-30"] wrapperClass="is-collapsed"}
package main

import (
	"log"
	"sync"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(badger.DefaultOptions("badgerdb"))
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()
	var wg = &sync.WaitGroup{}
	wg.Go(func() {
		db1, err1 := badger.Open(badger.DefaultOptions("badgerdb"))
		if err1 != nil {
			log.Printf("open db twice error: %v", err1)
			return
		}
		if err := db1.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	})
	wg.Wait()
}

```

```text {hl_lines=[4] wrapperClass="is-collapsed"}
badger 2026/06/01 09:58:16 INFO: All 0 tables opened in 0s
badger 2026/06/01 09:58:16 INFO: Discard stats nextEmptySlot: 0
badger 2026/06/01 09:58:16 INFO: Set nextTxnTs to 0
2026/06/01 09:58:16 open db twice error: Cannot acquire directory lock on "badgerdb".  Another process is using this Badger database. err: resource temporarily unavailable
badger 2026/06/01 09:58:16 INFO: Lifetime L0 stalled for: 0s
badger 2026/06/01 09:58:16 INFO: 
Level 0 [ ]: NumTables: 00. Size: 0 B of 0 B. Score: 0.00->0.00 StaleData: 0 B Target FileSize: 64 MiB
Level 1 [ ]: NumTables: 00. Size: 0 B of 10 MiB. Score: 0.00->0.00 StaleData: 0 B Target FileSize: 2.0 MiB
Level 2 [ ]: NumTables: 00. Size: 0 B of 10 MiB. Score: 0.00->0.00 StaleData: 0 B Target FileSize: 2.0 MiB
Level 3 [ ]: NumTables: 00. Size: 0 B of 10 MiB. Score: 0.00->0.00 StaleData: 0 B Target FileSize: 2.0 MiB
Level 4 [ ]: NumTables: 00. Size: 0 B of 10 MiB. Score: 0.00->0.00 StaleData: 0 B Target FileSize: 2.0 MiB
Level 5 [ ]: NumTables: 00. Size: 0 B of 10 MiB. Score: 0.00->0.00 StaleData: 0 B Target FileSize: 2.0 MiB
Level 6 [B]: NumTables: 00. Size: 0 B of 10 MiB. Score: 0.00->0.00 StaleData: 0 B Target FileSize: 2.0 MiB
Level Done
```

### 内存数据库

>[!warning] 使用内存数据库时，`DefaultOptions` 中的路径必须为空，否则会报错

```go
package main

import (
	"log"

	"github.com/dgraph-io/badger/v4"
)

func main(){
    db, err := badger.Open(badger.DefaultOptions("").WithInMemory(true))
    if err != nil {
        panic(err)
    }
    defer func() {
        if err = db.Close(); err != nil {
            log.Printf("close db error: %v", err)
        }
    }()
    // do something with db
}

```

## 事务-自动

### 只读事务-读取数据

- key不存在时，`txn.Get` 会返回 `badger.ErrKeyNotFound` 错误
- 获取value时，通过 `item.Value` 方法或者 `item.ValueCopy` 方法获取
- 在View中进行更新、删除数据会报错

```go {hl_lines=["20-33"]}
package main

import (
	"errors"
	"log"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(badger.DefaultOptions("badgerdb").WithLoggingLevel(badger.ERROR))
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()
	err = db.View(func(txn *badger.Txn) error {
		item, err := txn.Get([]byte("key"))
		if err != nil {
			if errors.Is(err, badger.ErrKeyNotFound) {
				log.Printf("key not found")
				return nil
			}
			return err
		}
		return item.Value(func(val []byte) error {
			log.Printf("key: %s, value: %s", "key", string(val))
			return nil
		})
	})
	if err != nil {
		log.Printf("view error: %v", err)
	}
}

```

### 读写事务-写入/更新数据

- 在Update中事务是可读写的，通过 `txn.Set` 方法来写入/更新数据，当然也可以在读写事务中读取数据

- 删除数据通过 `txn.Delete` 方法来删除数据，如果key不存在，不会报错

```go
package main

import (
	"log"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(badger.DefaultOptions("badgerdb").WithLoggingLevel(badger.ERROR))
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()
	err = db.Update(func(txn *badger.Txn) error {
		return txn.Set([]byte("key"), []byte("value"))
	})
	if err != nil {
		log.Printf("set key error: %v", err)
	}

	err = db.Update(func(txn *badger.Txn) error {
		_, err = txn.Get([]byte("key"))
		return err
	})
	if err != nil {
		log.Printf("get key error: %v", err)
	}

	err = db.Update(func(txn *badger.Txn) error {
		return txn.Delete([]byte("key"))
	})
	if err != nil {
		log.Printf("delete key error: %v", err)
	}
}
```

>[!INFO] 以上都是自动提交事务的方式，BadgerDB当然也支持手动管理事务

## 事务-手动

> `db.Update` 和 `db.View` 方法都是自动提交事务的方式，简单方便，但有些时候需要手动控制

- NewTransaction+Commit手动同步提交
  - 数据量太大，需要分批次提交，即中途提交一部分，然后再开新的事务继续提交
  - 事务跨多个函数调用、需要中途判断是否放弃
  - ...
- NewTransaction+CommitWith手动异步提交
  - 并发写入多个独立 (key, value)，每个独立提交，流水线重叠
  - 高吞吐批量写入，不想串行等罗盘
  - ...
  
### 只读事务

```go
package main

import (
	"log"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(badger.DefaultOptions("badgerdb").WithLoggingLevel(badger.ERROR))
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()
	txn := db.NewTransaction(false)
	defer txn.Discard()
	_, err = txn.Get([]byte("key"))
	if err != nil {
		log.Printf("get error: %v", err)
	}
	if err = txn.Commit(); err != nil {
		log.Fatalf("commit error: %v", err)
	}
}
```

### 读写事务

读写事务需要设置 NewTransaction 的参数为 true，表示这是一个读写事务

#### 同步提交

```go
package main

import (
	"log"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(badger.DefaultOptions("badgerdb").WithLoggingLevel(badger.ERROR))
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()
	txn := db.NewTransaction(true)
	defer txn.Discard()
	err = txn.Set([]byte("key1"), []byte("value1"))
	if err != nil {
		log.Fatalf("set key error: %v", err)
	}
	if err = txn.Commit(); err != nil {
		log.Fatalf("commit error: %v", err)
	}
}

```

### 异步提交

```go
package main

import (
	"log"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(badger.DefaultOptions("badgerdb").WithLoggingLevel(badger.ERROR))
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()
	txn := db.NewTransaction(true)

	err = txn.SetEntry(badger.NewEntry([]byte("key1"), []byte("value2")))
	if err != nil {
		log.Printf("set entry error: %v", err)
	}
	txn.CommitWith(func(err error) {
		if err != nil {
			log.Printf("commit error: %v", err)
		} else {
			log.Printf("commit success")
		}
	})
}
```

## 遍历


## 设置键值对的过期时间


## 前缀扫描


## 流式操作
