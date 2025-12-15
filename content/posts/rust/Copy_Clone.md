---
title: Rust的Copy和Clone
date: 2025-06-10T14:58:37+08:00
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

> [!NOTE] 简单记录下对Copy和Clone的理解

## 未实现`Clone`, 移动语义

下面的例子中, 第13行打印u时报错, 是因为u被移动到了`another_u`, u的值被释放了

```rust {hl_lines=[13] linenos=table}
#[derive(Debug)]
#[allow(unused)]
struct User {
    age: i32
}

fn main() {
    let u: User = User{
        age: 25
    };
    println!("{:?}",u);
    let another_u = u;
    println!("{:?}",u);
}

```

编译报错信息如下, 提示我们User没有实现`Copy`这个`trait`, 第13行借用了第12行中已经移动了的u
还提示可以实现 `Clone` trait

```shell {hl_lines=[5,8,10,12,16,19] linenos=table}
error[E0382]: borrow of moved value: `u`
  --> src\main.rs:13:21
   |
8  |     let u: User = User{
   |         - move occurs because `u` has type `User`, which does not implement the `Copy` trait
...
12 |     let another_u = u;
   |                     - value moved here
13 |     println!("{:?}",u);
   |                     ^ value borrowed here after move
   |
note: if `User` implemented `Clone`, you could clone the value
  --> src\main.rs:3:1
   |
3  | struct User {
   | ^^^^^^^^^^^ consider implementing `Clone` for this type
...
12 |     let another_u = u;
   |                     - you could clone this value
   = note: this error originates in the macro `$crate::format_args_nl` which comes from the expansion of the macro `println` (in Nightly builds, run with -Z macro-backtrace for more info)

```

## 实现 `Clone`

实现`Clone` trait之后, 可以显式调用`clone()`方法来进行深拷贝

> [!TIP]
> 如果所有字段都实现了`Clone`, 那么`#[derive(Clone)]`会自动实现`Clone` trait

```rust {hl_lines=[1,12,13] linenos=table}
#[derive(Debug,Clone)]
#[allow(unused)]
struct User {
    age: i32
}

fn main() {
    let u: User = User{
        age: 25
    };
    println!("{:?}",u);
    let another_u = u.clone();
    println!("{:?}",u);
    println!("{:?}",another_u);
}
```

## 实现 `Copy`, 按`bits`复制, 非移动语义

```rust {hl_lines=[1,12,13,14] linenos=table}
#[derive(Debug,Clone,Copy)]
#[allow(unused)]
struct User {
    age: i32
}

fn main() {
    let u: User = User{
        age: 25
    };
    println!("{:?}",u);
    let another_u = u;
    println!("{:?}",u);
    println!("{:?}",another_u);
}
```

编译成功, 正常执行

```text
User { age: 25 }
User { age: 25 }
User { age: 25 }
```

## 其他

Copy是按位做浅拷贝，那么它会默认拷贝的数据没有需要释放的资源；而Drop恰恰是为了释放额外的资源而生的
