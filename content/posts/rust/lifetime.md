---
title: Rust 生命周期小记
subtitle: ""
date: 2025-12-21T20:13:06+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
toc: true
lastmod: 2025-12-21T20:13:06+08:00
math: true
lightgallery: false
summary: "学习Rust的 Tokio 时正好遇到一个生命周期问题, 简单记录一下"
categories:
  - Rust
---

```rust
use std::thread;

fn main() {
    let name: Option<&str> = thread::current().name();
    if let Some(name) = name {
        println!("Current thread name: {}", name);
    } else {
        println!("Current thread is unnamed");
    }
}

```

上面代码看起来很简单, 获取当前线程的名字, 但结果并不理想

Rust的编译器非常强, 告诉我们 `thread::current()` 是一个临时变量, 在这个语句结束时会释放

不过 `.name()`方法返回的是一个 `Option<&str>`, 返回临时变量的引用会导致**悬垂引用**, 生命周期超过那个临时变量的生命周期.
Rust可没有Golang中的逃逸分析, 不会自动将引用的生命周期延长

```text {hl_lines=[4,12,13]}
 --> src\bin\lifetime.rs:4:16
  |
4 |     let name = thread::current().name();
  |                ^^^^^^^^^^^^^^^^^       - temporary value is freed at the end of this statement
  |                |
  |                creates a temporary value which is freed while still in use
5 |     if let Some(name) = name {
  |                         ---- borrow later used here
  |
help: consider using a `let` binding to create a longer lived value
  |
4 ~     let binding = thread::current();
5 ~     let name = binding.name();
  |

For more information about this error, try `rustc --explain E0716`.  
```

修复起来很简单, 编译器也告诉了我们如何做, 我哭死😭

```rust {hl_lines=[4,5]}
use std::thread;

fn main() {
    let current_thread = thread::current();
    let name: Option<&str> = current_thread.name();
    if let Some(name) = name {
        println!("Current thread name: {}", name);
    } else {
        println!("Current thread is unnamed");
    }
}

```