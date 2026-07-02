# Kamiertop Blog

Personal blog powered by [Hugo](https://gohugo.io/) and the [FixIt](https://github.com/hugo-fixit/FixIt) theme.

The site uses Hugo Modules instead of a Git submodule. Theme dependency is managed by `go.mod` / `go.sum`, and site configuration is split under `config/_default/`.

## Requirements

- Git
- Go, matching `go.mod`
- Hugo Extended, `0.163.3` or compatible
- Dart Sass, `1.97.1` or compatible

## Local Development

Clone the repository:

```bash
git clone git@github.com:kamiertop/kamiertop.github.io.git
cd kamiertop.github.io
```

Download module dependencies:

```bash
hugo mod get
```

Start the local server:

```bash
hugo server --disableFastRender
```

Build the site:

```bash
hugo --gc --minify
```

## Writing

Create a new post:

```bash
hugo new content posts/misc/new-post.md
```

Most content lives in `content/posts/`. After editing or adding posts, push to `main`; GitHub Actions will build and deploy the site to GitHub Pages.

## Theme

FixIt is imported as a Hugo Module in `config/_default/module.toml`:

```toml
[[imports]]
path = "github.com/hugo-fixit/FixIt"
```

The actual pinned version is recorded in `go.mod`. This repository tracks the FixIt `v1` branch through a pseudo-version.

Fetch the latest `v1` branch commit:

```bash
git ls-remote https://github.com/hugo-fixit/FixIt.git refs/heads/v1
```

Use the returned commit SHA to update the module:

```bash
hugo mod get github.com/hugo-fixit/FixIt@<commit-sha>
hugo mod tidy
```

Do not use `@v1` here. Go treats `v1` as a semantic version query, not as the FixIt Git branch name.

After updating, run a local build before committing:

```bash
hugo --gc --minify
```

## Deployment

Deployment is handled by `.github/workflows/deploy.yml`.

The workflow runs on pushes to `main` when site-related files change, including:

- `content/**`
- `assets/**`
- `config/**`
- `layouts/**`
- `static/**`
- `archetypes/**`
- `go.mod`
- `go.sum`

It can also be started manually from the GitHub Actions page.

## Project Layout

```text
config/_default/   Hugo configuration
content/posts/     Blog posts
assets/            Site assets and custom JavaScript/CSS
layouts/           Local layout overrides
static/            Static files copied as-is
archetypes/        Content templates
```
