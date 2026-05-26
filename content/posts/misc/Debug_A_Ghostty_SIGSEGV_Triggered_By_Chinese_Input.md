---
title: 记录一次在Ghostty中使用Codex、Claude等TUI工具时输入中文引发的SIGSEGV崩溃问题
subtitle: ""
date: 2026-05-14T10:30:27+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-05-14T10:30:27+08:00
math: true
lightgallery: false
summary: "解决在Ghostty中使用Codex、Claude等TUI工具时输入中文引发的SIGSEGV崩溃问题"
categories:
  - misc
tags:
  - Ghostty
  - TUI
  - SIGSEGV
---

> [!warning]
> 下面的内容不能完全修复，重启之后还是会遇到，我已选择 [kitty](https://sw.kovidgoyal.net/kitty/)

## 环境

- OS: Fedora 44
- Terminal: Ghostty
- TUI工具: Codex、Claude
- Shell: zsh
- 输入法: Fcitx5

## 问题描述

在ghostty中使用Codex和Claude只要输入中文，ghostty就崩溃闪退

## 排查方法

1. 在“软件”中下载一个终端
2. 启动 Claude，借助AI来调试，这里的模型是 DeepSeek-v4-pro
3. 在新的终端中没发现任何问题
4. 向Claude描述问题，Claude开始排查问题
5. 切换IME模块为wayland，问题依旧
6. 使用 `coredumpctl` 来分析崩溃日志，发现是SIGSEGV错误，怀疑是内存访问违规导致的崩溃
7. 进一步分析崩溃日志，发现崩溃发生在字体查找相关的代码路径上，查看配置文件
8. 之前的设置：`font-family = JetBrainsMono Nerd Font Mono`, 这个字体对中文支持不太好，新增配置（可自行增加字体）
9. ```text {title="~/.config/ghostty/config.ghostty"}
   font-family = JetBrainsMono Nerd Font Mono
   font-family = Maple Mono Normal NL NF CN
   font-family = PingFang SC
   ```
10. 重新加载配置，问题解决

## 日志分析

执行命令：`coredumpctl info ghostty`，获取崩溃日志，下面保留核心记录：

Stack Trace 从下往上看， #0 是崩溃发生的地方，#1、#2、#3...是调用栈上的函数调用关系，可以看到崩溃发生在 `FcCompare` 函数中，这个函数通常与字体比较相关，可能是在处理字体时发生了内存访问违规导致的崩溃。

```text
PID: 60355 (ghostty)
        Signal: 11 (SEGV)
     Timestamp: Thu 2026-05-14 09:55:58 CST (1h 27min ago)
  Command Line: ghostty
    Executable: /usr/bin/ghostty
 Control Group: /user.slice/user-1000.slice/user@1000.service/app.slice/app-ghostty-surface-transient-60238.scope
          Unit: user@1000.service
     User Unit: app-ghostty-surface-transient-60238.scope
         Slice: user-1000.slice
      Hostname: fedora
       Storage: /var/lib/systemd/coredump/core.ghostty.1000.46a22e39f1714ec6bfb0c3dcec0c2e34.60355.1778723758000000.zst (missing)
       Message: Process 60355 (ghostty) of user 1000 dumped core.
                Module /usr/bin/ghostty without build-id.
                Stack trace of thread 60393:
                #0  0x0000558f3d669198 FcCompare (/usr/bin/ghostty + 0x1b28198)               // 字体比较，最终崩溃点
                #1  0x0000558f3d6688f8 FcFontSetSort (/usr/bin/ghostty + 0x1b278f8)           // 对字体集合进行排序
                #2  0x0000558f3d669948 FcFontSort (/usr/bin/ghostty + 0x1b28948)              // 对字体进行排序
                #3  0x0000558f3cf18653 config.Config.fontSort (/usr/bin/ghostty + 0x13d7653)
                #4  0x0000558f3cfcb7d6 font.CodepointResolver.getIndexCodepointOverride (/usr/bin/ghostty + 0x148a7d6)  // 获取特定 Unicode 码点的字体索引
                #5  0x0000558f3d1e8ecc font.SharedGrid.getIndex (/usr/bin/ghostty + 0x16a7ecc) // 获取字体索引
                #6  0x0000558f3d1e9981 font.shaper.run.RunIterator.indexForCell (/usr/bin/ghostty + 0x16a8981)    // 为每个单元格计算字符索引
                #7  0x0000558f3d1d9612 renderer.generic.Renderer(renderer.OpenGL).rebuildRow (/usr/bin/ghostty + 0x1698612) // 重建渲染行，可能涉及到字体索引的计算
                #8  0x0000558f3d1c4c75 renderer.generic.Renderer(renderer.OpenGL).updateFrame (/usr/bin/ghostty + 0x1683c75)  // 更新渲染帧
                #9  0x0000558f3d1b614e renderer.Thread.renderCallback (/usr/bin/ghostty + 0x167514e)  // 渲染线程的回调函数，负责更新渲染帧
                #10 0x0000558f3d1c8b0b watcher.async.AsyncDynamic(dynamic.Xev(&.{ .io_uring, .epoll }[0..2])).wait__anon_631512__>
                #11 0x0000558f3d1989b5 backend.io_uring.Completion.invoke (/usr/bin/ghostty + 0x16579b5)
                #12 0x0000558f3d19ac0d backend.io_uring.Loop.tick___anon_622013 (/usr/bin/ghostty + 0x1659c0d)
                #13 0x0000558f3d16d3b3 renderer.Thread.threadMain_ (/usr/bin/ghostty + 0x162c3b3)  // 渲染线程的主循环
```

> [!success] 从日志分析可以看出，崩溃发生在字体比较的过程中，可能是因为输入中文时，Ghostty尝试查找合适的字体进行渲染，然而由于配置中缺乏对中文的支持，导致在处理字体时发生了内存访问违规，最终引发了SIGSEGV崩溃
