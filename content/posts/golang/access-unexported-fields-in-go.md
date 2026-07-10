---
title: "Go语言中访问未导出字段的方法"
date: "2026-07-09T20:10:06+08:00"
draft: false
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
lastmod: "2026-07-09T20:10:06+08:00"
lightgallery: false
summary: "总结下在Go语言中访问未导出字段的方法"
categories:
  - Go
tags:
  - Go
---

> [!summary]有时候我们希望访问一个结构体的未导出字段，但由于Go语言的封装特性，直接访问是不允许的，需要一些技巧来实现，这里总结下几种方法。

## 文件准备

```bash
mkdir access-unexported-fields-in-go
cd access-unexported-fields-in-go
go mod init access-unexported-fields-in-go
mkdir model
touch model/model.go
touch main.go
```

```go {title="model/model.go"}
package model

type User struct {
	id   int
	vip  bool
	name string
}

func NewUser(id int, vip bool, name string) User {
	return User{
		id:   id,
		vip:  vip,
		name: name,
	}
}

```

## 访问未导出字段


### 方法1 为结构体定义方法

> [!summary]通过为结构体定义方法来访问未导出字段，不过这种方法需要在结构体所在的包中定义方法，但往往我们无法修改，要是自己定义的包那都随便改了

```go {title="model/model.go"}
func (u User) ID() int {
	return u.id
}

func (u User) IsVIP() bool {
	return u.vip
}

func (u User) Name() string {
	return u.name
}
```

### 方法2 Unsafe Cast

> [!summary] 通过构造相同的结构体布局来访问未导出字段，这种方法需要知道结构体的字段顺序和类型，且不保证在未来版本中仍然有效。

```go {title="main.go"}
package main

import (
	"access-unexported-fields-in-go/model"
	"fmt"
	"unsafe"
)

// 必须构造相同的结构体布局，名字可以不同，字段顺序和类型必须相同
type userLayout struct {
    id   int
    vip  bool
    name string
}

func main() {
	user := model.NewUser(1, true, "Alice")
	
	// 方法2: Unsafe Cast
	userPtr := (*userLayout)(unsafe.Pointer(&user))
	fmt.Println(userPtr.id)
	fmt.Println(userPtr.vip)
	fmt.Println(userPtr.name)
}
```

### 方法3 字段偏移量

> 本质上和方法2是一样的

```go {title="main.go"}
package main

import (
	"access-unexported-fields-in-go/model"
	"fmt"
	"unsafe"
)

type userLayout struct {
	id   int
	vip  bool
	name string
}

func main() {
	user := model.NewUser(1, true, "Alice")

	baseAddr := uintptr(unsafe.Pointer(&user))

	idOffset := unsafe.Offsetof(userLayout{}.id)
	vipOffset := unsafe.Offsetof(userLayout{}.vip)
	nameOffset := unsafe.Offsetof(userLayout{}.name)

	idAddr := baseAddr + idOffset
	vipAddr := baseAddr + vipOffset
	nameAddr := baseAddr + nameOffset

	id := *(*int)(unsafe.Pointer(idAddr))
	vip := *(*bool)(unsafe.Pointer(vipAddr))
	name := *(*string)(unsafe.Pointer(nameAddr))

	fmt.Printf("base address: %#x\n", baseAddr)
	fmt.Printf("id:   offset=%d address=%#x value=%d\n", idOffset, idAddr, id)
	fmt.Printf("vip:  offset=%d address=%#x value=%t\n", vipOffset, vipAddr, vip)
	fmt.Printf("name: offset=%d address=%#x value=%s\n", nameOffset, nameAddr, name)
}
```

### 方法4 反射

```go {title="main.go"}
package main

import (
	"access-unexported-fields-in-go/model"
	"fmt"
	"reflect"
	"unsafe"
)

func main() {
	user := model.NewUser(1, true, "Alice")

	userValue := reflect.ValueOf(&user).Elem()

	idField := userValue.FieldByName("id")
	vipField := userValue.FieldByName("vip")
	nameField := userValue.FieldByName("name")

	id := *(*int)(unsafe.Pointer(idField.UnsafeAddr()))
	vip := *(*bool)(unsafe.Pointer(vipField.UnsafeAddr()))
	name := *(*string)(unsafe.Pointer(nameField.UnsafeAddr()))

	fmt.Println("id:", id)
	fmt.Println("vip:", vip)
	fmt.Println("name:", name)
}
```

## 总结

构造相同结构体布局的方式是最常用的，也是最方便的，但需要注意的是，这种方法依赖于结构体的字段顺序和类型，如果结构体定义发生变化，可能会导致访问错误。