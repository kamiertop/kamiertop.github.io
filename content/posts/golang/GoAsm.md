---
title: 如何在Go中使用汇编
subtitle: ""
date: 2026-01-22T14:45:14+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-01-22T14:45:14+08:00
math: true
lightgallery: false
summary: "简单学习如何在Go中使用汇编"
categories:
  - Go
Tags:
  - Go
---

晚上课题组聚餐, 没啥心思学习了, 借助LLM简单学习了一下如何使用, 在此感谢[Gemini](https://gemini.google.com/)

> [!quote] 一些资料 
> 之前在曹大和柴大的[《Go语言高级编程》](https://chai2010.cn/advanced-go-programming-book/ch3-asm/readme.html)中看到有关于汇编的介绍,
> Go官网也有一篇[文章](https://go.dev/doc/asm), 网上还有一些其他的资料
> - [Rob Pike: A Manual for the Plan 9 assembler](https://9p.io/sys/doc/asm.html)
> - [Plan 9 from Bell Labs](https://doc.cat-v.org/plan_9/)
> - [Go Assembly by Example](https://davidwong.fr/goasm/)
> - [Xargin: plan9 assembly 完全解析](https://segmentfault.com/a/1190000039978109)

## 为什么使用汇编

> Gemini 生成

1. 极致性能. (我们写的汇编不一定就能增加性能, 反而导致性能下降)
2. 访问特定的CPU特性, 比如做一些硬件加解密, 随机数生成等
3. 精确控制内存与寄存器
   1. 零拷贝处理
   2. 固定寄存器变量
4. 系统调用与内核交互
   1. 自制系统调用：你可以直接通过 SYSCALL 指令与内核对话, 跳过标准库的封装
   2. 上下文切换：如果你在尝试实现用户态协程调度器, 手写汇编是保存和恢复寄存器上下文（Context Switch）的唯一方法
5. 绕过 `runtime` 的限制
   1. 边界检查(很久之前看过一篇文章, 定位到热点调用之后, 在确保完全不会越界的情况下, 直接使用汇编实现)
   2. 逃避栈溢出检查
6. ...

## 实现一个简单的`Add`

> [!NOTE] 与平常的函数/方法不同, 我们只需要声明一个函数即可, 不需要函数体/方法体

```go {title="main.go" lineNos=false}
func Add(a, b int64) int64
```

接下来在当前目录下新建一个 `.s` 结尾的文件, 关于具体的语法可以参考文档或者交给LLM

```asm {title="add_amd64.s"}
TEXT ·Add(SB), NOSPLIT, $0-24
    MOVQ a+0(FP), AX
    MOVQ b+8(FP), BX
    ADDQ BX, AX
    MOVQ AX, ret+16(FP)
    
    RET
// 文件结尾最后必须有一个空行
```

然后直接编译/运行即可: `go run .`

## 尝试使用`SIMD`指令

`SIMD`指令可以用来进行并行计算, 例如对两个向量进行加法运算, 可以使用`SIMD`指令来并行计算, 从而提高计算效率, 下面的代码是直接相加, 不考虑溢出,
并且这个场景可能也不合理, 但目的只是为了演示如何使用`SIMD`指令

> [!NOTE] 下面只是用来演示
```go {title="main.go"}
func AddByRange(a, b [8]int64) [8]int64 {
	for i := range a {
		a[i] += b[i]
	}

	return a
}

func AddByAsm(a, b [8]int64) [8]int64
```

同理可以新建一个 `.s` 结尾的文件, 或者用刚才的 `add_amd64.s` 文件也可以, 对文件名不挑剔, 但要求汇编中有我们定义的函数

```asm {title="add_amd64.s", hl_lines=[6]}
// 函数签名：func AddByAsm(a, b [8]int64) [8]int64
// 参数 a: 8*8 = 64 字节 (偏移 0)
// 参数 b: 8*8 = 64 字节 (偏移 64)
// 返回值: 8*8 = 64 字节 (偏移 128)
// 总栈空间: 64 + 64 + 64 = 192 字节
TEXT ·AddByAsm(SB), NOSPLIT, $0-192
    // 1. 仅将 a 加载到 Z0
    VMOVDQU64 a+0(FP), Z0

    // 2. 直接将内存中的 b 与 Z0 相加，结果存入 Z0
    // 指令格式：VPADDQ mem, reg_src, reg_dest
    VPADDQ b+64(FP), Z0, Z0

    // 3. 将结果写回
    VMOVDQU64 Z0, ret+128(FP)
    VZEROUPPER
    
    RET
// 文件结尾最后必须有一个空行
```
