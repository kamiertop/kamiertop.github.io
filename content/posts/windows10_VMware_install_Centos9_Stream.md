---
title: Windows10 Vmware17 安装Centos-9-stream 引导界面卡顿
date: 2025-05-04T10:32:10+08:00
draft: false
comment: true
weight: 0
description: Windows10 Vmware17 安装Centos-9-stream 引导界面卡顿.
categories:
  - tool
summary: 自己电脑配置还行, 但是引导Centos9时非常卡, 低版本的Centos就没问题
---

<!--more-->

{{< admonition type=question title="环境" open=true >}}
- 环境: Windows10, vmware17, Centos-9-Stream-latest, AMD-7900x
- 在引导界面非常卡, 页面无法正确显示, 点击无反应/响应慢
{{< /admonition >}}


{{< admonition type=success title="解决办法" open=true >}}
- 解决办法: 在配置虚拟机时, 内存和CPU多分配一点
- 一开始分配的是16G和6(3*2)核, 上网检索发现了一篇类似的帖子, 然后分配了32G+12(6*2)核, 成功安装!
{{< /admonition >}}

