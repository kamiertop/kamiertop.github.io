---
title: Go标准库 database/sql 源码解读
date: 2025-12-02T15:55:15+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: "无聊时读读源码写写博客"
featuredImagePreview: /golang/database-sql-coverview.png
featuredImage: /golang/database-sql-coverview.png
toc: true
lastmod: 2025-12-02T15:55:15+08:00
math: false
lightgallery: false
summary: "阅读下标准库：database/sql 源码"
categories:
  - Go
# See details front matter: https://fixit.lruihao.cn/documentation/content-management/introduction/#front-matter
# 图标支持：https://fixit.lruihao.cn/zh-cn/documentation/content-management/diagrams-support/mermaid/
---

> [!NOTE] 实在看不下去论文了，于是读一下 `database/sql` 源码

> [!SUCCESS] `go version: go1.26` （1.26有些改动所以直接阅读1.26了）

`databa/sql` 包提供了一个围绕SQL数据库的通用接口，必须与数据库驱动配合使用才行，官方wiki列举了很多[驱动库](https://go.dev/wiki/SQLDrivers)，我常用的主要是[PostgreSQL](https://github.com/jackc/pgx)和[MySQL](https://github.com/go-sql-driver/mysql/)，其它的自行查阅即可

标准库 `database/sql` 中内容不多，忽略测试文件，只有下面这些

```bash
➜  go tree -I "*_test.go" src/database
src/database
└── sql
    ├── convert.go
    ├── ctxutil.go
    ├── doc.txt
    ├── driver
    │   ├── driver.go
    │   └── types.go
    └── sql.go

2 directories, 6 files
```
