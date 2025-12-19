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

## 显式创建 `Runtime`

### 创建异步任务后台运行，同时主线程执行同步逻辑

- 第7行显式创建一个多线程的异步运行时`Runtime`, 并开启时间功能(允许使用 `time` 模块). 
- 第10行通过`spawn`方法创建一个异步任务, 该任务会在后台运行. 值得注意的是这个任务只是立即交给异步运行时, 并不会阻塞主线程. 类似Golang的`go`关键字创建的一个goroutine.
- 第20行执行主线程任务，此时异步任务开始也在后台运行了
- 第27行通过`block_on`方法阻塞主线程, 等待异步任务完成. 类似于Golang的`WaitGroup`等待所有goroutine完成.
```Rust {hl_lines=[7,10,20,27] title="cargo add tokio --features rt-multi-thread,time"}
use std::error::Error;
use std::time::Duration;

use tokio::{runtime::Builder, time};

fn main() -> Result<(), Box<dyn Error>> {
    let rt = Builder::new_multi_thread().enable_time().build()?;

    // 后台异步任务
    let task = rt.spawn(async {
        for i in 1..=3 {
            println!("后台任务执行异步逻辑 - 第 {} 次", i);
            time::sleep(Duration::from_secs(1)).await;
        }
        println!("后台任务执行完成");
    });

    // 主线程：自由执行任意同步逻辑（比如处理用户输入、文件读写、循环业务）
    println!("main thread: 开始处理同步业务...");
    for i in 1..=5 {
        println!("main thread: 处理同步任务 - 第 {} 次", i);
        std::thread::sleep(Duration::from_millis(800)); // 每次阻塞 800ms
    }
    println!("main thread: 同步业务处理完成");

    // 等待异步任务结束
    rt.block_on(task)?;

    println!("main thread: 程序退出");
    Ok(())
}
```

使用 `cargo run` 运行能看到输出的信息中，是交替执行的

```text {data-open=false}
main thread: 开始处理同步业务...
main thread: 处理同步任务 - 第 1 次
后台任务执行异步逻辑 - 第 1 次
main thread: 处理同步任务 - 第 2 次
后台任务执行异步逻辑 - 第 2 次
main thread: 处理同步任务 - 第 3 次
后台任务执行异步逻辑 - 第 3 次
main thread: 处理同步任务 - 第 4 次
后台任务执行完成
main thread: 处理同步任务 - 第 5 次
main thread: 同步业务处理完成
main thread: 程序退出
```

### 创建多个异步任务，并且使用返回值

下面代码中创建了两个异步task（仅作学习使用，这种场景不一定合理），每个任务会把结果返回

```rust {hl_lines=[13,20,25,26] title="cargo add tokio --features rt-multi-thread"}
use std::error::Error;
use tokio::runtime::Builder;
use tokio::task::JoinHandle;

fn main() -> Result<(),Box<dyn Error>>{
    let rt = Builder::new_multi_thread().build()?;

    let task1:JoinHandle<i32> = rt.spawn(async {
       let mut sum = 0;
        for i in 1..=10000 {
            sum += i;
        }
        sum
    });
    let task2:JoinHandle<i32> = rt.spawn(async {
       let mut product = 1;
        for i in 1..=10 {
            product *= i;
        }
        product
    });

    rt.block_on(
        async {
            let result1: i32 = task1.await?;
            let result2: i32 = task2.await?;
            println!("Task 1 result (sum 1 to 10000): {}", result1);
            println!("Task 2 result (product 1 to 10): {}", result2);
            Ok::<(),Box<dyn Error>>(())
        }
    )?;

    Ok(())
}
```


### 单线程和多线程 Runtime

上面两个例子都是多线程的 Runtime, 运行效果都是意料之中的，如果熟悉Golang的话，会觉得非常舒服~. 下面演示多线程和单线程模式

- 左边是单线程的，多次运行后会发现总是先打印`task1`, 再打印`task2`
- 右边是多线程的，多次运行后会发现打印顺序是随机的
- 在Golang中执行通过设置`runtime.GOMAXPROCS()`也能看到类似的随机、固定顺序的结果🥰

{{< twocol >}}

```rust {title="new_current_thread" hl_lines=[6]}
use std::error::Error;
use tokio::runtime::Builder;
use tokio::task::JoinHandle;

fn main() -> Result<(),Box<dyn Error>>{
    let rt = Builder::new_current_thread().build()?;

    let task1:JoinHandle<i32> = rt.spawn(async {
        println!("task1");
        (1..=10).sum()
    });
    let task2:JoinHandle<i32> = rt.spawn(async {
        println!("task2");
        (1..=10).sum()
    });

    rt.block_on(
        async {
            let result1:i32 = task1.await?;
            let result2:i32 = task2.await?;
            println!("Task 1 result : {}", result1);
            println!("Task 2 result : {}", result2);
            Ok::<(),Box<dyn Error>>(())
        }
    )?;

    Ok(())
}
```

===

```rust {title="new_multi_thread" hl_lines=[6]}
use std::error::Error;
use tokio::runtime::Builder;
use tokio::task::JoinHandle;

fn main() -> Result<(),Box<dyn Error>>{
    let rt = Builder::new_multi_thread().build()?;

    let task1:JoinHandle<i32> = rt.spawn(async {
        println!("Task1");
        (1..=10).sum()
    });
    let task2:JoinHandle<i32> = rt.spawn(async {
        println!("Task2");
        (1..=10).sum()
    });

    rt.block_on(
        async {
            let result1:i32 = task1.await?;
            let result2:i32 = task2.await?;
            println!("Task 1 result : {}", result1);
            println!("Task 2 result : {}", result2);
            Ok::<(),Box<dyn Error>>(())
        }
    )?;

    Ok(())
}
```

{{< /twocol >}}