---
title: Fedora JetBrains IDE 乱码
subtitle: ""
date: 2026-05-06T20:02:25+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-05-06T20:02:25+08:00
math: true
lightgallery: false
summary: "Fedora 安装 JetBrains 时乱码解决方案"
categories:
  - misc
# See details front matter: https://fixit.lruihao.cn/documentation/content-management/introduction/#front-matter
# 图标支持：https://fixit.lruihao.cn/zh-cn/documentation/content-management/diagrams-support/mermaid/
---

# Fedora 中安装 JetBrains IDE 乱码解决方案

[Fedora](https://fedoraproject.org/)44发布后从Arch转了过来，总体感觉都很不错，有些小问题但是可以接受。

安装Goland、RustRover时发现选择中文语言时会乱码，下载了一个[字体](https://github.com/AirLongDian/MeowSans_Font)，修改了一下页面字体成功解决

先看下面图片

![](/misc/rust_rover.png)

随意打开一个项目，然后打开设置，参照下图设置，重启即可

![](/misc/fix_text.png)