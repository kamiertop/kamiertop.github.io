---
title: Linux中关闭使用Chrome时网站弹出的xdg-open提示
subtitle: ""
date: 2026-05-13T17:41:25+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2026-05-13T17:41:25+08:00
math: true
lightgallery: false
summary: "Linux中关闭使用Chrome时网站弹出的xdg-open提示"
categories:
  - misc
tags:
  - Fedora
  - xdg-open
---

## 问题描述

> [!abstract]
> 最近全面拥抱[Fedora](https://fedoraproject.org/)，使用Chrome访问[抖音](https://www.douyin.com/)时，总是会弹出xdg-open的提示，特别烦，经由GPT大人指导，终于找到了解决办法

弹框如下图所示：

![](/misc/chrome-xdg-open/1.png)

## 解决办法

点击上图中的：**打开xdg-open**，弹出如下图所示的提示：

![](/misc/chrome-xdg-open/2.png)

> [!note]
> 可以看到截图中有：打开 “bitbrowser://cc/”，这个 `bitbrowser://` 就是我们需要的

执行以下命令

```bash
sudo mkdir -p /etc/opt/chrome/policies/managed
sudo tee /etc/opt/chrome/policies/managed/block-bitbrowser.json >/dev/null <<'EOF'
{
  "URLBlocklist": [
    "bitbrowser://*"
  ]
}
EOF
```

除了这个，抖音还有一个协议，文件最终内容如下图所示：

![](/misc/chrome-xdg-open/3.png)

执行完毕后，重启Chrome浏览器，访问抖音就不会看到那个烦人的xdg-open提示了，完美解决！🥰

最后可以在浏览器的地址栏输入 `chrome://policy/` 来查看当前生效的策略，确认我们刚才添加的策略已经生效了，如下图所示：

![](/misc/chrome-xdg-open/4.png)

## 结语

> [!summary] 如果看到其他网站也有类似的弹出提示，可以通过同样的方式来解决，找到对应的协议，添加到URLBlocklist中即可
