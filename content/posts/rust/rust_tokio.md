---
title: Rust异步运行时Tokio
subtitle: ""
date: 2025-12-10T21:05:45+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: "逐步学习一下Rust的异步运行时Tokio"
toc: true
lastmod: 2025-12-10T21:05:45+08:00
math: true
lightgallery: false
summary: "学习Rust异步运行时Tokio，把所有功能都跑一下"
categories:
  - Rust
---

<img src="/rust/rust_go.jpg" alt="rust-go"/>

- 在Golang中使用并发非常简单, 通过 `go`关键字即可调用一个函数交由GMP模型调度管理.
- 在Rust中实现并发的模式有很多种, 这里学一下`Tokio`, `Tokio`已经是Rust异步运行时的事实标准了
- Golang有内置的Runtime，而Rust的Tokio则是一个异步运行时库，可以显式创建或通过宏来使用

## 创建运行时

### 显式创建运行时

```rust {title="cargo add tokio --features rt-multi-thread" hl_lines=[4]}
use tokio::runtime::Builder;

fn main() -> Result<(), std::io::Error> {
    let rt = Builder::new_multi_thread().enable_time().build()?;
    let _ = rt;
    Ok(())
}
```

> [!TIP] 上面是一个多线程的, 下面演示一个单线程运行时(类似Golang中的`runtime.GOMAXPROCS(1)`)

```rust {title="cargo add tokio" hl_lines=[4]}
use tokio::runtime::Builder;

fn main() -> Result<(), std::io::Error> {
    let rt = Builder::new_current_thread().build()?;
    let _ = rt;
    Ok(())
}

```

### 使用宏

> [!NOTE] 推荐使用宏

#### 单线程版本

`cargo add tokio --features macros rt `

```rust
#[tokio::main(flavor = "current_thread")]
async fn main() {}
```

#### 多线程版本

> [!TIP] 默认是多线程版本, 如果不使用`full`, 需要手动添加: `rt-multi-thread`

`cargo add tokio --features macros rt-multi-thread`

```rust
#[tokio::main(flavor = "multi_thread")]
async fn main() {}
```

等价于

```rust
#[tokio::main]
async fn main() {}
```

#### 使用 `expand` 展开宏来看一下

```rust {hl_lines=["3-8"]}
#[tokio::main(flavor = "multi_thread")]
async fn main() {
    tokio::spawn(async {
        for i in 1..=5 {
            let _ = i;
            tokio::time::sleep(std::time::Duration::from_secs(1)).await;
        }
    });
}
```

- 安装expand工具: `cargo install cargo-expand`
- 展开代码: `cargo expand xxx`

> [!SUCCESS] 展开后的代码如下
> 可以看到上面代码3-8行被放到了下面的`body`变量中, 然后`body`被第26行的`block_on`阻塞等待

```rust {data-open=false hl_lines=["8-13"]}
#![feature(prelude_import)]
#[macro_use]
extern crate std;
#[prelude_import]
use std::prelude::rust_2024::*;
fn main() {
    let body = async {
        tokio::spawn(async {
            for i in 1..=5 {
                let _ = i;
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
            }
        });
    };
    #[allow(
        clippy::expect_used,
        clippy::diverging_sub_expression,
        clippy::needless_return,
        clippy::unwrap_in_result
    )]
    {
        return tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("Failed building the Runtime")
            .block_on(body);
    }
}
```