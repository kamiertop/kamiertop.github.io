#!/usr/bin/env bash
# Generate light/dark Chroma styles and wire them into assets/scss/custom.scss.
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  printf 'Usage: %s <chroma-theme>\n' "${0##*/}" >&2
  printf '       %s default\n' "${0##*/}" >&2
  exit 2
fi

input_theme=$1
if [[ ! "$input_theme" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'Invalid theme name: %s\n' "$input_theme" >&2
  exit 2
fi

root=$(cd "$(dirname "$0")/.." && pwd)
custom="$root/assets/scss/custom.scss"
marker_start='// BEGIN generated Chroma theme (do not edit)'
marker_end='// END generated Chroma theme'

if [[ "$input_theme" == "default" || "$input_theme" == "reset" ]]; then
  tmp_custom=$(mktemp)
  awk -v start="$marker_start" -v end="$marker_end" \
    '$0 == start { skip=1; next } $0 == end { skip=0; next } !skip { print }' \
    "$custom" > "$tmp_custom"
  mv "$tmp_custom" "$custom"
  printf 'Reset Chroma theme imports in %s\n' "$custom"
  exit 0
fi

# Chroma's light and dark themes usually have different names. The argument may
# be either side of a pair; files are placed under the name supplied by the user.
light_theme=''
dark_theme=''
case "$input_theme" in
  catppuccin-latte|catppuccin-mocha) light_theme=catppuccin-latte; dark_theme=catppuccin-mocha ;;
  github|github-dark) light_theme=github; dark_theme=github-dark ;;
  gruvbox-light|gruvbox) light_theme=gruvbox-light; dark_theme=gruvbox ;;
  kanagawa-lotus|kanagawa-wave) light_theme=kanagawa-lotus; dark_theme=kanagawa-wave ;;
  modus-operandi|modus-vivendi) light_theme=modus-operandi; dark_theme=modus-vivendi ;;
  monokailight|monokai) light_theme=monokailight; dark_theme=monokai ;;
  paraiso-light|paraiso-dark) light_theme=paraiso-light; dark_theme=paraiso-dark ;;
  rose-pine-dawn|rose-pine) light_theme=rose-pine-dawn; dark_theme=rose-pine ;;
  solarized-light|solarized-dark) light_theme=solarized-light; dark_theme=solarized-dark ;;
  tokyonight-day|tokyonight-night) light_theme=tokyonight-day; dark_theme=tokyonight-night ;;
  xcode|xcode-dark) light_theme=xcode; dark_theme=xcode-dark ;;
  *) printf 'Unsupported theme pair: %s\n' "$input_theme" >&2; exit 2 ;;
esac

out_dir="$root/assets/scss/$input_theme"
mkdir -p "$out_dir"

# Hugo's --modeSelector emits `.dark`. FixIt uses data-theme-mode instead.
# Prefix selectors with FixIt's code-block scope so they override its defaults.
scope_light() {
  sed -E 's/\.chroma/\.single .highlight .chroma/g; s/\.bg/\.single .highlight .bg/g'
}
scope_dark() {
  sed -E "s/\.chroma/\.single .highlight .chroma/g; s/\.bg/\.single .highlight .bg/g"
}
hugo gen chromastyles --style="$light_theme" --mode=light > "$out_dir/highlight.scss"
scope_light < "$out_dir/highlight.scss" > "$out_dir/.highlight.scss.tmp" && mv "$out_dir/.highlight.scss.tmp" "$out_dir/highlight.scss"
tmp_dark=$(mktemp)
trap 'rm -f "$tmp_dark"' EXIT
hugo gen chromastyles --style="$dark_theme" --mode=dark --modeSelector > "$tmp_dark"
sed "s/\\.dark /[data-theme-mode='dark'] /g" "$tmp_dark" | scope_dark > "$out_dir/highlight-dark.scss"
# In FixIt's `auto` mode, follow the operating system's dark preference too.
{
  printf '\n@media (prefers-color-scheme: dark) {\n'
  sed "s/\\.dark /[data-theme-mode='auto'] /g; s/\.chroma/.single .highlight .chroma/g; s/\.bg/.single .highlight .bg/g" "$tmp_dark"
  printf '}\n'
} >> "$out_dir/highlight-dark.scss"

tmp_custom=$(mktemp)
trap 'rm -f "$tmp_dark" "$tmp_custom"' EXIT
awk -v start="$marker_start" -v end="$marker_end" \
  '$0 == start { skip=1; next } $0 == end { skip=0; next } !skip { print }' \
  "$custom" > "$tmp_custom"
{
  printf '%s\n' "$marker_start"
  printf '@use "%s/highlight";\n' "$input_theme"
  printf '@use "%s/highlight-dark";\n' "$input_theme"
  printf '%s\n\n' "$marker_end"
  cat "$tmp_custom"
} > "$custom"
rm -f "$tmp_custom"

printf 'Generated %s (%s) and %s (%s)\n' \
  "$out_dir/highlight.scss" "$light_theme" "$out_dir/highlight-dark.scss" "$dark_theme"
printf 'Updated %s\n' "$custom"
