---
title: 使用 mygo 实现（无边框）圆角窗口
date: '2026-10-24T18:16:27+08:00'
draft: false
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
lastmod: '2026-10-24T18:16:27+08:00'
lightgallery: false
summary: "记录如何使用 mygo 实现（无边框）圆角窗口"
categories:
  - Go
tags:
  - Go
  - GUI
  - mygo
---

{{<link "https://github.com/egoist/mygo" "mygo" "" true>}}

[mygo](https://github.com/egoist/mygo) 是一个用 Go 语言编写的跨平台 GUI 框架，支持 Windows、macOS 和 Linux。
有 Native UI 和 WebView两种模式，这篇文章展示一个最小的demo演示如何使用 mygo 的 Native UI 模式实现一个圆角窗口（由Claude+Glm5.3指导）

```go {name="main.go", hl_lines=[38,39,40,69]}
// mygo-demo：纯 mygo 实现的无边框圆角窗口演示。
// 特性：透明圆角、最大化时自动变直角、可拖拽标题栏、
// 自绘的三个窗口控制按钮（最小化 / 最大化 / 关闭）。
//
//	go run .
package main

import (
	"log"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"

	"github.com/ELY-Open-Source/MujicaUI/icons" // 图标集：mygo 本体没有内置图标
)

// radius 是窗口的圆角半径（单位 DIP，逻辑像素）。
// 最大化时圆角会置 0（直角），否则四角会透出桌面。
const radius = 12

// closeRed 是关闭按钮 hover 时的红色，仿系统窗口控件的惯例。
var closeRed = ui.Hex("#c01c28")

// app 是窗口显示的状态。窗口引用也存这里：ui.Context 不暴露窗口。
type app struct{ win *mygo.Window }


func main() {
	a := &app{}
	mygo.App.WhenReady(func() {
		a.win = mygo.NewWindow(mygo.WindowOptions{
			Title:     "mygo rounded window",
			Width:     480,
			Height:    320,
			MinWidth:  320,
			MinHeight: 200,
			// 三个关键窗口选项：
			TitleBarStyle:     mygo.TitleBarHidden, // 隐藏系统标题栏
			HideWindowButtons: true,                // 连系统窗口按钮也隐藏，由视图自绘
			Transparent:       true,                // 窗口透明（RGBA），圆角透出桌面；false 则四角不透明
			Content:           ui.View(a.view),
		})
	})
	if err := mygo.App.Run(); err != nil {
		log.Fatal(err)
	}
}

// view 每帧从状态重建整个界面（即时模式）：窗口需要绘制时就调用它。
func (a *app) view(c *ui.Context) {
	t := c.Theme() // mygo 内置主题：颜色随系统深浅色自动切换

	// 根节点背景设为全透明，桌面才能从圆角外透出来。
	// （普通窗口根节点默认画主题背景色，会把整窗填成不透明。）
	c.Root().Background(ui.Transparent)

	// 最大化时用直角，其余时候用圆角。
	r := float32(radius)
	if a.win != nil && a.win.IsMaximized() {
		r = 0
	}

	// 圆角外框：Fill 铺满窗口，Clip 按圆角裁剪子内容，
	// Background 画窗口底色，Border 画一圈 1px 描边。
	// ★ 是否要描边就看下面这行：去掉 .Border(...) 即无边框，
	//   第一个参数是宽度（DIP），改成 2 更粗，配 t.Border.Alpha(0.5) 变半透明。
	ui.Column(c).Fill().Clip().Radius(r).
		Background(t.Background).
		Border(1, t.Border).
		Children(func() {
			a.titleBar(c)
			// 内容区：居中一行提示文字。
			ui.Column(c).Grow(1).Center().Children(func() {
				ui.Text(c, "拖动标题栏移动 · 双击标题栏最大化").TextColor(t.TextMuted)
			})
		})
}

// titleBar 是自绘标题栏：整条栏 DragWindow 可拖拽（双击自动最大化/还原），
// 右侧放三个窗口控制按钮。
func (a *app) titleBar(c *ui.Context) {
	t := c.Theme()
	ui.Row(c).FillWidth().Shrink(0).MinHeight(32).Padding(0, 12).Gap(8).
		Background(t.Surface).BorderWidth(0, 0, 1, 0).BorderColor(t.Border). // 底部分隔线
		DragWindow().Children(func() {
		ui.Text(c, "mygo rounded window").Bold().Grow(1)
		if chromeButton(c, "min", icons.Must("minus"), "最小化", false).Clicked() {
			a.win.Minimize() // 最小化
		}
		// 最大化 ↔ 还原：图标随状态切换（方框 ↔ 双方框）。
		max := a.win != nil && a.win.IsMaximized()
		icon, label := icons.Must("square"), "最大化"
		if max {
			icon, label = icons.Must("copy"), "还原"
		}
		if chromeButton(c, "max", icon, label, false).Clicked() {
			if max {
				a.win.Unmaximize() // 还原
			} else {
				a.win.Maximize() // 最大化
			}
		}
		if chromeButton(c, "close", icons.Must("x"), "关闭", true).Clicked() {
			// 不能在视图构建期间直接 Close()：那会在窗口自己的渲染
			// 回调栈上拆毁它，GTK 会段错误（Linux 后端的 bug）。
			// Update 把关闭推迟到当前帧回调结束之后。
			a.win.Update(func() { a.win.Close() })
		}
	})
}

// chromeButton 画一个无边框的窗口控制按钮：平时只有图标，hover 才出现
// 背景；danger 为 true 时（关闭键）hover 变红。label 是无障碍名称。
func chromeButton(c *ui.Context, key string, icon *ui.SVG, label string, danger bool) ui.Element {
	t := c.Theme()
	// c.Key 给控件稳定标识：可聚焦控件都需要（跨帧对上号）。
	b := ui.ButtonBase(c.Key(key)).Size(28, 28).Radius(4).Label(label)
	bg, fg := ui.Color{}, t.Text // 默认：透明底 + 正常文字色
	switch {
	case danger && b.Pressed():
		bg, fg = closeRed.Mix(ui.Hex("#000000"), 0.25), ui.Hex("#ffffff") // 按下加深
	case danger && b.Hovered():
		bg, fg = closeRed, ui.Hex("#ffffff")
	case b.Pressed():
		bg, fg = t.SurfacePressed, t.Text
	case b.Hovered():
		bg, fg = t.SurfaceHover, t.Text
	}
	b.Background(bg).TextColor(fg)
	b.Children(func() { ui.Icon(c, icon).Size(16, 16) })
	return b
}

```

> [!note] 高亮的前三行是关键代码

{{< image src="/golang/mygo1.png" caption="深色背景效果演示" >}}

> [!warning] 如果`Transparent`为`false`，则四角不透明，无法实现圆角效果

{{< image src="/golang/mygo2.png" caption="浅色背景效果演示，能看到四个黑色直角" >}}

> [!tip] 实现无边框窗口，只需要注释掉最后一行高亮的代码即可

{{< image src="/golang/mygo3.png" caption="白色背景无边框效果演示，左右下三个方向全和背景融为一体了" >}}

{{< image src="/golang/mygo4.png" caption="白色背景有边框效果演示" >}}

```text {name="go.mod"}
module mygo-demo

go 1.27.3

require github.com/egoist/mygo v0.6.3

require (
	github.com/ebitengine/purego v0.11.1 // indirect
	github.com/go-text/typesetting v0.3.5 // indirect
	golang.org/x/image v0.46.0 // indirect
	golang.org/x/net v0.59.0 // indirect
	golang.org/x/text v0.43.0 // indirect
)

```
