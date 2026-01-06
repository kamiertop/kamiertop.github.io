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

### 宏规则集(MacroRules)描述

`MacroRules → MacroRule ( ; MacroRule )* ;?`

宏规则集中是一条或多条宏规则, 也就是多个模式的定义, 规则之间使用分号隔开, 最后一个规则的分号可以省略, 规则和规则不能一样


```rust {hl_lines=[2,3] wrapper=false lineNos=false}
macro_rules! macro_name1( // 圆括号
    () => {println!("rule1");};           // 第一个规则, 最后使用 ";" 结尾
    ($x: expr) => {println!("{}", $x);};  // 第二个规则, 最后使用 ";" 结尾, 也可以省略
    // ($x: expr) => {println!("{}", $x);}  // 可以省略最后的分号
);
```

### 宏规则(MacroRule)描述

`MacroRule → MacroMatcher => MacroTranscriber`

每条宏规则由三部分组成:
1. 宏匹配器: `MacroMatcher`
2. 箭头: `=>`
3. 宏转录器: `MacroTranscriber`

### 宏匹配器(MacroMatcher)描述

`MacroMatcher → ( MacroMatch* ) | [ MacroMatch* ] | { MacroMatch* }`

宏匹配器由**包裹符**包裹<u>0个或多个宏匹配单元</u>, 包裹符可以是圆括号、方括号或花括号, 任选其一

```rust
macro_rules! macro_name [
    () => {           // 圆括号, 无匹配单元
        println!();
    };
    [$x: expr] => {   // 方括号, 有一个匹配单元
        println!();
    };
    {$t: ty, $x: ident} => {     // 花括号, 有两个匹配单元
        println!();
    };
];
```

### 宏匹配单元(MacroMatch)描述

```text
MacroMatch →
      Token_except $ and delimiters 
    | MacroMatcher
    | $ ( IDENTIFIER_OR_KEYWORDexcept crate | RAW_IDENTIFIER | _ ) : MacroFragSpec
    | $ ( MacroMatch+ ) MacroRepSep? MacroRepOp
```

宏匹配单元可以由以下几种组成

- 普通token: 除了`$`和包裹符()、[]、{}外的所有[token](https://doc.rust-lang.org/stable/reference/tokens.html#r-lex.token.syntax)
- 宏匹配器: 嵌套的宏匹配器, 是`[],(),{}`包裹的0个或多个宏匹配单元
- 宏片段: `$ ( IDENTIFIER_OR_KEYWORD except crate | RAW_IDENTIFIER | _ ) : MacroFragSpec`
- 宏重复: `$ ( MacroMatch+ ) MacroRepSep? MacroRepOp`

#### 示例1: token匹配

```rust {src="由豆包生成" title="匹配Token"}
macro_rules! literal_token_match {
    // 匹配模式：由 字面量Token（"hello"） + 字面量Token（,） + 字面量Token（world） 组成
    ("hello", world) => {
        println!("匹配成功：字面量Token完全一致");
    };
    // 匹配模式：由 字面量Token（add） + 字面量Token（+） + 字面量Token（10） 组成
    (add + 10) => {
        println!("匹配成功：运算符Token也能匹配");
    };
}
fn main() {
    literal_token_match!("hello", world);
    // literal_token_match!("hello". world); // 编译报错, . ≠ , 
    literal_token_match!(add + 10);
    // 以下调用会编译报错（字面量不一致）
    // literal_token_match!("hi", world); // "hi" ≠ "hello"
    // literal_token_match!(add - 10);   // "-" ≠ "+"
}
```

#### 示例2: 嵌套

> [!NOTE] 下面的宏 `m1` 种的3个模式是一样的, 只是包裹符不同, 后面的有些例子看起来会比较绕, 我们尽量把包裹符给区分开

```rust {wrapper=false lineNos=false}
macro_rules! m1 {
    () => {};
    [] => {};
    {} => {};
}
```

```rust {title="必须匹配包裹符"}
macro_rules! m1 {
    () => {};      // 空匹配
    ([]) => {};    // 匹配空的方括号
    ([abc]) => {}; // 匹配包含标识符 abc 的方括号
}
macro_rules! m2 {
    [(abc)] => {}; // 匹配包含标识符 abc 的圆括号, ((abc))看起来有点晕, 所以使用[]包裹 (abc)
    ({def}) => {}; // 匹配包含标识符 def 的花括号
}
fn main() {
    m1!();
    m1!([]);    // 必须传递空的方括号, 不能是(),{}
    m1!([abc]); // 必须传递 [abc], 不能是 m1!((abc)) 或 m1!({abc})
    m2!((abc)); // 必须是 (abc), 不能是 m2!([abc]) 或 m2!({abc})
    m2!({ def }); // 必须是 {def}, 不能是 m2!([def]) 或 m2!((def))
}
```

<hr class="awesome-hr"/>

- `(pair [$a:expr, $b:expr])` 外层是圆括号()包裹
- 圆括号里面是多个**MacroMatch**
  - 第一个Match是普通的token `pair`
  - 第二个Match是方括号包裹的嵌套表达式 `[$a:expr, $b:expr]`
  - 嵌套表达式中也是多个MacroMatch
    - 第一个是 [元变量](#示例3-元变量捕获) 捕获 `$a:expr`
    - 第二个是 [元变量](#示例3-元变量捕获) 捕获 `$b:expr`

```rust {hl_lines=[3,4]}
macro_rules! nested_matcher {
    // 匹配模式：外层() 包裹 字面量Token（pair） + 嵌套MacroMatcher ([$a:expr, $b:expr])
    (pair [$a:expr, $b:expr]) => {
        println!("嵌套匹配1：{} 和 {} 配对", $a, $b);
    };
    // 匹配模式：外层() 包裹 嵌套MacroMatcher（{ $x:ident }） + 字面量Token（: end）
    ({ $x:ident } : end) => {
        println!("嵌套匹配2：花括号内的标识符是 {}", stringify!($x));
    };
}

fn main() {
    // 正确匹配：嵌套的 [10, 20] 符合 MacroMatcher 结构
    nested_matcher!(pair[10, 20]);
    // 正确匹配：嵌套的 {foo} 符合 MacroMatcher 结构
    nested_matcher!({ foo } : end);

    // 以下调用会编译报错（嵌套结构不一致）
    // nested_matcher!(pair (10, 20)); // 内层是 [] 而非 ()
    // nested_matcher!([foo] : end);   // 内层是 {$x:ident} 而非 [], 所以只能传递 {foo}, {ab}, {def} 这种的
}
```

#### 示例3: 元变量捕获

`$ ( IDENTIFIER_OR_KEYWORD_except crate | RAW_IDENTIFIER | _ ) : MacroFragSpec`

- `$` 符号开头
- 中间是标识符或者关键字(关键字不能是crate)或者原始字符串,或者是 `_`
- 后面是冒号 `:`
- 最后是片段类型 `MacroFragSpec`: `block | expr | expr_2021 | ident | item | lifetime | literal | meta | pat | pat_param | path | stmt | tt | ty | vis`

```rust {hl_lines=[3,13,21] wrapperClass="is-expanded is-collapsed"}
// m1!("abc"); m!("a literal");
macro_rules! m1 {
    ($a: literal) => {
        println!("{}", $a);
    };
}

//  let abc = 10;
//  m2!(abc);
//  m2!(10);
macro_rules! m2 {
    // 传递表达式, 比如 10, abc, 10 + 20 等, 要求是一个值
    ($a: expr) => {
        println!("{}", $a);
    };
}

// m3!(i32); m3!(u8);
macro_rules! m3 {
    // 捕获类型
    ($a: ty) => {
        println!("{}", stringify!($a));
    };
}
```

#### 示例4: 重复匹配

[重复运算符](https://doc.rust-lang.org/stable/reference/macros-by-example.html#r-macro.decl.repetition.operators)：`*`（零次或多次）、`+`（一次或多次）、`?`（零次或一次）

```rust {wrapperClass="is-expanded is-collapsed" hl_lines=[7,9,14,3]}
macro_rules! my_vec {
    // 使用 , 分割, 重复0次或多次
    [$($x: expr),*] => {
        {
            let mut temp_vec = Vec::new();
            // 使用$()* 遍历传入的多对儿表达式值
            $(
                temp_vec.push($x);
            )*
            temp_vec
        }
    };
    // 使用 ; 分割, 重复0次或多次
    [$($x: expr);*] => {
        {
            let mut temp_vec = Vec::new();
            $(
                temp_vec.push($x);
            )*
            temp_vec
        }
    };
}

fn main() {
    my_vec!(1, 2, 3, 4, 5); // 使用 , 分割的多个表达式值
    my_vec!(5; 4; 3; 2; 1); // 使用 ; 分割的多个表达式值
}
```

```rust
use std::collections::HashMap;

macro_rules! my_map {
    [
        // 第一个MacroMatch, 使用$()包裹
        $(
              // 这是一个MacroMatch, 由{}/[]/()包裹, 被包裹的部分是3个MacroMatch, 分别是
              // 1. $key: expr
              // 2. =>
              // 3. $value: expr
            {$key: expr => $value: expr}  
        )
        , // 重复分隔符, 多个键值对之间用逗号分割
        * // 对前面的每个匹配单元, 重复任意次 
        // 第二个MacroMatch, 可选地匹配一个逗号
        $(
          ,
        )
        ? // 重复0次或1次 , 用于处理最后一个键值对后面的逗号
    ]
    =>
    {
        {
            let mut map = std::collections::HashMap::new();
            $(
                map.insert($key, $value);
            )*
            map
        }
    };
}

fn main() {
    let _: HashMap<&str, i32> = my_map!(
        {"one" => 1},
        {"two" => 2},
        {"three"=>3},
    );
}

```

### 宏规则转录器(MacroTranscriber)

使用()/{}/[]包裹任意数量的TokenTree

- (TokenTree*)
- [TokenTree*]
- {TokenTree*}

```rust {title="任选其中一个包裹符"}
macro_rules! m {
    ([]) => [
        println!("[]");
    ];
    ({}) => {
        println!("{{}}")
    };
    {()} => {
        println!("()")
    }
}
```

`TokenTree → Token except delimiters | DelimTokenTree`

### 宏的作用域/导入导出

- 导出: 通过 `#[macro_export]` 导出宏
- 导入: 路径导入: `use crate::宏名字;`
- 优先级: 导出的宏优先级低于本地定义的宏

```rust
#[macro_export]
macro_rules! m {
    () => {
        println!("")
    };
}
```

## 过程宏