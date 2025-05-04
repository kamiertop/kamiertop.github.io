---
title: go1.20及以后版本编译标准库为静态库文件
date: 2025-05-04T17:07:38+08:00
draft: false
summary: "Go1.20及以后的发行版不再包含预编译好的标准库文件, 因此需要在本地编译, 以方便查看汇编"
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description:
toc: true
math: false
lightgallery: false
---

<!--more-->

# Golang1.20及以后版本编译标准库为静态库文件

{{< admonition type=question title="问题发现" open=true >}}
- 在使用 `go tool compile -S main.go`查看汇编代码时, 提示 **main.go:3:8: could not import fmt (file not found)**
- 网络搜索, 发现[Go1.20](https://golang.google.cn/blog/go1.20)时为了缩小发行包, 不会将预编译的标准库静态文件放到下载Go时的归档文件中
- 标准库的包在需要时构建并缓存
  {{< /admonition >}}


{{< admonition type=success title="解决办法" open=true >}}
- `export GODEBUG=installgoroot=all && go install -v std`
- 会在 `$GOROOT/pkg/$GOOS_$GOARCH`下生成标准库各个库的.a文件
- 运行 `go tool compile -S main.go` 正常执行
  {{< /admonition >}}