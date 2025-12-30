---
title: 如何在pycharm中使用UV和Jupyter
date: 2025-05-15T21:25:55+08:00
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
categories:
  - misc
summary: 没有使用uv时在Pycharm中可以很容易使用jupyter(pycharm会自己下载), 使用uv会反而不行了, 简单折腾一下

# See details front matter: https://fixit.lruihao.cn/documentation/content-management/introduction/#front-matter
---

<!--more-->

## 前情提要

最近开始学习机器学习相关的内容, 难免要用到 `Jupyter`
之前并没有使用 `uv`来管理环境, 在项目中新建一个 `ipynb`文件, pycharm会自动下载Jupyter
完全使用uv之后, pycharm反而无法下载成功, 翻看 `uv`文档之后简单折腾了一下, 找到了解决方案

## 解决

- 安装全局jupyter-lab: `uv tool install jupyter-lab`
- 生成配置文件: `jupyter lab --generate-config`
- 编辑配置文件, 添加以下内容
    ```bash
    # 关闭用户认证, 启动时不打开浏览器(我这里在浏览器环境发现无法进行代码补全, 不想折腾了, 加上更喜欢在pycharm中使用)
    c.NotebookApp.token = ''
    c.NotebookApp.password = ''
    c.LabApp.open_browser = False
    ```
- 执行命令, 启动server: `uv run --with jupyter jupyter lab`

------------

> [!TIP]
> 注意配置当前项目的解释器, 需要设置为`uv`

## 相关链接

{{< link "https://docs.astral.sh/uv/" "uv" "" true "https://docs.astral.sh/uv/assets/logo-letter.svg" >}}

> [!NOTE] 
> 更新到最新版本Pycharm之后, 似乎已经支持了, 我这里也不想再探究了, 新项目直接 `uv add notebook`, 在notebook中运行之后Pycharm会自动启用
