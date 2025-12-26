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

## `tokio::time`

### 睡眠

> 对于没有VIP的客户我们让他们等一下🤣(不是), 此时可以使用`tokio::time::sleep()`

- 标准库的 `std::thread::sleep()` 会阻塞线程, 而 `tokio::time::sleep()` 则不会阻塞线程, 只会让出线程给其他任务
- 下面代码非常简单, 观察高亮行就能知道如何使用

```rust {hl_lines=[10]}
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::time::Duration;

#[tokio::main]
async fn main() {
    println!(
        "当前时间: {:?}",
        SystemTime::now().duration_since(UNIX_EPOCH)
    );
    tokio::time::sleep(Duration::from_secs(2)).await;
    println!(
        "等待结束，当前时间: {:?}",
        SystemTime::now().duration_since(UNIX_EPOCH)
    );
}
```

### 超时

> [!NOTE] 超时是指任务执行时间超过了指定的时间, 此时会返回一个错误
> - 相对时间: 从当前时间开始计算, 超过指定时间则超时
> - 绝对时间: 指定一个具体的时间点

#### 相对时间

```rust {hl_lines=[10]}
use tokio::time::{Duration, sleep, timeout};

async fn task() {
    // 模拟超时任务
    sleep(Duration::from_secs(3)).await;
}

#[tokio::main]
async fn main() {
    match timeout(Duration::from_secs(2), task()).await {
        Ok(_) => println!("Task completed within timeout"),
        Err(elapsed) => println!("Task timed out, {}", elapsed),
    };
}
```

#### 绝对时间

```rust {hl_lines=[7]}
use std::ops::Add;
use tokio::time::{Duration, Instant, timeout_at};

#[tokio::main]
async fn main() {
    let deadline: Instant = Instant::now().add(Duration::from_secs(2));
    match timeout_at(deadline, do_something()).await {
        Ok(_) => println!("任务完成"),
        Err(_) => println!("任务未在规定时间点之前完成"),
    }
}

async fn do_something() {
    tokio::time::sleep(Duration::from_secs(3)).await;
}

```


### 定时器

> [!TIP] 
> - 第一次 `tick()`是立即完成的, 这很方便, 如果我们不想立刻完成, 可以在循环之前调用一次 `tick()`
> - 定时器返回的 `Instant`总是理论时间, 不会因为任务执行时间而延迟

```rust
use tokio::time::{Duration, interval};

#[tokio::main]
async fn main() {
    let mut ticker = interval(Duration::from_secs(1));
    println!(
        "第一次会立即调用, tick()之前打印时间观察: {:?}",
        tokio::time::Instant::now()
    );
    for i in 0..5 {
        let instant = ticker.tick().await;

        println!("i: {}, instant: {:?}", i, instant);
    }
}

```

可以看到下面输出的第一行和第二行几乎是一样的, 正好印证第一次调用是立即完成的

```text {hl_lines=[1,2] wrapper=false}
第一次会立即调用, tick()之前打印时间观察: Instant { t: 17574.0125039s }
i: 0, instant: Instant { t: 17574.0124982s }
i: 1, instant: Instant { t: 17575.0124982s }
i: 2, instant: Instant { t: 17576.0124982s }
i: 3, instant: Instant { t: 17577.0124982s }
i: 4, instant: Instant { t: 17578.0124982s }
```

## `tokio::sync`

> [!NOTE] 同步原语
> `tokio::sync`为异步任务提供了很多同步原语, 熟悉Golang的可能会觉得很亲切 ![](/golang/walk.gif)
> 