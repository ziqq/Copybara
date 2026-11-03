<!-- Copyright (c) 2026 Anton Ustinoff. Use and redistribution are subject to LICENSE. -->

# Copybara landing

Public origin: https://copybara.ustinoff.dev. GitHub Pages serves the output
of `.github/workflows/landing.yml` from `main`, using the GitHub Actions source.

The site uses Nunjucks, SCSS, TypeScript and Vite. English lives at `/`, Russian
at `/ru/`; each locale includes a privacy page. System fonts and local images
avoid third-party scripts, fonts and analytics.

```sh
npm ci
npm run landing:dev
npm run landing:build
```

The build produces `dist/landing`, checks TypeScript and validates local HTML
and CSS references. Generated output and dependencies are ignored by Git.
Copy and links live in `landing/src/i18n/` and `landing/src/data.ts`.

The six JPEGs under `docs/appstore/screenshots/web/` are derivatives of the
native EN/RU App Store compositions. Update those source images before building.

Configure the custom domain in GitHub Pages before creating its DNS record:
`copybara CNAME ziqq.github.io.`. Keep existing domain records intact. Once
GitHub issues the certificate, enable HTTPS enforcement and verify `/`, `/ru/`,
`/privacy.html` and `/ru/privacy.html` over HTTPS. The workflow never publishes
an application release or submits an App Store build.
