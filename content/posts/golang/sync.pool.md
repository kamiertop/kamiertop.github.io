---
title: Go sync.Pool 源码解读
date: '2026-07-07T13:08:41+08:00'
draft: false
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
collections: 
  - sync
lastmod: '2026-07-07T13:08:41+08:00'
lightgallery: false
summary: ""
categories:
  - Go
tags:
  - Go
---

## 使用方法

## 源码实现

### `Pool`

```go
type Pool struct {
	noCopy noCopy

	local     unsafe.Pointer // local fixed-size per-P pool, actual type is [P]poolLocal
	localSize uintptr        // size of the local array

	victim     unsafe.Pointer // local from previous cycle
	victimSize uintptr        // size of victims array

	// New optionally specifies a function to generate
	// a value when Get would otherwise return nil.
	// It may not be changed concurrently with calls to Get.
	New func() any
}
```