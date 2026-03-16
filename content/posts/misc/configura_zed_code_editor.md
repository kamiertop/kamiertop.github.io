---
title: 配置Zed快捷键
subtitle: ""
date: 2026-03-16T11:33:45+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-03-16T11:33:45+08:00
math: true
lightgallery: false
summary: "Zed是一款由Rust编写的代码编辑器, 由于官方文档不是特别全面, 所以这里介绍一下自己如何折腾`快捷键配置`的"
categories:
  - misc
---

> Zed官网的文档对于快捷键介绍不是特别完全, 所以这里简单记录一下

- [Zed官网](https://zed.dev/)
- [文档地址](https://zed.dev/docs/)

## Base Keymap

> [!NOTE] 从其它编辑器中转过来的同学们可以选择一个自己之前熟悉的方案
> 左上角Zed -> Open Settings -> Keymap -> Base Keymap

这里我选择的是: **JetBrains**，但依然有些配置不满意，或者和JetBrains的不一样，所以就需要自己配置了

## 简单配置

以命令面板为例，默认的是`shift+shift`，我想改为`ctrl-p`

- 点击左上角Zed -> Open Keymap File
- 写入如下配置

```json {enable = false}
[
  {
    "context": "Workspace",
    "bindings": {
      "ctrl-p": "command_palette::Toggle"
    }
  }
]
```

- 那么如何知道`ctrl-p`对应的操作就是 `"command_palette::Toggle"` 呢，可以打开默认的快捷键配置文件，然后 `Ctrl-F` 搜索快捷键即可知道对应的Action

## 略微复杂配置

- 之前使用 `Windows`，用的是Windows Terminal，在Windows Terminal上`Ctrl+C`有选中时就是复制语义，否则就只是Ctrl+C
- 当前的系统是 `Arch Linux`，终端中的复制默认是：`Ctrl+Shift+C`，粘贴是：`Ctrl+Shift+V`
- 修改
  - 首先在默认的快捷键配置文件中找到 `Action`，发现是：`terminal::Copy`和`terminal::Paste`，以及`["terminal::SendKeystroke", "ctrl-c"]`
  - 我们的目的是让 `Ctrl-C` 分条件选择 `terminal::Copy` 和 `["terminal::SendKeystroke", "ctrl-c"]`，核心是：<span style="color: blue">找到在终端环境时，选中和不选中时的上下文差别</span>
  - 根据文档我们需要打开命令面板，然后输入：`dev: open key context view`，如下图所示：![keybind](/misc/keybind.png)
  - 打开终端，观察上下文树：![context](/misc/context.png)
  - 打开终端，鼠标选中一段文本，观察上下文树：![context_selection](/misc/context_selection.png)
  - 找到了上下文差别，就可以写快捷键了，如下所示：
  - ```json {expandDepth=2, copyable=false, sort=true, boxed=false, enable = false}
    [
      {
        "context": "Terminal",
        "bindings": {
          "ctrl-v": "terminal::Paste"
        }
      },
      {
        "context": "Terminal && selection",
        "bindings": {
          "ctrl-c": "terminal::Copy"
        }
      },
      {
        "context": "Terminal && !selection",
        "bindings": {
          "ctrl-c": ["terminal::SendKeystroke", "ctrl-c"]
        }
      }
    ]
    ```

## 总结

> [!SUCCESS] 依照官方文档所说，大部分操作都有快捷键，通过刚才的方式可以实现大部分的配置
