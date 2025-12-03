---
title: SolidJS router template
date: 2025-11-22T17:28:02+08:00
draft: false
comment: true
weight: 0
hiddenFromHomePage: false
hiddenFromSearch: false
hiddenFromRss: false
hiddenFromRelated: false
description: ""
toc: true
lastmod: 2025-11-22T17:28:02+08:00
math: false
lightgallery: false
summary: "身为一个对前端感兴趣的菜鸡小卡拉米，尽管大模型写前端已经非常厉害了，但还是想手动记一些笔记，本篇博客记录一个简单的solidjs router模板"
categories:
  - misc
---

{{<link "https://docs.solidjs.com/solid-router/" "Solid Router" "" true>}}

`Solid Router`支持基于配置的路由和组件路由，使用哪种方式全看个人喜好

## 项目结构

初始化一个项目，使用 `pnpm add @solidjs/router` 下载依赖，精简项目结构，`src`目录下只有这几个文件，其中`Hello.tsx`用来演示延迟加载

```bash {title="tree src/"}
src
├── App.tsx
├── env.d.ts
├── NotFound.tsx
└── index.tsx
```

```tsx {title="src/NotFound.tsx"}
import type { JSX } from "solid-js";

export default function NotFound(): JSX.Element {
  return <div>PageNotFound</div>;
}
```

## 基于配置的路由

下面代码中通过 `*` 定义404页面并演示延迟加载。

通过 `routes`定义路由，注意跟路由的组件 `Layout` 作为布局组件，可以添加 `Header` 和 `Footer`，然后只切换中间区域

如果没有第一个子路由，直接访问 `/` 会发现找不到任何路由

```tsx {title="src/index.tsx" hl_lines=[10,15]}
import {
  Router,
  type RouteDefinition,
  type RouteSectionProps,
} from "@solidjs/router";
import type { JSX, JSXElement } from "solid-js";
import { lazy } from "solid-js";
import { render } from "solid-js/web";

function Layout(props: RouteSectionProps): JSXElement {
  return (
    <>
      <header>header</header>
      <hr />
      {props.children}
      <hr />
      <footer>footer</footer>
    </>
  );
}

const root = document.getElementById("root");
if (!root) {
  throw new Error("root not found");
}

function Child2(): JSX.Element {
  return <div>Child2</div>;
}

function Child1(): JSX.Element {
  return <div> Child1</div>;
}

function Main(): JSXElement {
  return <div>Main</div>;
}

const routes: RouteDefinition[] = [
  {
    path: "/",
    component: Layout,
    children: [
      {
        path: "",
        component: Main,
      },
      {
        path: "/child1",
        component: Child1,
      },
      {
        path: "/child2",
        component: Child2,
      },
    ],
  },
  {
    path: "*",
    component: lazy(() => import("./NotFound")),
  },
];

render(() => <Router children={routes} />, root);
```

## 组件路由

组件路由和基于配置的路由区别不大，想访问根路由依然需要定义高亮的那行路由

```tsx {title="src/index.tsx" hl_lines=[39]}
import { Route, Router, type RouteSectionProps } from "@solidjs/router";
import type { JSXElement } from "solid-js";
import { render } from "solid-js/web";
import NotFound from "./NotFound.tsx";

function Layout(props: RouteSectionProps): JSXElement {
  return (
    <>
      <header>header</header>
      <hr />
      {props.children}
      <hr />
      <footer>footer</footer>
    </>
  );
}

const root = document.getElementById("root");
if (!root) {
  throw new Error("root not found");
}

function Child2(): JSXElement {
  return <div>Child2</div>;
}

function Child1(): JSXElement {
  return <div> Child1</div>;
}

function Main(): JSXElement {
  return <div>Main</div>;
}

function RouterComponent(): JSXElement {
  return (
    <Router>
      <Route path="/" component={Layout}>
        <Route path="/" component={Main} />
        <Route path="child1" component={Child1} />
        <Route path="child2" component={Child2} />
      </Route>

      <Route path="*" component={NotFound} />
    </Router>
  );
}

render(RouterComponent, root);
```

> [!tip]
> 官网还展示了根级布局，下面演示一下

```tsx
import { Route, Router } from "@solidjs/router";
import { type JSX, type JSXElement } from "solid-js";
import { render } from "solid-js/web";

const root = document.getElementById("root");
if (!root) {
  throw new Error("root not found");
}

function Home(): JSX.Element {
  return <div>"Home"</div>;
}
function About(): JSX.Element {
  return <div>"About"</div>;
}

function Layout(props: { children?: JSXElement }): JSXElement {
  return (
    <>
      <header>Header</header>
      {props.children}
      <footer>Footer</footer>
    </>
  );
}

function RouterComponent(): JSXElement {
  return (
    <Router root={Layout}>
      <Route path="/" component={Home} />
      <Route path="/about" component={About} />
    </Router>
  );
}

render(() => <RouterComponent />, root);
```

## 路径参数

使用 `Typescript` 声明 `useParams` 的泛型类型时，需要在 `interface` 类型定义中添加 [第13行](#param-13)

```tsx {title="src/index.tsx" hl_lines=[13,15] anchorLineNos=true lineAnchors="param"}
import { Route, Router, useParams } from "@solidjs/router";
import { type JSXElement } from "solid-js";
import { render } from "solid-js/web";

const root = document.getElementById("root");
if (!root) {
  throw new Error("root not found");
}

function Child2(): JSXElement {
  interface Param {
    id: string;
    [key: string]: string;
  }
  const param = useParams<Param>();
  return <>{param.id}</>;
}

function RouterComponent(): JSXElement {
  return (
    <Router>
      <Route path="/">
        <Route path="child2/:id" component={Child2} />
      </Route>
    </Router>
  );
}

render(() => <RouterComponent />, root);
```
