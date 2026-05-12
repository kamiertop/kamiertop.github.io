---
title: Fedora44 JetBrains IDE Emoji字体设置
subtitle: ""
date: 2026-05-11T21:49:29+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-05-11T21:49:29+08:00
math: true
lightgallery: false
summary: ""
categories:
  - misc
tags:
  - IDE
  - Fedora44
  - JetBrains
  - Font
---

在Fedora44中使用Goland、RustRover等JetBrains IDE时发现无法显示彩色Emoji，并且还需要支持中文，一番折腾找到如下解决办法

```mermaid

flowchart LR

设置 --> 编辑器 --> 字体

字体 --> MapleMono(主要字体：Maple Mono Normal NL)
字体 --> 回滚字体(回滚字体：Noto Color Emoji)

```

---

{{<link "https://github.com/subframe7536/maple-font" "Maple Font" "" true>}}
