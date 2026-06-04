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

> [!warning] 使用持久化数据库时，`DefaultOptions` 中的路径必须是一个有效的目录，否则会panic

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

> [!warning] 使用内存数据库时，`DefaultOptions` 中的路径必须为空，否则会报错

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

> [!INFO] 以上都是自动提交事务的方式，BadgerDB当然也支持手动管理事务

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

### 默认参数

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
	err = db.View(func(txn *badger.Txn) error {
		opts := badger.DefaultIteratorOptions       // 新建一个默认的迭代器配置
		it := txn.NewIterator(opts)                 // 创建一个新的迭代器，传入配置
		defer it.Close()
		for it.Rewind(); it.Valid(); it.Next() {    // 从迭代器的起始位置开始迭代，直到迭代器无效
			item := it.Item()
			k := item.Key()
			v, err := item.ValueCopy(nil)
			if err != nil {
				return err
			}
			log.Printf("key: %s, value: %s", k, v)
		}

		return nil
	})
	if err != nil {
		log.Printf("view error: %v", err)
	}
}

```

### 自定义迭代器配置

> 下面是`DefaultIteratorOptions`定义，可以根据需要修改其中的参数来定制迭代器的行为

```go
var DefaultIteratorOptions = IteratorOptions{
	PrefetchValues: true,       // 是否预取值，默认为true
	PrefetchSize:   100,        // 预取的键值对数量，默认为100
	Reverse:        false,      // 是否反向迭代，默认为false
	AllVersions:    false,      // 是否返回所有版本的键值对，默认为false，即只返回最新版本
}
```

## 前缀扫描

> 使用 `Seek` 来寻找第一个符合条件的key

```go {hl_lines=[]}
package main

import (
	"fmt"
	"log"
	"strconv"

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
		for i := range 10 {
			err := txn.Set([]byte("prefix_key"+strconv.Itoa(i)), []byte(fmt.Sprint("value", i)))
			if err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		log.Fatalf("update error: %v", err)
	}
	err = db.View(func(txn *badger.Txn) error {
		opts := badger.DefaultIteratorOptions
		it := txn.NewIterator(opts)
		defer it.Close()
		prefixKey := []byte("prefix_key")
		for it.Seek(prefixKey); it.ValidForPrefix(prefixKey); it.Next() {
			item := it.Item()
			k := item.Key()
			v, err := item.ValueCopy(nil)
			if err != nil {
				return err
			}
			log.Printf("key: %s, value: %s", k, v)
		}

		return nil
	})
	if err != nil {
		log.Printf("view error: %v", err)
	}
}

```

> [!SUCCESS] 性能更好的方式：设置 `opts.Prefix` 来指定前缀，然后使用 `Valid` 来判断是否继续迭代

```go
db.View(func(txn *badger.Txn) error {
    opts := badger.DefaultIteratorOptions
		prefixKey := []byte("prefix_key")
		opts.Prefix = prefixKey
		it := txn.NewIterator(opts)

		defer it.Close()
		for it.Seek(prefixKey); it.Valid(); it.Next() {
			item := it.Item()
			k := item.Key()
			v, err := item.ValueCopy(nil)
			if err != nil {
				return err
			}
			log.Printf("key: %s, value: %s", k, v)
		}
})
```

### 前缀扫描倒序

> [!NOTE] 扫描机制：定位+过滤
>
> - 正向: 定位到前缀的第一个key，然后向后迭代过滤，直到遇到不匹配前缀的key为止
> - 反向: 定位到前缀的最后一个key，然后向前迭代过滤，直到遇到不匹配前缀的key为止

针对下面的例子，我们不能使用`it.Seek([]byte("prefix_key"))`，因为 `prefix_key` 的左边已经没有任何小于 `prefix_key` 的key了，所以我们需要定位到 `prefix_key` 的最后一个key，即 `prefix_key9`，然后向前迭代，直到遇到不匹配前缀的key为止

|      |  起点（Seek）锚点   | 还能不能扫（Valid）  |     何时停止      |
| :--: | :-----------------: | :------------------: | :---------------: |
| 正序 | k >= prefix（下界） | HasPrefix(k, prefix) | 第一个 !HasPrefix |
| 反序 |  k <= upper (上界)  | HasPrefix(k, prefix) | 第一个!HasPrefix  |

```go {hl_lines=[35,36,39,40]}
package main

import (
	"fmt"
	"log"
	"strconv"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(badger.DefaultOptions("").WithLoggingLevel(badger.ERROR).WithInMemory(true))
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()
	err = db.Update(func(txn *badger.Txn) error {
		for i := range 10 {
			err := txn.Set([]byte("prefix_key"+strconv.Itoa(i)), []byte(fmt.Sprint("value", i)))
			if err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		log.Fatalf("update error: %v", err)
	}
	err = db.View(func(txn *badger.Txn) error {
		opts := badger.DefaultIteratorOptions
		opts.Reverse = true
		opts.Prefix = []byte("prefix_key")
		it := txn.NewIterator(opts)
		defer it.Close()
		it.Seek([]byte("prefix_key9"))
		for ; it.Valid(); it.Next() {
			item := it.Item()
			k := item.Key()
			v, err := item.ValueCopy(nil)
			if err != nil {
				return err
			}
			log.Printf("key: %s, value: %s", k, v)
		}

		return nil
	})
	if err != nil {
		log.Printf("view error: %v", err)
	}
}

```

还有一种写法，不设置 `opts.Prefix`，而是在迭代过程中通过 `it.ValidForPrefix`

```go
db.View(func(txn *badger.Txn) error {
    opts := badger.DefaultIteratorOptions
		opts.Reverse = true
		//opts.Prefix = []byte("prefix_key")
		it := txn.NewIterator(opts)
		defer it.Close()
		it.Seek([]byte("prefix_key9"))
		for ; it.ValidForPrefix([]byte("prefix_key")); it.Next() {
			item := it.Item()
			k := item.Key()
			v, err := item.ValueCopy(nil)
			if err != nil {
				return err
			}
			log.Printf("key: %s, value: %s", k, v)
		}
})
```

## 只迭代key

> 性能比较好

```go
package main

import (
	"log"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(
		badger.DefaultOptions("badgerdb").
			WithLoggingLevel(badger.ERROR),
	)
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()

	err = db.View(func(txn *badger.Txn) error {
		opts := badger.DefaultIteratorOptions
		opts.PrefetchValues = false
		it := txn.NewIterator(opts)

		defer it.Close()
		for it.Rewind(); it.Valid(); it.Next() {
			item := it.Item()
			log.Printf("key: %s", item.Key())
		}

		return nil
	})
	if err != nil {
		log.Printf("view error: %v", err)
	}
}
```

## 设置键值对的过期时间

```go
package main

import (
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(
		badger.DefaultOptions("badgerdb").
			WithLoggingLevel(badger.ERROR),
	)
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()

	err = db.Update(func(txn *badger.Txn) error {
		entry := badger.NewEntry([]byte("key_ttl"), []byte("value")).WithTTL(time.Second * 3)
		return txn.SetEntry(entry)
	})
	err = db.View(func(txn *badger.Txn) error {
		_, err := txn.Get([]byte("key_ttl"))
		return err
	})
	fmt.Println(errors.Is(err, badger.ErrKeyNotFound)) // false

	time.Sleep(time.Second * 5)
	err = db.View(func(txn *badger.Txn) error {
		_, err = txn.Get([]byte("key_ttl"))
		return err
	})
	fmt.Println(errors.Is(err, badger.ErrKeyNotFound)) // true
}

```

## 流式操作

```go
package main

import (
	"context"
	"fmt"
	"log"

	"github.com/dgraph-io/badger/v4"
	"github.com/dgraph-io/badger/v4/pb"
	"github.com/dgraph-io/ristretto/v2/z"
)

func main() {
	db, err := badger.Open(
		badger.DefaultOptions("badgerdb").
			WithLoggingLevel(badger.ERROR),
	)
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()

	// 1. 先写入一批测试数据,其中一部分使用 "prefix_key" 前缀
	if err := seed(db); err != nil {
		log.Fatalf("seed error: %v", err)
	}

	// 2. 创建 Stream
	stream := db.NewStream()
	// 并发扫描的 goroutine 数,根据 CPU/磁盘情况调整
	stream.NumGo = 16
	// 只迭代该前缀下的 key;若为 nil 则全库扫描
	stream.Prefix = []byte("prefix_key")
	// 日志前缀,便于在多个 Stream 任务中区分日志输出
	stream.LogPrefix = "Stream: "

	// ChooseKey 在每个 key 第一次被遇到时调用(只看最新版本)
	// 返回 false 可以跳过该 key。并发调用,逻辑需保证线程安全。
	stream.ChooseKey = func(item *badger.Item) bool {
		// 这里示例:过滤掉所有被标记删除/过期的 key
		return !item.IsDeletedOrExpired()
	}

	// KeyToList 把 key 转换成要发送的 KVList。
	// 不设置时默认使用 stream.ToList(会取所有有效版本)。
	// 这里覆盖一下,仅取当前(最新)版本的 value。
	stream.KeyToList = func(key []byte, itr *badger.Iterator) (*pb.KVList, error) {
		item := itr.Item()
		val, err := item.ValueCopy(nil)
		if err != nil {
			return nil, err
		}
		kv := &pb.KV{
			Key:       append([]byte{}, key...),
			Value:     val,
			Version:   item.Version(),
			ExpiresAt: item.ExpiresAt(),
		}
		return &pb.KVList{Kv: []*pb.KV{kv}}, nil
	}

	// Send 是单 goroutine 调用,负责消费 stream 框架批量发出的数据。
	// buf 是 z.Buffer,内部包含序列化好的 pb.KV,使用 BufferToKVList 解析。
	var total int
	stream.Send = func(buf *z.Buffer) error {
		list, err := badger.BufferToKVList(buf)
		if err != nil {
			return err
		}
		for _, kv := range list.Kv {
			// StreamDone 标记可在开启 SendDoneMarkers 时收到,这里跳过即可
			if kv.StreamDone {
				continue
			}
			total++
			fmt.Printf("[stream] key=%s value=%s version=%d\n", kv.Key, kv.Value, kv.Version)
		}
		return nil
	}

	// 3. 启动 Stream,Orchestrate 会阻塞直到所有数据扫描发送完毕
	if err := stream.Orchestrate(context.Background()); err != nil {
		log.Fatalf("stream orchestrate error: %v", err)
	}
	fmt.Printf("done, total streamed kv: %d\n", total)
}

func seed(db *badger.DB) error {
	return db.Update(func(txn *badger.Txn) error {
		// 命中前缀的数据
		for i := 0; i < 5; i++ {
			k := fmt.Sprintf("prefix_key_%02d", i)
			v := fmt.Sprintf("value_%02d", i)
			if err := txn.Set([]byte(k), []byte(v)); err != nil {
				return err
			}
		}
		// 不命中前缀的数据,验证 Prefix 过滤是否生效
		for i := 0; i < 3; i++ {
			k := fmt.Sprintf("other_key_%02d", i)
			if err := txn.Set([]byte(k), []byte("ignored")); err != nil {
				return err
			}
		}
		return nil
	})
}
```

复制到新的BadgerDB中

```go
package main

import (
	"context"
	"fmt"
	"log"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(badger.DefaultOptions("").WithLoggingLevel(badger.ERROR).WithInMemory(true))
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()

	// 写入一些数据
	if err := seed(db); err != nil {
		log.Fatalf("seed error: %v", err)
	}
	newDB, err := badger.Open(
		badger.DefaultOptions("").
			WithLoggingLevel(badger.ERROR).
			WithInMemory(true),
	)
	if err != nil {
		log.Fatalf("open newdb error: %v", err)
	}
	defer func() {
		if err = newDB.Close(); err != nil {
			log.Printf("close newdb error: %v", err)
		}
	}()

	stream := db.NewStream()
	copyStream := newDB.NewStreamWriter()
	// StreamWriter 必须先 Prepare(会清空 newDB 已有数据);否则 Write 不会落表
	if err := copyStream.Prepare(); err != nil {
		log.Fatalf("stream writer prepare error: %v", err)
	}
	stream.Send = copyStream.Write

	// 3. 启动 Stream,Orchestrate 会阻塞直到所有数据扫描发送完毕
	if err := stream.Orchestrate(context.Background()); err != nil {
		log.Fatalf("stream orchestrate error: %v", err)
	}
	// 必须 Flush,内部会提交 SSTables 并 sync,否则下面 View 读不到数据
	if err := copyStream.Flush(); err != nil {
		log.Fatalf("stream writer flush error: %v", err)
	}
	err = newDB.View(func(txn *badger.Txn) error {
		it := txn.NewIterator(badger.DefaultIteratorOptions)
		defer it.Close()
		for it.Rewind(); it.Valid(); it.Next() {
			item := it.Item()
			k := item.Key()
			v, _ := item.ValueCopy(nil)
			fmt.Printf("key: %s, value: %s\n", k, v)
		}

		return nil
	})
	if err != nil {
		log.Fatalf("view newdb error: %v", err)
	}
}

func seed(db *badger.DB) error {
	return db.Update(func(txn *badger.Txn) error {
		for i := 0; i < 5; i++ {
			k := fmt.Sprintf("prefix_key_%02d", i)
			v := fmt.Sprintf("value_%02d", i)
			if err := txn.Set([]byte(k), []byte(v)); err != nil {
				return err
			}
		}
		for i := 0; i < 3; i++ {
			k := fmt.Sprintf("other_key_%02d", i)
			if err := txn.Set([]byte(k), []byte("ignored")); err != nil {
				return err
			}
		}
		return nil
	})
}

```

## 单调递增整数

```go
package main

import (
	"log"

	"github.com/dgraph-io/badger/v4"
)

func main() {
	db, err := badger.Open(badger.DefaultOptions("seq").WithLoggingLevel(badger.ERROR))
	if err != nil {
		panic(err)
	}
	defer func() {
		if err = db.Close(); err != nil {
			log.Printf("close db error: %v", err)
		}
	}()
	seq, err := db.GetSequence([]byte("id"), 1000)
	if err != nil {
		log.Printf("get sequence error: %v", err)
		return
	}
	defer func() {
		if err = seq.Release(); err != nil {
			log.Printf("release sequence error: %v", err)
		}
	}()
	for i := 0; i < 10; i++ {
		id, err := seq.Next()
		if err != nil {
			log.Printf("get next id error: %v", err)
			return
		}
		log.Printf("got id: %d", id)
	}
}

```

```text {title="第一次运行结果"}
2026/06/04 17:26:12 got id: 0
2026/06/04 17:26:12 got id: 1
2026/06/04 17:26:12 got id: 2
2026/06/04 17:26:12 got id: 3
2026/06/04 17:26:12 got id: 4
2026/06/04 17:26:12 got id: 5
2026/06/04 17:26:12 got id: 6
2026/06/04 17:26:12 got id: 7
2026/06/04 17:26:12 got id: 8
2026/06/04 17:26:12 got id: 9
```

```text{title="第二次运行结果"}
2026/06/04 17:26:13 got id: 10
2026/06/04 17:26:13 got id: 11
2026/06/04 17:26:13 got id: 12
2026/06/04 17:26:13 got id: 13
2026/06/04 17:26:13 got id: 14
2026/06/04 17:26:13 got id: 15
2026/06/04 17:26:13 got id: 16
2026/06/04 17:26:13 got id: 17
2026/06/04 17:26:13 got id: 18
2026/06/04 17:26:13 got id: 19
```
