# WakeBar

- `WakeBar.swift` is the macOS app.
- `site/` is the static product site.
- Keep the app and site small; avoid adding build systems unless required.
- Shared OhRats styles/behavior come from `assets.ohrats.party`.
- Follow cross-product UI guidance in `../handbook/design/ui.md`; when review feedback generalizes, promote it there/shared UI instead of keeping a one-off local fix.
- Keep the site preview consistent with the actual menu labels and behavior in `WakeBar.swift`.
- Site HTML revalidates. Product assets are referenced by content-fingerprinted `/assets/*` URLs cached immutably; do not add unhashed aliases, redirects, or manual `?v=` cache busting.
- Build locally with Xcode command-line tools; tagged releases are signed/notarized by `.github/workflows/build.yml`.
- Never expose signing keys, certificates, passwords, or GitHub secret values.
- Homebrew packaging is maintained in `OhRats-Technologies/homebrew-tap`.
