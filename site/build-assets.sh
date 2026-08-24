#!/bin/sh
set -eu

src="${1:-/src}"
out="${2:-/out}"
assets="$out/assets"

rm -rf "$out"
mkdir -p "$assets"
cp "$src/index.html" "$src/robots.txt" "$src/sitemap.xml" "$out/"

for source in "$src"/*.svg "$src"/social-card.png; do
    [ -f "$source" ] || continue
    name="$(basename "$source")"
    ext=".${name##*.}"
    stem="${name%$ext}"
    hash="$(sha256sum "$source" | cut -c1-12)"
    target="$stem.$hash$ext"
    cp "$source" "$assets/$target"
    cp "$source" "$out/$name"
    sed -i "s#/$name#/assets/$target#g" "$out/index.html"
done
