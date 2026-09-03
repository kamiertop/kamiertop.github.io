---
title: 'Hugo Fixit主题常用组件使用示例'
date: '2026-09-03T19:32:37+08:00'
draft: false
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
lastmod: '2026-09-03T19:32:37+08:00'
lightgallery: false
summary: "Hugo Fixit主题常用功能链接"
categories:
  - Misc
tags:
  - Misc
---


## 代码块

### 链接

- https://fixit.lruihao.cn/zh-cn/docs/content-management/markdown-syntax/extended/#code-fences-extended
- https://gohugo.io/content-management/syntax-highlighting/#highlighting-in-code-fences
- https://fixit.lruihao.cn/zh-cn/docs/getting-started/configuration/params/#codeblock

### 概念：Hugo 高亮 vs FixIt 包装器

代码块的配置分两层，各管各的：

- Hugo `[markup.highlight]`（`config/_default/markup.toml`）：代码块**内容本身**——语法高亮、配色、行号、语言检测、tab 宽度
- FixIt `[params.codeblock]`（`config/_default/params.toml`）：代码块**包装器**——复制/下载/全屏按钮、显示模式、阴影、折叠

> 命名注意：两层里各有 `style`/`mode`，含义不同——Hugo 的 `style` 是 Chroma 配色主题名（`noClasses=false` 时不生效）；FixIt 的 `mode` 是包装器样式（classic / mac / simple）。

### 属性

#### 基础属性（FixIt 扩展语法）

- name="" 代码块名称 / 标签项名称，左上角显示
- title="" 代码块标题，居中显示
- group="" 标签组名称（多个代码块组成 tab 切换）
- before_tabs="" 在标签项之前显示的内容
- filename="" 代码块文件名（可用于下载）

#### 高亮选项（Hugo）

- hl_lines=[1, "4-9"] 高亮指定行或行范围
- linenos=false 是否显示行号：true / false / inline / table
- linenostart=1 起始行号
- anchorlinenos=false 行号渲染为 HTML 锚点
- lineanchors="" 行号锚点 id 的前缀
- tabwidth=4 tab 替换的空格数

#### 主题配置（codeblock，可用 Markdown 属性覆盖）

- wrapper_class="" 附加到代码块容器上的类，空格分隔多个，可选值：
  - is-collapsed 初始折叠（超过 max_shown_lines 时只显示预览部分）
  - is-expanded 初始展开（忽略折叠限制，全部显示）
  - line-nos-hidden 初始隐藏行号
  - line-wrapping 初始开启自动换行
- max_shown_lines=10 预览时显示的最大行数
- shadow="never" 阴影：always / hover / never
- copyable=true 显示复制按钮


#### 已废弃的 camelCase 别名（v1.0.0 起改用 snake_case）

- wrapperClass → wrapper_class
- maxShownLines → max_shown_lines
- lineNosToggler → line_nos_toggler
- lineWrapToggler → line_wrap_toggler

### 全局默认配置（Hugo markup.highlight）

放在 `config/_default/markup.toml` 的 `[highlight]` 段，是所有代码块的默认值；标 ✅ 的项可在单个代码块用 fence 属性覆盖。

| 配置键 | 默认值 | 说明 | fence 覆盖 |
| --- | --- | --- | --- |
| `codeFences` | `true` | 是否高亮围栏代码块 | ❌ |
| `noClasses` | `true` | `false` 输出 CSS class（FixIt 必需 `false`）；`true` 输出内联样式 | ❌ |
| `style` | `monokai` | Chroma 配色主题，仅 `noClasses=true` 时生效 | ✅ `style="..."` |
| `guessSyntax` | `false` | 未指定语言时自动检测 | ✅ `guesssyntax=true` |
| `lineNos` | `false` | 是否显示行号：true / false / inline / table | ✅ `linenos=...` |
| `lineNoStart` | `1` | 起始行号 | ✅ `linenostart=...` |
| `lineNumbersInTable` | `true` | 行号用两列表格渲染 | ❌ |
| `hl_Lines` | `""` | 全局默认高亮行 | ✅ `hl_lines=[...]` |
| `anchorLineNos` | `false` | 行号渲染成锚点 | ✅ `anchorlinenos=true` |
| `lineAnchors` | `""` | 行号锚点 id 前缀 | ✅ `lineanchors="..."` |
| `hl_inline` | `false` | 不带外层容器渲染 | ✅ `hl_inline=true` |
| `tabWidth` | `4` | tab 替换空格数 | ✅ `tabwidth=4` |
| `wrapperClass` | `highlight` | 高亮最外层 class（v0.140.2+，仅全局） | ❌ |

键名规律：配置文件用 camelCase（`lineNoStart`、`anchorLineNos`、`hl_Lines`），fence 属性用小写（`linenostart`、`anchorlinenos`、`hl_lines`）。

> 注意区分：Hugo 的 `wrapperClass`（全局配置，控制高亮最外层 class）≠ FixIt 的 `wrapper_class`（代码块包装器附加类）。在 fence 里写 `wrapperClass` 会被 Hugo 转小写成 `wrapperclass`，并被 FixIt 当作废弃别名解析为 `wrapper_class`。

## Mermaid

- https://fixit.lruihao.cn/zh-cn/docs/content-management/diagrams-support/mermaid/
- https://fixit.lruihao.cn/zh-cn/docs/content-management/shortcodes/extended/mermaid/

## Image

- https://fixit.lruihao.cn/zh-cn/docs/content-management/shortcodes/extended/introduction/#image
- https://fixit.lruihao.cn/zh-cn/docs/content-management/markdown-syntax/basics/#%E5%9B%BE%E7%89%87

## Link

- https://fixit.lruihao.cn/zh-cn/docs/content-management/markdown-syntax/basics/#links