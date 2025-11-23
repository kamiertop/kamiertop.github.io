---
title: solid router template
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
├── Hello.tsx
└── index.tsx
```

```tsx {title="src/Hello.tsx"}
import type { JSX } from "solid-js";

export default function Hello(): JSX.Element {
  return <div>"Hello, World!"</div>;
}
```

## 基于配置的路由

下面的代码中定义了3个路由，分别是：`/`（演示延迟加载）,`*`（通配符匹配）和`about`

```tsx {title="src/index.tsx" hl_lines=[27]}
import { render } from "solid-js/web";
import { Router, type RouteDefinition } from "@solidjs/router";
import { lazy } from "solid-js";
import type { JSX } from "solid-js";
const root = document.getElementById("root");

if (!root) {
  throw new Error("root not found");
}

function About(): JSX.Element {
  return <div>"About"</div>;
}
function NotFound(): JSX.Element {
  return (
    <div>
      <h1>404 - Page Not Found</h1>
      <p>The page you are looking for does not exist.</p>
    </div>
  );
}

const routes: RouteDefinition[] = [
  {
    path: "/",
    component: lazy(() => import("./Hello.tsx")),
    children: [],
  },
  {
    path: "/about",
    component: () => <About />,
  },
  {
    path: "*",
    component: () => <NotFound />,
  },
];

render(() => <Router children={routes} />, root);
```

上面代码演示了最基本的路由配置，下面演示嵌套路由/布局，就是一个页面的局部组件进行切换

下面代码高亮的第41行增加了子路由及其对应组件，此时我们有3个顶级的扁平`/child1`，`/about`，`*`，不再拥有`/`，
`Hello`组件成为了布局组件，当我们访问`/child1`时才会渲染出来`Hello.tsx`的内容

```tsx {title="src/index.tsx" hl_lines=[38,41]}
import { Router, type RouteDefinition } from "@solidjs/router";
import type { JSX } from "solid-js";
import { lazy } from "solid-js";
import { render } from "solid-js/web";

const root = document.getElementById("root");
if (!root) {
  throw new Error("root not found");
}

function About(): JSX.Element {
  return <div>"About"</div>;
}

function Child1(): JSX.Element {
  return <div>"Child1"</div>;
}
function NotFound(): JSX.Element {
  return (
    <div>
      <h1>404 - Page Not Found</h1>
      <p>The page you are looking for does not exist.</p>
    </div>
  );
}

const routes: RouteDefinition[] = [
  {
    path: "/",
    component: lazy(() => import("./Hello.tsx")),
    children: [
      {
        path: "child1",
        component: () => <Child1 />,
      },
    ],
  },
  {
    path: "/about",
    component: () => <About />,
  },
  {
    path: "*",
    component: () => <NotFound />,
  },
];

render(() => <Router children={routes} />, root);
```

作为布局组件，理应渲染子组件，此时通过修改`Hello.tsx`来实现，下面代码高亮的第7行用来渲染子组件

```tsx {title="src/Hello.tsx" hl_lines=[7]}
import type { JSX } from "solid-js";

export default function Hello(props: { children?: JSX.Element }): JSX.Element {
  return (
    <div>
      "Hello, World!"
      {props.children}
    </div>
  );
}
```

现在访问 `/child1`会看到下面内容，这就是布局组件的作用，只切换子组件，作为布局的内容不变

```text {.no-header lineNos=false}
"Hello, World"
"Child1"
```

## 组件路由

组件路由和基于配置的路由区别不大，这里只记录关键的代码，依然可以实现布局的功能

```tsx {title="src/index.tsx" hl_lines=[5]}
function RouterComponent(): JSXElement {
  return (
    <Router>
      <Route path="/" component={lazy(() => import("./Hello.tsx"))}>
        <Route path="child1" component={Child1} />
      </Route>
      <Route path="/about" component={About} />
      <Route path="*" component={NotFound} />
    </Router>
  );
}

render(() => <RouterComponent />, root);
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
