---
title: Fedora在Ghostty中使用Codex、Claude等TUI工具输入中文时闪退崩溃
subtitle: ""
date: 2026-05-11T18:05:39+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-05-11T18:05:39+08:00
math: true
lightgallery: false
summary: "一个奇怪的闪退bug"
categories:
  -
---

# Fedora44中使用Ghostty运行tui工具输入中文时崩溃

- 输入法：Fcitx5-Rime
- Terminal：[Ghostty](https://ghostty.org/)
- Agent工具：Codex、ClaudeCode
- 问题：输入中文时直接崩溃退出
- 解决办法（GPT大人）：`env GTK_IM_MODULE=wayland ghostty`，在新启动的终端中执行`codex`/`claude`，输入中文一切正常，随后不设置环境变量都可以了
- 原因：不知道，很奇怪...
- 其他终端中是否尝试：未尝试
