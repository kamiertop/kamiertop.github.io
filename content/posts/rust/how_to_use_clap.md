---
title: Rust命令行参数解析库clap快速上手
date: 2025-05-16T23:20:45+08:00
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
summary: "clap是rust的一个功能强大的命令行参数解析库"
lastmod: 2025-09-20
categories:
  - Rust
---

<!--more-->

> [!NOTE] clap
> 最近在学习Rust, 有用到命令行参数解析库[clap](https://docs.rs/clap/latest/clap/), 在此记录一下

对于简单的参数完全可以手动处理无需引入额外的依赖, 但当命令和参数比较多的时候可以就可以使用第三方库来简化开发

# clap
- clap提供两种模式, builder模式和derive模式, 具体使用哪种方式全凭个人喜好
  - derive模式通过宏自动生成代码, 将参数映射到struct或者enum中, 结构清晰, 但需要查阅文档记一下参数
  - builder模式支持动态参数, 运行时配置和一些复杂的校验逻辑, 可以按需构建解析器, 但需要手动维护参数和子命令的层次结构
- clap会自动生成帮助文档
## derive模式
- 安装:  `cargo add clap --features derive`

### 位置参数
> x <属性值1> <属性值2>

```rust {hl_lines=[3] linenos=table}
use clap::Parser;

#[derive(Parser)]  // 必须添加Parser派生宏
struct Study {
	// 这里没有任何自定义属性宏, 使用时就是位置参数
    a: u8,
    b: u8,
}

fn main() {
    let cli = Study::parse();

    println!("a: {:?}", cli.a);
    println!("b: {:?}", cli.b);
}
// cargo run -- --help
// cargo run -- 3 4
// cargo run -- 100 1
```

### 命名参数
```rust {hl_lines=[3,5,7] linenos=table}
use clap::Parser;

#[derive(Parser)] //必须写
struct Study {
    #[arg(short)]	//short表示使用单横杠方式(默认是首字母): -n <name值> 或者 -n=<name值>
    // #[arg(short='N')] short默认取首字母, 可能会和其他的冲突, 所以可以手动指定一个字母, 注意这里是一个单引号的字符	
    #[arg(long)]    //short表示使用双横杠方式: --name <name值> 或者 --name=<name值>
    name: String,
}

fn main() {
    let cli = Study::parse();

    println!("name: {:?}", cli.name);
}
// cargo run -- --help
// cargo run -- -n jack
// cargo run -- --name=jack
```

### 属性

- `version`
- `default_value`
- `name`
```rust {hl_lines=[6] linenos=table}
use clap::Parser;

#[command(name="cli")] // 输出version的时候一并输出
#[derive(Parser)] //必须写
#[command(version="0.1.0",about="intro attribute")]	// 指定version和about
struct Study {
    #[arg(default_value="default_name")]			// 指定name字段的默认值
    name: String,
}

fn main() {
    let cli = Study::parse();
    println!("{}",cli.name);
}
// cargo run -- --help
// 下面是默认的help
introduce attribute

Usage: demo.exe [NAME]

Arguments:
  [NAME]  [default: default_name]

Options:
  -h, --help     Print help
  -V, --version  Print version

```

- `next_line_help` : 默认false
```rust {hl_lines=[5] linenos=table}
use clap::Parser;

#[derive(Parser)]
#[command(version="0.1.0",about="introduce attribute")]
#[command(next_line_help = true)]
struct Study {
    #[arg(long)]
    name: String,
}

fn main() {
    let cli = Study::parse();
    println!("{}",cli.name);
}
// cargo run -- --help
// demo --help
// 观察下方输出, 'Print help'和'Print version'换行输出显示的
// 上面的例子中是没有换行显示输出的
introduce attribute

Usage: demo.exe --name <NAME>

Options:
      --name <NAME>

  -h, --help
          Print help
  -V, --version
          Print version
 
```

- `help`
  - arg指定
  - 文档注释(三斜杠)
```rust {hl_lines=[6,19] linenos=table}
use clap::Parser;

#[derive(Parser)] //必须写
struct Study {
    #[arg(long)]
    #[arg(help = "help about name")]
    name: String,
}

fn main() {
    let cli = Study::parse();
    println!("{}",cli.name);
}
// cargo run -- --help
// demo --help
Usage: demo.exe --name <NAME>

Options:
      --name <NAME>  help about name
  -h, --help         Print help

```

```rust {hl_lines=[6,19] linenos=table}
use clap::Parser;

#[derive(Parser)]
struct Study {
    #[arg(long)]
    /// help about name by doc
    name: String,
}

fn main() {
    let cli = Study::parse();
    println!("{}",cli.name);
}
// cargo run -- --help
// demo --help
Usage: demo.exe --name <NAME>

Options:
      --name <NAME>  help about name by doc
  -h, --help         Print help
```

- `value_name` : 提示输出的值的名字
```rust {hl_lines=[8,19,22] linenos=table}
use clap::Parser;

#[derive(Parser)]
struct Study {
    #[arg(long)]
    #[arg(
        help = "help about name",
        value_name = "名字"
    )]
    name: String,
}

fn main() {
    let cli = Study::parse();
    println!("{}",cli.name);
} 
// cargo run -- --help
// demo --help
Usage: demo.exe --name <名字>

Options:
      --name <名字>  help about name
  -h, --help       Print help

```

- 可选参数: 使用option包裹

```rust {hl_lines=[6,19,22] linenos=table}
use clap::Parser;

#[derive(Parser)]
struct Study {
    #[arg(long)]
    name: Option<String>,
}

fn main() {
    let cli = Study::parse();
    println!("{:?}",cli.name);
} 
// cargo run -- --help
// demo --help
// 可以看到name是可选参数
Usage: demo.exe [OPTIONS]

Options:
      --name <NAME>
  -h, --help         Print help
```

### 子命令

在clap中声明子命令可以使用以下方式
```rust {hl_lines=[6,10] linenos=table}
use clap::Subcommand;
use clap::Parser;

#[derive(Parser, Debug)]
struct Cli {
    #[command(subcommand)]	//表示command是一个子命令, 类型是一个enum类型
    command: Command,
}

#[derive(Subcommand, Debug)]
enum Command {
    /// Get request
    Get {
        #[arg(help = "URL to fetch")]
        #[arg(long)]
        url: String,
    },
}

fn main() {
    let _ = Cli::parse();
}
// 默认不显示子命令的参数信息
// cargo run -- --help
// cargo run -- help
// demo --help
// demo help
Usage: demo.exe <COMMAND>

Commands:
  get   Get request
  help  Print this message or the help of the given subcommand(s)

Options:
  -h, --help  Print help
  
// 查看子命令的帮助信息
// cargo run -- help get
// demo help get
Get request

Usage: demo.exe get --url <URL>

Options:
      --url <URL>  URL to fetch
  -h, --help       Print help

```


### 枚举
> 下面代码第13行中可以为One添加别名alias, 或者指定name(这里为了演示, 就使用了abc, 从命令行输入时也要使用abc哦)

```rust {hl_lines=[6,11,13] linenos=table data-open=true}
use clap::Parser;

#[derive(Parser)]
struct Study {
    #[arg(long, short)]
    #[arg(value_enum)]
    length: Len,
}

#[derive(Debug, Clone)]
#[derive(clap::ValueEnum)]
enum Len {
    #[value(name = "abc", alias = "o", help = "1")]
    One,
    Two,
}

fn main() {
    let cli = Study::parse();
    println!("{:?}", cli.length);
}

```
```text {hl_lines=[6] linenos=table}
Usage: study-clap.exe --length <LENGTH>

Options:
  -l, --length <LENGTH>
          Possible values:
          - abc: 1
          - two

  -h, --help
          Print help (see a summary with '-h')
```

```text
cargo run -- --length=o  
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.06s
     Running `target\debug\study-clap.exe --length=o`
One
```
```text
cargo run -- --length=abc
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.02s
     Running `target\debug\study-clap.exe --length=abc`
One
```
> [!tip] 
> 枚举值解析时默认使用字段名字的小写形式, 比如下面的two, 如果是TwoLine, 那么解析时就是"two-line"

```text
cargo run -- --length=two
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.02s
     Running `target\debug\study-clap.exe --length=two`
Two
```