---
title: '在Linux中使用gpui component实现圆角窗口'
date: '2026-09-03T17:56:00+08:00'
draft: false
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
lastmod: '2026-09-03T17:56:00+08:00'
lightgallery: false
summary: "记录一下在Linux中使用gpui component实现圆角窗口的过程"
categories:
  - Rust
tags:
  - Rust
---

> [!summary] 准备使用[gpui](https://gpui.rs/)和[gpui component](https://github.com/longbridge/gpui-kit)开发一个本地的音乐播放器，想实现一个圆角窗口的效果，折腾好久总是差点意思，和AI斗智斗勇半天终于解决

## 思路

> [!success] 使用透明背景+自定义`TitleBar`+自定义`Panel`实现
> **实现一个类似于 `Zed` 编辑器的效果，全屏/最大化直角，非全屏/非最大化时为圆角**

## main

```rust {hl_lines=[32]}
mod app;
use gpui::{AppContext, Application, Styled, TitlebarOptions, WindowBackgroundAppearance, WindowBounds, WindowDecorations, WindowOptions};
use gpui::{px, size};
use gpui_component::Root;

fn main() {
    let app: Application = gpui_platform::application().with_assets(gpui_component_assets::Assets);

    app.run(move |cx| {
        gpui_component::init(cx);
        // 应用整体是深色外观，把组件主题切到 Dark，否则 Root 默认绘制浅色背景，
        // 会在窗口圆角处透出白边。
        gpui_component::Theme::change(gpui_component::ThemeMode::Dark, None, cx);
        let window_options = WindowOptions {
            // 1200x760 的窗口居中显示
            window_bounds: Some(WindowBounds::centered(size(px(1200.), px(760.)), cx)),
            // 最小尺寸为 900x560，防止窗口过小导致布局错乱
            window_min_size: Some(size(px(900.), px(560.))),
            // 使用客户端装饰，由 GPUI Component 绘制标题栏和窗口控制按钮。
            // 配合透明背景，根元素的圆角才能成为窗口最外层的可见边界。
            window_decorations: Some(WindowDecorations::Client),
            ..Default::default()
        };
        cx.spawn(async move |cx| {
            cx.open_window(window_options, |window, cx| {
                let view = cx.new(|_| app::App::default());
                cx.new(|cx| {
                    Root::new(view, window, cx)
                        // 不设置边框
                        .bordered(false)
                        // 根元素背景设为透明
                        .bg(gpui::transparent_black())
                })
            })
            .expect("Failed to open window");
        })
        .detach();
    });
}
```

## Render

```Rust
mod title_bar;
pub mod root;

use crate::{app::App, domain::LibraryView};
use gpui::prelude::FluentBuilder;
use gpui::*;
use gpui_component::{button::*, *};

/// 窗口圆角的唯一来源：标题栏顶角、关闭按钮右上角、主面板底角都从这里取值，
/// 改这一处三处圆角会一起跟着变，保证一致。
pub(crate) const WINDOW_RADIUS: Pixels = px(16.);

/// 窗口圆角值：全屏或最大化时返回直角（0），否则返回正常圆角。
/// 全屏与最大化是两个独立状态（`Window::is_fullscreen` / `is_maximized`），要一起判。
pub(crate) fn window_radius(window: &Window) -> Pixels {
    if window.is_fullscreen() || window.is_maximized() {
        px(0.)
    } else {
        WINDOW_RADIUS
    }
}

impl Render for App {
    fn render(&mut self, window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        let songs = self.library.tracks.len();
        let status = self
            .playback
            .current
            .as_ref()
            .map(|t| t.title.as_str())
            .unwrap_or("未播放");

        div()
            .v_flex()
            .size_full()
            .text_color(rgb(0xe5e7eb))
            // 从上向下排列，首先是TitleBar
            .child(title_bar::title_bar(window))
            // 其次是主面板，主面板控制左下角和右下角圆角
            .child(main_panel(self, songs, status, window))
    }
}

```

## `TitleBar`

gpui_component提供了`TitleBar`组件，但说实话，目前还不是很好用，很多样式无法设置，比如右上角的关闭按钮鼠标悬浮时默认是红色背景，直角边框。
当我们想使用圆角窗口时就会很不协调，所以需要自己实现一个`TitleBar`组件

```Rust {wrapper_class="is-collapsed"}
//! KTM Music 的应用顶部栏。
//!
//! 这里直接绘制标题栏和窗口控制按钮（最小化 / 最大化 / 关闭），而不是复用
//! `gpui_component::TitleBar`。原因是 GPUI 的 `overflow` 目前只做矩形裁剪，
//! 库内置的关闭按钮 hover 是直角方块，会把标题栏右上角的圆角顶穿。自己画
//! 才能给关闭按钮单独加 `rounded_tr`，让 hover 背景跟随窗口圆角。

use gpui::{px, InteractiveElement as _, IntoElement, div, Styled, rgb, ParentElement, WindowControlArea, MouseButton, FontWeight};
use gpui::StatefulInteractiveElement as _;
use gpui;
use gpui_component::InteractiveElementExt as _;
use gpui_component::{Icon, IconName, Sizable};

use super::window_radius;

/// 标题栏高度，窗口控制按钮的宽高与之保持一致（保持正方形）。
const TITLE_BAR_HEIGHT: gpui::Pixels = px(34.);

/// 创建应用顶部栏。
///
/// `window` 透传给窗口控制按钮（最大化按钮据此在内部切换图标）。
pub(crate) fn title_bar(window: &gpui::Window) -> impl IntoElement {
    div()
        .id("title-bar")
        .flex()
        .items_center()
        .h(TITLE_BAR_HEIGHT)
        .flex_shrink_0()
        // 顶部两个角圆角：窗口左上/右上角由这里决定，需与主面板底部圆角一致。
        .bg(rgb(0x181b21))
        .border_color(rgb(0x2a303a))
        .text_color(rgb(0xe5e7eb))
        // 双击标题栏空白处切换最大化 / 还原。
        .on_double_click(|_, window, _| window.zoom_window())
        .child(
            div()
                .id("title-bar-drag")
                .flex()
                .items_center()
                .gap_3()
                .flex_1()
                .h_full()
                .pl_3()
                .window_control_area(WindowControlArea::Drag)
                .on_mouse_down(MouseButton::Left, |_, window, _| {
                    window.start_window_move()
                })
                .on_mouse_down(MouseButton::Right, |event, window, _| {
                    window.show_window_menu(event.position)
                })
                .child(div().font_weight(FontWeight::BOLD).child("KTM Music")),
        )
        .child(
            div()
                .id("window-controls")
                .flex()
                .items_center()
                .h_full()
                .flex_shrink_0()
                .child(minimize_button())
                .child(maximize_button(window))
                .child(close_button(window)),
        )
        .rounded_t(window_radius(window))
}

/// 最小化按钮。灰底 hover，不贴窗口角落，无需圆角。
fn minimize_button() -> impl IntoElement {
    div()
        .id("minimize")
        .flex()
        .items_center()
        .justify_center()
        .w(TITLE_BAR_HEIGHT)
        .h_full()
        .flex_shrink_0()
        .text_color(rgb(0xe5e7eb))
        .hover(|style| style.bg(rgb(0x2a303a)))
        .active(|style| style.bg(rgb(0x2a303a)))
        // 阻止鼠标按下冒泡到标题栏，避免误触发窗口拖拽。
        .on_mouse_down(MouseButton::Left, |_, window, cx| {
            window.prevent_default();
            cx.stop_propagation();
        })
        .on_click(|_, window, cx| {
            cx.stop_propagation();
            window.minimize_window();
        })
        .child(
            Icon::new(IconName::WindowMinimize).small()
        )
}

/// 最大化 / 还原按钮。灰底 hover，不贴窗口角落，无需圆角。
/// 图标在组件内部根据窗口是否最大化，在「最大化 / 还原」间切换。
fn maximize_button(window: &gpui::Window) -> impl IntoElement {
    div()
        .id("maximize")
        .flex()
        .items_center()
        .justify_center()
        .w(TITLE_BAR_HEIGHT)
        .h_full()
        .flex_shrink_0()
        .text_color(rgb(0xe5e7eb))
        .hover(|style| style.bg(rgb(0x2a303a)))
        .active(|style| style.bg(rgb(0x2a303a)))
        // 阻止鼠标按下冒泡到标题栏，避免误触发窗口拖拽
        .on_mouse_down(MouseButton::Left, |_, window, cx| {
            window.prevent_default();
            cx.stop_propagation();
        })
        .on_click(|_, window, cx| {
            cx.stop_propagation();
            window.zoom_window();
        })
        .child(
            if window.is_maximized() {
                Icon::new(IconName::WindowRestore).small()
            } else {
                Icon::new(IconName::WindowMaximize).small()
            }
        )
}

/// 关闭按钮。贴在窗口右上角，必须给自己加 `rounded_tr` 圆角——
/// GPUI 的 overflow 只做矩形裁剪，子元素不会被父级圆角裁剪，
/// 不加这行，hover 背景就是直角方块，会顶穿窗口圆角。
fn close_button(window: &gpui::Window) -> impl IntoElement {
    div()
        .id("close")
        .flex()
        .items_center()
        .justify_center()
        .w(TITLE_BAR_HEIGHT)
        .h_full()
        .flex_shrink_0()
        .text_color(rgb(0xe5e7eb))
        .rounded_tr(window_radius(window))
        .hover(|style| style.bg(rgb(0x2a303a)).text_color(rgb(0xffffff)))
        .active(|style| style.bg(rgb(0x2a303a)).text_color(rgb(0xffffff)))
        // 阻止鼠标按下冒泡到标题栏，避免误触发窗口拖拽。
        .on_mouse_down(MouseButton::Left, |_, window, cx| {
            window.prevent_default();
            cx.stop_propagation();
        })
        .on_click(|_, window, cx| {
            cx.stop_propagation();
            window.remove_window();
        })
        .child(Icon::new(IconName::WindowClose).small())
}
```

## `MainPanel`

```Rust {hl_lines=[8]}
fn main_panel(app: &App, songs: usize, status: &str, window: &Window) -> impl IntoElement {
    div()
        .v_flex()
        .flex_1()
        .p_8()
        .gap_6()
        .bg(rgb(0x101216))
        .rounded_b(window_radius(window))
}
```