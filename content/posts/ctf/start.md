---
title: 'CTF入门'
date: '2026-08-10T21:30:05+08:00'
draft: false
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
lastmod: '2026-08-10T21:30:05+08:00'
lightgallery: false
summary: "CTF入门第一天学习"
categories:
  - CTF
tags:
  - CTF
---

## 2026-08-10

> 资料收集、账号注册、初步尝试解决几个简单的Web题目

- CTF是什么
- CTF的分类
- CTF的比赛形式
- Web
  - 重定向
  - 简单的密码爆破（后面继续评估使用Go还是Python作为主力）
  - 重定向
  - HTTP请求方法
  - `curl`的L和X参数
  - http基本认证
  - 简单的几个题目：base64解码、字符串移位，F12查看源代码

## 2026-08-17

> web：信息泄露

- 备份文件下载
  - 下载网站源码：常见的目录名字和后缀做笛卡尔积然后发送请求
  - bak文件：
    - 备份文件的后缀名：`.bak`、`.old`、`.backup`、`.zip`、`.tar.gz`
    - 备份文件的目录名：`backup`、`bak`、`old`、`temp`
  - vim缓存： `.index.php.swp`，使用 vim -r 恢复，但当前电脑一般没原来的环境，无法精准恢复，使用 strings 工具查看
  - `.DS_Store` 泄露，尝试获取该文件，然后解析该二进制文件
- svn泄露（还需要再了解）