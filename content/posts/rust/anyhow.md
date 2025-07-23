---
title: Rust的anyhow
date: 2025-07-23T15:31:01+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
math: false
lightgallery: false
summary: ""
categories:
  - Rust
# See details front matter: https://fixit.lruihao.cn/documentation/content-management/introduction/#front-matter
---

<!--more-->

在Rust中使用`anyhow`可以很方便得去处理错误, `anyhow`会自动将错误信息封装成`anyhow::Error`中, 这里记录下为什么使用, 如何使用

## Go中如何处理

`Go`中的错误处理是通过函数多返回值+实现`error`接口来实现的, 无论具体的错误是什么, 只要实现了`error`接口, 都可以作为返回值
```golang {hl_lines=[11] linenos=table}
package main

import (
	"io"
	"os"
)

func readFile(filepath string) ([]byte, error) {
	file, err := os.Open(filepath)
	if err != nil {
		return nil, err
	}

	return io.ReadAll(file)
}

```

## Rust中如何处理

### 不使用`anyhow`

```rust
use std::fs;
use std::io;

fn read_file(filepath: &str) -> io::Result<String> {
    fs::read_to_string(filepath)
}

fn main() -> io::Result<()> {
    let content = read_file("example.txt")?;
    println!("File content:\n{}", content);
    Ok(())
}
```
上面代码非常简单, 如果文件不存在就会报下面的错误, 提示找不到文件, 但是我们却无法知道具体是哪个文件
```text
Error: Os { code: 2, kind: NotFound, message: "系统找不到指定的文件。" }
```

### 使用`anyhow`
> 代码中的返回值我明确了是`anyhow::Result<T>`
```rust {hl_lines=[5] linenos=table}
use anyhow::Context;
use std::fs;

fn read_file(filepath: &str) -> anyhow::Result<String> {
    fs::read_to_string(filepath)
        .with_context(|| format!("Failed to read file: {}", filepath))
}

fn main() -> anyhow::Result<()> {
    let content = read_file("example.txt")?;
    println!("{}", content);
    Ok(())
}
```
使用`anyhow`之后, 我们可以附加一些信息到错误中(上面代码高亮部分), 此时错误信息如下

```text
Error: Failed to read file: example.txt

Caused by:
    系统找不到指定的文件。 (os error 2)

```

## 使用`anyhow`进行错误传播

### 如果不使用`anyhow`
> [!note] 
> Rust的标准库中`?`运算符只能自动传播跟返回类型相同的错误, 例如: 
```rust
fn foo() -> Result<(), std::io::Error> {
    let _ = "123".parse::<u32>()?; // ❌ 这里是 ParseIntError，不兼容
    Ok(())
}
```
如果我们的逻辑中有多个不同类型的错误, 就无法使用`?`运算符进行错误传播了, 此时可以使用`Box<dyn std::error::Error>`

```rust
fn parse_config(path: &str) -> Result<u16, Box<dyn std::error::Error>> {
    let content = std::fs::read_to_string(path)?;
    let port: u16 = content.trim().parse()?;
    Ok(port)
}
```

或者我们也可以使用enum定义我们自己的错误类型, 然后实现`std::error::Error` trait, 下面代码build没有问题, 但是写起来有点麻烦
```rust
use std::fs;
use std::io;
use std::num::ParseIntError;

#[derive(Debug)]
enum MyError {
    Io(io::Error),
    Parse(ParseIntError),
}

impl std::fmt::Display for MyError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            MyError::Io(e) => write!(f, "I/O error: {}", e),
            MyError::Parse(e) => write!(f, "Parse error: {}", e),
        }
    }
}


impl From<io::Error> for MyError {
    fn from(err: io::Error) -> MyError {
        MyError::Io(err)
    }
}

impl From<ParseIntError> for MyError {
    fn from(err: ParseIntError) -> MyError {
        MyError::Parse(err)
    }
}

#[allow(unused)]
fn load_port(path: &str) -> Result<u16, MyError> {
    let content = fs::read_to_string(path)?; // 自动转换成 MyError::Io
    let port: u16 = content.trim().parse()?; // 自动转换成 MyError::Parse
    Ok(port)
}

```


### 使用`anyhow`
使用`anyhow`之后代码会变得非常简洁
```rust
fn load_port(path: &str) -> anyhow::Result<u16> {
    let content = fs::read_to_string(path)?;
    let port = content.trim().parse::<u16>()?;
    Ok(port)
}
```
我们还可以附加一些信息
```rust
use anyhow::Context;
fn load_port(path: &str) -> anyhow::Result<u16> {
    let content = fs::read_to_string(path)
        .with_context(|| format!("failed to read file: {}", path))?;
    let port = content.trim().parse::<u16>()
        .context("failed to parse port number")?;
    Ok(port)
}
```

### 使用`anyhow!`
`anyhow!`是一个宏, 可以构建一个错误消息, 可以使用`{}`来格式化错误消息

```rust
fn main() -> anyhow::Result<()> {
    Err(anyhow::anyhow!("Test anyhow! with format args: {}", "use anyhow!"))
}
```
```text
Error: Test anyhow! with format args: use anyhow!
```