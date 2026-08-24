# WakeBar

- `WakeBar.swift` is the macOS app.
- `site/` is the static product site.
- Keep the app and site small; avoid adding build systems unless required.
- Shared OhRats styles/behavior come from `assets.ohrats.party`.
- Keep the site preview consistent with the actual menu labels and behavior in `WakeBar.swift`.
- Site HTML revalidates. Stable local asset URLs redirect to content-fingerprinted `/assets/*` files cached immutably; do not add manual `?v=` cache busting.
- Build locally with Xcode command-line tools; tagged releases are signed/notarized by `.github/workflows/build.yml`.
- Never expose signing keys, certificates, passwords, or GitHub secret values.
- Homebrew packaging is maintained in `OhRats-Technologies/homebrew-tap`.
