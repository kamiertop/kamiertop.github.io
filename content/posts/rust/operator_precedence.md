---
title: Rust与Golang 的运算符优先级
subtitle: ""
date: 2026-01-13T18:09:26+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: "Rust与Golang 的运算符优先级"
toc: true
lastmod: 2026-01-13T18:09:26+08:00
math: true
lightgallery: false
summary: ""
categories:
  - Rust
  - Go
tags:
  - Go
  - Rust
  - LeetCode
---

记录 `Rust` 和 `Golang` 中位运算符(`<<`和`>>`)的优先级不同之处, 然后查看有符号/无符号整数的除法和位运算的汇编区别

<!--more-->

年中要找实习, 所以开始刷LeetCode, 作为一个Rust新手, 我会使用Go和Rust都做一下. 在做二分查找这道题计算中间索引时, 发现 `Rust` 和 `Golang` 的运算符优先级有一些不同

## 问题描述

- Golang版本: `mid := left + (right-left)>>1`, 优先计算 `(right-left)>>1`
- Rust错误版本: `mid := left + (right-left) >> 1`, 优先计算 `left + (right-left) >> 1`
- Rust正确版本: `mid := left + ((right-left) >> 1)`, 使用括号强制优先计算 `(right-left) >> 1`


## 运算符优先级

### Golang

> [!SUCCESS] 
> - [Go spec](https://go.dev/ref/spec#Operators)
> - [中文](https://go-lang.org.cn/ref/spec#Operators)

可以看到, `<<` 和 `>>` 的优先级要高于 `+` 和 `-`

```text
Precedence    Operator
    5             *  /  %  <<  >>  &  &^
    4             +  -  |  ^
    3             ==  !=  <  <=  >  >=
    2             &&
    1             ||
```

### Rust

> [!SUCCESS] 
> - [Rust Reference](https://doc.rust-lang.org/stable/reference/expressions.html#r-expr.precedence)
> - [中文](https://doc.rust-lang.net.cn/reference/expressions.html#r-expr.precedence)


下表优先级从高到低, 优先级相同, 按照其结合性计算

| Operator/Expression | Associativity |
|---------------------|---------------|
| ...                 | ...           |
| `as`                | left to right |
| `*` `/` `%`         | left to right |
| `+` `-`             | left to right |
| `<<` `>>`           | left to right |
| ...                 | ...           |
|                     |               |


## 有符号整数的除法和位运算

一开始处理除以2的场景时, 会使用普通运算符, 后面看到有些题解使用位运算, 就一直使用了, 但并未思考它们的区别?

### Golang

```go {name="main.go" hl_lines=[4,8]}
package main

func f1(left, right int) int {
	return (right - left) / 2
}

func f2(left, right int) int {
	return (right - left) >> 1
}
```

查看汇编代码: `go tool compile -S main.go`

```asm
// 指令长度: 18字节(下一行的size=18), 需要更多的指令来处理符号和溢出
main.f1 STEXT nosplit size=18 args=0x10 locals=0x0 funcid=0x0 align=0x0
        0x0000 00000 (G:/code/go/leetcode/array/main.go:3)      TEXT    main.f1(SB), NOSPLIT|NOFRAME|ABIInternal, $0-16
        0x0000 00000 (G:/code/go/leetcode/array/main.go:3)      FUNCDATA        $0, gclocals·g2BeySu+wFnoycgXfElmcg==(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:3)      FUNCDATA        $1, gclocals·g2BeySu+wFnoycgXfElmcg==(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:3)      FUNCDATA        $5, main.f1.arginfo1(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:3)      FUNCDATA        $6, main.f1.argliveinfo(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:3)      PCDATA  $3, $1
        0x0000 00000 (G:/code/go/leetcode/array/main.go:4)      SUBQ    AX, BX          # BX = right - left
        0x0003 00003 (G:/code/go/leetcode/array/main.go:4)      MOVQ    BX, CX          # 备份差值到CX寄存器
        0x0006 00006 (G:/code/go/leetcode/array/main.go:4)      SHRQ    $63, BX         # 右移63位, 得到符号位(正数为0, 负数为-1)
        0x000a 00010 (G:/code/go/leetcode/array/main.go:4)      LEAQ    (CX)(BX*1), AX  # 修正偏移值
        0x000e 00014 (G:/code/go/leetcode/array/main.go:4)      SARQ    $1, AX          # 算数右移1位(等价于除以2)
        0x0011 00017 (G:/code/go/leetcode/array/main.go:4)      RET                     # 返回结果
        0x0000 48 29 c3 48 89 d9 48 c1 eb 3f 48 8d 04 19 48 d1  H).H..H..?H...H.
        0x0010 f8 c3
// 指令长度: 10字节(下一行的size=10)                                                    ..
main.f2 STEXT nosplit size=10 args=0x10 locals=0x0 funcid=0x0 align=0x0
        0x0000 00000 (G:/code/go/leetcode/array/main.go:7)      TEXT    main.f2(SB), NOSPLIT|NOFRAME|ABIInternal, $0-16
        0x0000 00000 (G:/code/go/leetcode/array/main.go:7)      FUNCDATA        $0, gclocals·g2BeySu+wFnoycgXfElmcg==(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:7)      FUNCDATA        $1, gclocals·g2BeySu+wFnoycgXfElmcg==(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:7)      FUNCDATA        $5, main.f2.arginfo1(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:7)      FUNCDATA        $6, main.f2.argliveinfo(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:7)      PCDATA  $3, $1
        0x0000 00000 (G:/code/go/leetcode/array/main.go:8)      SUBQ    AX, BX           # BX = right - left
        0x0003 00003 (G:/code/go/leetcode/array/main.go:8)      SARQ    $1, BX           # 算数右移1位(等价于除以2)
        0x0006 00006 (G:/code/go/leetcode/array/main.go:8)      MOVQ    BX, AX           # 讲结果移动到返回寄存器AX
        0x0009 00009 (G:/code/go/leetcode/array/main.go:8)      RET                      # 返回结果
        0x0000 48 29 c3 48 d1 fb 48 89 d8 c3                    H).H..H...
go:cuinfo.producer.<unlinkable> SDWARFCUINFO dupok size=0
        0x0000 72 65 67 61 62 69                                regabi
go:cuinfo.packagename.main SDWARFCUINFO dupok size=0
        0x0000 6d 61 69 6e                                      main
main..inittask SNOPTRDATA size=8
        0x0000 00 00 00 00 00 00 00 00                          ........
gclocals·g2BeySu+wFnoycgXfElmcg== SRODATA dupok size=8
        0x0000 01 00 00 00 00 00 00 00                          ........
main.f1.arginfo1 SRODATA static dupok size=5
        0x0000 00 08 08 08 ff                                   .....
main.f1.argliveinfo SRODATA static dupok size=2
        0x0000 00 00                                            ..
main.f2.arginfo1 SRODATA static dupok size=5
        0x0000 00 08 08 08 ff                                   .....
main.f2.argliveinfo SRODATA static dupok size=2
        0x0000 00 00                                            ..                           ..
```

综上所述, 两种方式的结果是相同的, 但位运算的方式更高效, 使用的指令更少

### Rust

安装工具: `cargo install cargo-show-asm`

```rust {name="main.rs", hl_lines=[3,8]}
#[unsafe(no_mangle)]
fn func1(left: i64, right: i64) -> i64 {
    (right - left) / 2
}

#[unsafe(no_mangle)]
fn func2(left: i64, right: i64) -> i64 {
    (right - left) >> 1
}

fn main() {

}

```

使用`cargo show-asm`查看汇编代码

```asm {title="cargo asm --bin <项目名> --intel func1"}
	.globl	func1
	.p2align	4
func1:
	sub rdx, rcx     # 计算差值, rcx=left, rdx=right
	mov rax, rdx     # 将差值复制到rax寄存器, rax是64位返回值寄存器
	shr rax, 63      # 逻辑右移63位, 获得差值的符号位
	add rax, rdx     # 讲符号位加到原差值上, 实现负数除法时的向零取整修正
	sar rax, 1       # 算数右移1位(等价于除以2)
	ret
```
```asm {title="cargo asm --bin <项目名> --intel func2" hl_lines=["4-7"]}
	.globl	func2
	.p2align	4
func2:
	mov rax, rdx    # 将rdx的值复制到rax, rdx是第二个参数right
	sub rax, rcx    # rcx=left, 计算差值, rax = rac-rcx = right-left
	sar rax         # 算数右移1位(等价于除以2)
	ret				# 返回结果
```

### 总结

> [!NOTE] 通过上述分析不难注意到, 位运算的方式更高效, 使用的指令更少


## 无符号整数的除法和位运算

### Golang

```go {hl_lines=[3,8]}
//go:noinline
func f3(left, right uint) uint {
	return (right - left) / 2
}

//go:noinline
func f4(left, right uint) uint {
	return (right - left) >> 1
}
```

```asm {hl_lines=["8-11","20-23"] wrapper=false}
main.f3 STEXT nosplit size=10 args=0x10 locals=0x0 funcid=0x0 align=0x0
        0x0000 00000 (G:/code/go/leetcode/array/main.go:14)     TEXT    main.f3(SB), NOSPLIT|NOFRAME|ABIInternal, $0-16
        0x0000 00000 (G:/code/go/leetcode/array/main.go:14)     FUNCDATA        $0, gclocals·g2BeySu+wFnoycgXfElmcg==(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:14)     FUNCDATA        $1, gclocals·g2BeySu+wFnoycgXfElmcg==(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:14)     FUNCDATA        $5, main.f3.arginfo1(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:14)     FUNCDATA        $6, main.f3.argliveinfo(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:14)     PCDATA  $3, $1
        0x0000 00000 (G:/code/go/leetcode/array/main.go:15)     SUBQ    AX, BX
        0x0003 00003 (G:/code/go/leetcode/array/main.go:15)     SHRQ    $1, BX
        0x0006 00006 (G:/code/go/leetcode/array/main.go:15)     MOVQ    BX, AX
        0x0009 00009 (G:/code/go/leetcode/array/main.go:15)     RET
        0x0000 48 29 c3 48 d1 eb 48 89 d8 c3                    H).H..H...
main.f4 STEXT nosplit size=10 args=0x10 locals=0x0 funcid=0x0 align=0x0
        0x0000 00000 (G:/code/go/leetcode/array/main.go:19)     TEXT    main.f4(SB), NOSPLIT|NOFRAME|ABIInternal, $0-16
        0x0000 00000 (G:/code/go/leetcode/array/main.go:19)     FUNCDATA        $0, gclocals·g2BeySu+wFnoycgXfElmcg==(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:19)     FUNCDATA        $1, gclocals·g2BeySu+wFnoycgXfElmcg==(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:19)     FUNCDATA        $5, main.f4.arginfo1(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:19)     FUNCDATA        $6, main.f4.argliveinfo(SB)
        0x0000 00000 (G:/code/go/leetcode/array/main.go:19)     PCDATA  $3, $1
        0x0000 00000 (G:/code/go/leetcode/array/main.go:20)     SUBQ    AX, BX
        0x0003 00003 (G:/code/go/leetcode/array/main.go:20)     SHRQ    $1, BX
        0x0006 00006 (G:/code/go/leetcode/array/main.go:20)     MOVQ    BX, AX
        0x0009 00009 (G:/code/go/leetcode/array/main.go:20)     RET
        0x0000 48 29 c3 48 d1 eb 48 89 d8 c3                    H).H..H...
```


### Rust

Rust会对无符号的简单除法做优化, 直接使用位运算代替, 可以看到下面的func3和func4的汇编代码是相同的

```rust {name="main.rs" hl_lines=[3,9]}
#[unsafe(no_mangle)]
fn func3(left: u64, right: u64) -> u64 {
    (left-right) >> 1
}


#[unsafe(no_mangle)]
fn func4(left: u64, right: u64) -> u64 {
    (left-right) / 2
}
```

```asm {title = "cargo asm --bin <项目名> --intel func3" hl_lines=["4-7"] lineNos=false}
	.globl	func3
	.p2align	4
func3:
	mov rax, rcx
	sub rax, rdx
	shr rax
	ret
```

```asm {title="cargo asm --bin <项目名> --intel func4" hl_lines=["4-7"] lineNos=false}
	.globl	func4
	.p2align	4
func4:
	mov rax, rcx
	sub rax, rdx
	shr rax
	ret
```

### 总结

> [!NOTE] 针对无符号数的除法(`/2`,`/4`,`/8`), 编译器会直接转化为位运算, 提高效率
