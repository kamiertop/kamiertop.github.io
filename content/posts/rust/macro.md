---
title: Rust宏
date: 2026-01-05T13:05:54+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
summary: "学习Rust宏"
toc: true
lastmod: 2026-01-05T13:05:54+08:00
math: true
lightgallery: false
categories:
  - Rust
---

> [!success]Rust中的宏非常强大, 是用来生成代码的代码, 本质是在编译器展开代码

## 分类

- 声明宏: `macro_rules!`
- 过程宏
  - 属性宏: `#[get("/users")]`
  - 函数宏: `query!("SELECT * FROM users")`
  - 派生宏: `#[derive(Debug)]`

## 声明宏

[语法](https://doc.rust-lang.org/stable/reference/macros-by-example.html#r-macro.decl.syntax): `macro_rules! 宏的名字 宏规则集合定义`

![img.png](/rust/macro_rules_syntax.png)

### 包裹宏规则的3种方式

```text {wrapper=false lineNos=false}
MacroRulesDef → ( MacroRules ) ; | [ MacroRules ] ; | { MacroRules }
```

1. 圆括号+分号结尾: `(宏规则集);`
2. 方括号+分号结尾: `[宏规则集];`
3. 花括号: `{宏规则集}`

使用代码演示更为直观

```rust {hl_lines=[1,5,7,11,13,17]}
macro_rules! macro_name1( // 圆括号
    () => {
        println!("macro_name1");
    };
); // 圆括号+分号结尾

macro_rules! macro_name2 { // 花括号
    () => {
        println!("macro_name2");
    };
} // 花括号结尾

macro_rules! macro_name3 [ // 方括号
    () => {
        println!("macro_name3");
    };
]; // 方括号+分号结尾

```

### 宏规则集

`MacroRules → MacroRule ( ; MacroRule )* ;?`

宏规则集中是一条或多条宏规则, 也就是多个模式的定义, 规则之间使用分号隔开, 最后一个规则的分号可以省略, 规则和规则不能一样


```rust {hl_lines=[2,3] wrapper=false lineNos=false}
macro_rules! macro_name1( // 圆括号
    () => {println!("rule1");};           // 第一个规则, 最后使用 ";" 结尾
    ($x: expr) => {println!("{}", $x);};  // 第二个规则, 最后使用 ";" 结尾, 也可以省略
    // ($x: expr) => {println!("{}", $x);}  // 可以省略最后的分号
);
```

### 宏规则

## 过程宏