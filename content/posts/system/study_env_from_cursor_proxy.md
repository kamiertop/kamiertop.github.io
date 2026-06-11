---
title: Cursor CLI HTTP Proxy 环境变量配置
date: 2026-06-11T17:09:25+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-06-11T17:09:25+08:00
math: true
lightgallery: false
summary: "在服务器中使用Cursor时正确配置环境变量以获得所有模型"
categories:
  - system
tags:
  - linux
  - env
---

> [!abstract] 大哥给了一个十来天的Cursor体验卡，本想在服务器中使用，直接修改论文源码，启动后发现模型数量和本地的不对

## 本地模型

> 已开启TUN模式

```bash
 agent --list-models
Available models

auto - Auto
gpt-5.3-codex-low - Codex 5.3 Low
gpt-5.3-codex-low-fast - Codex 5.3 Low Fast
gpt-5.3-codex - Codex 5.3
gpt-5.3-codex-fast - Codex 5.3 Fast
gpt-5.3-codex-high - Codex 5.3 High
gpt-5.3-codex-high-fast - Codex 5.3 High Fast
gpt-5.3-codex-xhigh - Codex 5.3 Extra High
gpt-5.3-codex-xhigh-fast - Codex 5.3 Extra High Fast
gpt-5.2 - GPT-5.2
gpt-5.2-codex-low - Codex 5.2 Low
gpt-5.2-codex-low-fast - Codex 5.2 Low Fast
gpt-5.2-codex - Codex 5.2
gpt-5.2-codex-fast - Codex 5.2 Fast
gpt-5.2-codex-high - Codex 5.2 High
gpt-5.2-codex-high-fast - Codex 5.2 High Fast
gpt-5.2-codex-xhigh - Codex 5.2 Extra High
gpt-5.2-codex-xhigh-fast - Codex 5.2 Extra High Fast
gpt-5.1-codex-max-low - Codex 5.1 Max Low
gpt-5.1-codex-max-low-fast - Codex 5.1 Max Low Fast
gpt-5.1-codex-max-medium - Codex 5.1 Max
gpt-5.1-codex-max-medium-fast - Codex 5.1 Max Medium Fast
gpt-5.1-codex-max-high - Codex 5.1 Max High
gpt-5.1-codex-max-high-fast - Codex 5.1 Max High Fast
gpt-5.1-codex-max-xhigh - Codex 5.1 Max Extra High
gpt-5.1-codex-max-xhigh-fast - Codex 5.1 Max Extra High Fast
composer-2.5 - Composer 2.5
claude-fable-5-thinking-high - Fable 5 1M Thinking (NO ZDR)
claude-fable-5-thinking-xhigh - Fable 5 1M Extra High Thinking (NO ZDR)
claude-opus-4-8-thinking-high - Opus 4.8 1M Thinking
claude-opus-4-8-thinking-high-fast - Opus 4.8 1M Thinking Fast
gpt-5.5-high - GPT-5.5 1M High
gpt-5.5-high-fast - GPT-5.5 High Fast
claude-opus-4-7-thinking-high - Opus 4.7 1M High Thinking
claude-opus-4-7-thinking-high-fast - Opus 4.7 1M High Thinking Fast
gpt-5.4-high - GPT-5.4 1M High
gpt-5.4-high-fast - GPT-5.4 High Fast
claude-4.6-opus-high-thinking - Opus 4.6 1M Thinking
composer-2.5-fast - Composer 2.5 Fast (default)
claude-fable-5-low - Fable 5 1M Low (NO ZDR)
claude-fable-5-medium - Fable 5 1M Medium (NO ZDR)
claude-fable-5-high - Fable 5 1M (NO ZDR)
claude-fable-5-xhigh - Fable 5 1M Extra High (NO ZDR)
claude-fable-5-max - Fable 5 1M Max (NO ZDR)
claude-fable-5-thinking-low - Fable 5 1M Low Thinking (NO ZDR)
claude-fable-5-thinking-medium - Fable 5 1M Medium Thinking (NO ZDR)
claude-fable-5-thinking-max - Fable 5 1M Max Thinking (NO ZDR)
claude-opus-4-8-low - Opus 4.8 1M Low
claude-opus-4-8-low-fast - Opus 4.8 1M Low Fast
claude-opus-4-8-medium - Opus 4.8 1M Medium
claude-opus-4-8-medium-fast - Opus 4.8 1M Medium Fast
claude-opus-4-8-high - Opus 4.8 1M
claude-opus-4-8-high-fast - Opus 4.8 1M Fast
claude-opus-4-8-xhigh - Opus 4.8 1M Extra High
claude-opus-4-8-xhigh-fast - Opus 4.8 1M Extra High Fast
claude-opus-4-8-max - Opus 4.8 1M Max
claude-opus-4-8-max-fast - Opus 4.8 1M Max Fast
claude-opus-4-8-thinking-low - Opus 4.8 1M Low Thinking
claude-opus-4-8-thinking-low-fast - Opus 4.8 1M Low Thinking Fast
claude-opus-4-8-thinking-medium - Opus 4.8 1M Medium Thinking
claude-opus-4-8-thinking-medium-fast - Opus 4.8 1M Medium Thinking Fast
claude-opus-4-8-thinking-xhigh - Opus 4.8 1M Extra High Thinking
claude-opus-4-8-thinking-xhigh-fast - Opus 4.8 1M Extra High Thinking Fast
claude-opus-4-8-thinking-max - Opus 4.8 1M Max Thinking
claude-opus-4-8-thinking-max-fast - Opus 4.8 1M Max Thinking Fast
gpt-5.5-none - GPT-5.5 1M None
gpt-5.5-none-fast - GPT-5.5 None Fast
gpt-5.5-low - GPT-5.5 1M Low
gpt-5.5-low-fast - GPT-5.5 Low Fast
gpt-5.5-medium - GPT-5.5 1M
gpt-5.5-medium-fast - GPT-5.5 Fast
gpt-5.5-extra-high - GPT-5.5 1M Extra High
gpt-5.5-extra-high-fast - GPT-5.5 Extra High Fast
claude-4.6-sonnet-medium - Sonnet 4.6 1M
claude-4.6-sonnet-medium-thinking - Sonnet 4.6 1M Thinking
claude-opus-4-7-low - Opus 4.7 1M Low
claude-opus-4-7-low-fast - Opus 4.7 1M Low Fast
claude-opus-4-7-medium - Opus 4.7 1M Medium
claude-opus-4-7-medium-fast - Opus 4.7 1M Medium Fast
claude-opus-4-7-high - Opus 4.7 1M High
claude-opus-4-7-high-fast - Opus 4.7 1M High Fast
claude-opus-4-7-xhigh - Opus 4.7 1M
claude-opus-4-7-xhigh-fast - Opus 4.7 1M Fast
claude-opus-4-7-max - Opus 4.7 1M Max
claude-opus-4-7-max-fast - Opus 4.7 1M Max Fast
claude-opus-4-7-thinking-low - Opus 4.7 1M Low Thinking
claude-opus-4-7-thinking-low-fast - Opus 4.7 1M Low Thinking Fast
claude-opus-4-7-thinking-medium - Opus 4.7 1M Medium Thinking
claude-opus-4-7-thinking-medium-fast - Opus 4.7 1M Medium Thinking Fast
claude-opus-4-7-thinking-xhigh - Opus 4.7 1M Thinking
claude-opus-4-7-thinking-xhigh-fast - Opus 4.7 1M Thinking Fast
claude-opus-4-7-thinking-max - Opus 4.7 1M Max Thinking
claude-opus-4-7-thinking-max-fast - Opus 4.7 1M Max Thinking Fast
grok-build-0.1 - Grok Build 0.1 1M
gpt-5.4-low - GPT-5.4 1M Low
gpt-5.4-medium - GPT-5.4 1M
gpt-5.4-medium-fast - GPT-5.4 Fast
gpt-5.4-xhigh - GPT-5.4 1M Extra High
gpt-5.4-xhigh-fast - GPT-5.4 Extra High Fast
claude-4.6-opus-high - Opus 4.6 1M
claude-4.6-opus-max - Opus 4.6 1M Max
claude-4.6-opus-high-thinking-fast - Opus 4.6 1M Thinking Fast
claude-4.6-opus-max-thinking - Opus 4.6 1M Max Thinking
claude-4.6-opus-max-thinking-fast - Opus 4.6 1M Max Thinking Fast
claude-4.5-opus-high - Opus 4.5
claude-4.5-opus-high-thinking - Opus 4.5 Thinking
gpt-5.2-low - GPT-5.2 Low
gpt-5.2-low-fast - GPT-5.2 Low Fast
gpt-5.2-fast - GPT-5.2 Fast
gpt-5.2-high - GPT-5.2 High
gpt-5.2-high-fast - GPT-5.2 High Fast
gpt-5.2-xhigh - GPT-5.2 Extra High
gpt-5.2-xhigh-fast - GPT-5.2 Extra High Fast
gemini-3.1-pro - Gemini 3.1 Pro
gpt-5.4-mini-none - GPT-5.4 Mini None
gpt-5.4-mini-low - GPT-5.4 Mini Low
gpt-5.4-mini-medium - GPT-5.4 Mini
gpt-5.4-mini-high - GPT-5.4 Mini High
gpt-5.4-mini-xhigh - GPT-5.4 Mini Extra High
gpt-5.4-nano-none - GPT-5.4 Nano None
gpt-5.4-nano-low - GPT-5.4 Nano Low
gpt-5.4-nano-medium - GPT-5.4 Nano
gpt-5.4-nano-high - GPT-5.4 Nano High
gpt-5.4-nano-xhigh - GPT-5.4 Nano Extra High
grok-4.3 - Grok 4.3 1M
claude-4.5-sonnet - Sonnet 4.5
claude-4.5-sonnet-thinking - Sonnet 4.5 Thinking
gpt-5.1-low - GPT-5.1 Low
gpt-5.1 - GPT-5.1
gpt-5.1-high - GPT-5.1 High
gemini-3-flash - Gemini 3 Flash
gemini-3.5-flash - Gemini 3.5 Flash
gpt-5.1-codex-mini-low - Codex 5.1 Mini Low
gpt-5.1-codex-mini - Codex 5.1 Mini
gpt-5.1-codex-mini-high - Codex 5.1 Mini High
claude-4-sonnet - Sonnet 4
claude-4-sonnet-thinking - Sonnet 4 Thinking
gpt-5-mini - GPT-5 Mini
kimi-k2.5 - Kimi K2.5

Tip: use --model <id> (or /model <id> in interactive mode) to switch.
```

## 服务器模型

```bash
❯ agent --list-models                                
Available models

auto - Auto
composer-2.5 - Composer 2.5
composer-2.5-fast - Composer 2.5 Fast (default)
grok-build-0.1 - Grok Build 0.1 1M
grok-4.3 - Grok 4.3 1M
kimi-k2.5 - Kimi K2.5

Tip: use --model <id> (or /model <id> in interactive mode) to switch.
```

发现好用的都不在列表中，怀疑是需要配置网络代理，于是设置了以下环境变量
```bash
export http_proxy=http://{ip}:{port}
export https_proxy=http://{ip}:{port}
```

- 设置完之后发现还是不行，请交了 composer-2.5 之后发现需要设置大写的环境变量，Cursor 不识别小写的环境变量
- 于是设置了大写的环境变量，成功解决，可以获得所有的模型了
- **问题在于Linux中环境变量的大小写敏感**

## Linux环境变量

> [!abstract] 既然到这里了，正好学习一下Linux环境变量相关的知识


### 环境变量是什么

> 环境变量本质上是：`key=value`

例如：
```bash
PATH=/usr/local/bin:/usr/bin:/bin
SHELL=/usr/bin/zsh
```

用来给程序提供运行时的配置信息，程序可以通过读取环境变量来获取这些信息，比如当前用户、家目录、默认shell等，每个进程都有自己的环境变量，子进程会继承父进程的环境变量。

### 查看环境变量

- 查看所有的环境变量：`env`, `printenv`

- 查看某一个环境变量
  - `echo $HOME`
  - `printenv HOME`
- 查看当前 shell 变量和环境变量：`set`（set命令查看当前shell的所有变量，包括普通shell变量和函数等）

### 普通变量 vs 环境变量

- 普通变量：只能在当前shell中使用，子进程无法访问, 定义如下：
```bash
VAR=value
echo $VAR # 输出value
bash
echo $VAR # 输出空，因为子进程无法访问父进程的普通变量
```
- 环境变量：可以被当前shell和子进程访问，使用`export`命令将普通变量转换为环境变量：
```bash
export VAR=value
echo $VAR # 输出value
bash
echo $VAR # 输出value，因为子进程可以访问父进程的环境变量
```
或者先定义普通变量再导出：
```bash
VAR=value
export VAR
```

### 临时环境变量

可以在命令前临时设置环境变量，这样这个环境变量只对当前命令有效，不会污染当前shell的环境变量：
```bash
VAR=value command
HTTP_PROXY=http://127.0.0.1:7890 curl https://example.com
```

### 删除环境变量

使用`unset`命令删除环境变量：
```bash
export VAR=value
echo $VAR # 输出value
unset VAR
echo $VAR # 输出空，因为环境变量已经被删除
```

### `PATH`环境变量

> PATH环境变量是一个特殊的环境变量，它告诉操作系统在执行命令时应该在哪些目录中查找可执行文件。PATH变量的值是一个由冒号分隔的目录列表，例如：
```bash
PATH=/usr/local/bin:/usr/bin:/bin
```

Linux用冒号分隔不同的目录，并且有顺序，操作系统会按照PATH中目录的顺序查找可执行文件，如果在第一个目录中找到了，就执行它，不会继续查找后面的目录。

查看一个命令的路径：`which command`，例如：
```bash
which zsh
```
临时给`PATH`添加一个目录：
```bash
export PATH=/my/custom/path:$PATH
```
一般推荐把自定义的目录放在PATH的前面，这样可以覆盖系统默认的命令，或者放在后面以避免覆盖系统命令

### 常见的环境变量

- `HOME`：当前用户的家目录
- `USER`：当前用户的用户名
- `SHELL`：当前用户的默认shell
- `PATH`：可执行文件的搜索路径
- `LANG`：系统的语言和区域设置
- `EDITOR`：默认的文本编辑器
- `PAGER`：默认的分页程序
- `HTTP_PROXY` / `HTTPS_PROXY`：HTTP/HTTPS代理设置
- `NO_PROXY`：不使用代理的地址列表
- `PWD`：当前工作目录
- `OLDPWD`：上一个工作目录
- `TERM`：终端类型

### 大小写敏感

> [!warning] Linux中的环境变量是大小写敏感的，`HTTP_PROXY`和`http_proxy`是两个不同的环境变量，有些程序可能只识别其中一个，有些会做特殊处理，例如`curl`会同时识别`HTTP_PROXY`和`http_proxy`，但有些程序可能只识别大写的环境变量，所以在设置环境变量时要注意大小写

### 为程序设置环境变量

有时候我们需要为某个程序设置特定的环境变量，可以在命令前临时设置，或者在shell配置文件中永久设置，例如：
```bash
# 临时设置环境变量
HTTP_PROXY=http://127.0.0.1:7897 curl https://example.com
# 永久设置环境变量，添加到~/.bashrc或~/.zshrc中
export HTTP_PROXY=http://127.0.0.1:7897
```

### 在程序中访问环境变量

```go
package main

import "os"

func main() {
	home := os.Getenv("HOME") // 获取环境变量HOME的值
	println("Home directory:", home)
	home = os.Getenv("home") // 获取环境变量HOME的值
	println("Home directory with lowercase:", home) // 输出空，因为环境变量是大小写敏感的
}

```

```rust
fn main() {
    match std::env::var("HOME") {
        Ok(value) => println!("HOME={}", value),
        Err(_) => eprintln!("HOME environment variable is not set"),
    }
    match std::env::var("home") {
        Ok(value) => println!("home={}", value),
        Err(_) => eprintln!("home environment variable is not set"),
    }
}
```

### 在程序中设置环境变量

- 在程序中设置环境变量会影响当前进程和之后启动的子进程

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
)
func main() {
	// 设置当前进程的环境变量
	os.Setenv("A", "B")
	// 当前 Go 进程可以读到
	fmt.Println("current process A =", os.Getenv("A"))
	// 之后启动的子进程默认会继承
	cmd := exec.Command("sh", "-c", "echo child process A=$A")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
	// 修改环境变量
	os.Setenv("A", "C")
	fmt.Println("after update A =", os.Getenv("A"))
	// 删除环境变量
	os.Unsetenv("A")
	fmt.Println("after unset A =", os.Getenv("A"))
}
```

- 父进程修改环境变量后，已经启动的子进程不会跟着改变

```go
package main

import (
	"os"
	"os/exec"
	"time"
)

func main() {
	os.Setenv("A", "before")
	cmd := exec.Command("sh", "-c", `
          echo "child start A=$A"
          sleep 2
          echo "child after sleep A=$A"
          `)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Start()
	time.Sleep(1 * time.Second)
	os.Setenv("A", "after")
	cmd.Wait()
}

```