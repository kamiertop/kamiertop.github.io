#!/usr/bin/env python3
"""Generate paired light/dark Chroma SCSS themes for the FixIt theme."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


THEME_PAIRS = {
    "catppuccin-latte": "catppuccin-mocha",
    "github": "github-dark",
    "gruvbox-light": "gruvbox",
    "kanagawa-lotus": "kanagawa-wave",
    "modus-operandi": "modus-vivendi",
    "monokailight": "monokai",
    "paraiso-light": "paraiso-dark",
    "rose-pine-dawn": "rose-pine",
    "solarized-light": "solarized-dark",
    "tokyonight-day": "tokyonight-night",
    "xcode": "xcode-dark",
}


def pair_for(theme: str) -> tuple[str, str]:
    for light, dark in THEME_PAIRS.items():
        if theme == light or theme == dark:
            return light, dark
    raise ValueError(f"unsupported theme pair: {theme}")


def run_hugo(theme: str, *args: str) -> str:
    command = ["hugo", "gen", "chromastyles", f"--style={theme}", *args]
    result = subprocess.run(command, check=True, text=True, capture_output=True)

    return result.stdout


def scope_light(css: str) -> str:
    return css.replace(".chroma", ".single .highlight .chroma").replace(
        ".bg", ".single .highlight .bg"
    )


def scope_dark(css: str, mode: str) -> str:
    css = css.replace(".dark ", f"[data-theme-mode='{mode}'] ")
    return scope_light(css)


def update_custom_scss(path: Path, theme: str) -> None:
    start = "// BEGIN generated Chroma theme (do not edit)"
    end = "// END generated Chroma theme"
    content = path.read_text()
    pattern = rf"{re.escape(start)}.*?{re.escape(end)}\n?"
    generated = (
        f'{start}\n@use "{theme}/highlight";\n'
        f'@use "{theme}/highlight-dark";\n{end}\n\n'
    )
    if re.search(pattern, content, flags=re.DOTALL):
        content = re.sub(pattern, generated, content, count=1, flags=re.DOTALL)
    else:
        content = generated + content
    path.write_text(content)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {Path(sys.argv[0]).name} <chroma-theme>", file=sys.stderr)
        print(f"       {Path(sys.argv[0]).name} default", file=sys.stderr)
        return 2

    theme = sys.argv[1]
    root = Path(__file__).resolve().parent.parent
    custom_path = root / "assets" / "scss" / "custom.scss"
    if theme in {"default", "reset"}:
        content = custom_path.read_text()
        start = "// BEGIN generated Chroma theme (do not edit)"
        end = "// END generated Chroma theme"
        content = re.sub(rf"{re.escape(start)}.*?{re.escape(end)}\n?", "", content, count=1, flags=re.DOTALL)
        custom_path.write_text(content)
        print(f"Reset Chroma theme imports in {custom_path}")
        return 0
    if not re.fullmatch(r"[A-Za-z0-9_-]+", theme):
        print(f"invalid theme name: {theme}", file=sys.stderr)
        return 2
    try:
        light, dark = pair_for(theme)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2

    output_dir = root / "assets" / "scss" / theme
    output_dir.mkdir(parents=True, exist_ok=True)

    light_css = scope_light(run_hugo(light, "--mode=light"))
    dark_css = scope_dark(run_hugo(dark, "--mode=dark", "--modeSelector"), "dark")
    auto_css = scope_dark(run_hugo(dark, "--mode=dark", "--modeSelector"), "auto")
    (output_dir / "highlight.scss").write_text(light_css)
    (output_dir / "highlight-dark.scss").write_text(
        dark_css + "\n@media (prefers-color-scheme: dark) {\n" + auto_css + "}\n"
    )
    update_custom_scss(root / "assets" / "scss" / "custom.scss", theme)

    print(f"Generated {output_dir / 'highlight.scss'} ({light})")
    print(f"Generated {output_dir / 'highlight-dark.scss'} ({dark})")
    print(f"Updated {root / 'assets' / 'scss' / 'custom.scss'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
