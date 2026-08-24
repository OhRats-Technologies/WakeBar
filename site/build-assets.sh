#!/bin/sh
set -eu

src="${1:-/src}"
out="${2:-/out}"
assets="$out/assets"
redirects="$out/redirects.conf"

rm -rf "$out"
mkdir -p "$assets"
cp "$src/index.html" "$src/robots.txt" "$src/sitemap.xml" "$out/"
: > "$redirects"

for source in "$src"/*.svg "$src"/social-card.png; do
    [ -f "$source" ] || continue
    name="$(basename "$source")"
    ext=".${name##*.}"
    stem="${name%$ext}"
    hash="$(sha256sum "$source" | cut -c1-12)"
    target="$stem.$hash$ext"
    cp "$source" "$assets/$target"
    cat >> "$redirects" <<EOF
location = /$name {
    add_header Cache-Control "public, max-age=0, must-revalidate" always;
    add_header Cloudflare-CDN-Cache-Control "public, max-age=0, must-revalidate" always;
    return 307 /assets/$target;
}
EOF
done
