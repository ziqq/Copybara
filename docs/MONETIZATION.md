# Copybara — Monetization

Strategy for funding Copybara without compromising its principles. This is a
planning document; nothing here is implemented yet. Decisions are marked
**TBD** — pick them when ready and this doc becomes the spec.

## Principles (non-negotiable)

- **Stay open source (MIT).** The source is free to read, build, and fork.
- **Local-only stays local.** Monetization must never require an account,
  telemetry, ads, or sending clipboard data anywhere. Privacy is the product.
- **No dark patterns.** No nag screens on a paid-but-unpaid loop, no crippling
  the free tier into uselessness, no hostage-taking of the user's own history.
- **The free tier is genuinely useful** on its own — the current v0.2 feature set
  is the baseline and stays free.

## Distribution channels

Distribution requires a **paid Apple Developer account ($99/yr)** — the only hard
cost, needed for notarization and the Mac App Store regardless of price. See
[`RELEASE.md`](RELEASE.md).

| Channel | Audience | Notes |
|---|---|---|
| Build from source (GitHub) | developers | free, always |
| DMG via GitHub Releases | power users | free; on-demand in-app update check |
| Mac App Store | everyone | trust, discoverability, auto-updates, sandbox |
| Direct download (Gumroad) | supporters | optional pay-what-you-want |

## Models considered

### A. Donations (no paywall)
Free everywhere; fund via GitHub Sponsors / "Buy Me a Coffee" / an in-app tip jar.
- **Pros:** maximum adoption and goodwill; simplest; fits the ethos.
- **Cons:** low, unpredictable revenue.

### B. Paid App Store, free source
A small one-time price on the Mac App Store (pay for convenience: notarized,
auto-updating, sandboxed), while the source and DMG stay free.
- **Pros:** steady trickle; honest ("pay if you want the easy button").
- **Cons:** modest revenue; some friction on discovery.

### C. Freemium (free core + one-time Pro IAP) — *recommended target*
Everything shipped so far stays free. A one-time **Pro** in-app purchase unlocks
opt-in extras. Never a subscription unless a real recurring cost appears (a sync
backend).
- **Pros:** clear value exchange; scales with the app; keeps the free tier strong.
- **Cons:** needs a licensing/entitlement layer; must keep the free/Pro split fair.

### D. Subscription — *not recommended*
Only justifiable if Copybara ever runs a hosted service (cross-device sync). A
simple local utility should not rent itself.

## Candidate "Pro" features (Model C)

Things people happily pay once for, that don't break the local-only promise:

- **iCloud sync** of history/pins across your Macs (CloudKit — still the user's
  own iCloud, no third-party server). *Highest-value; also the only thing that
  could justify a subscription later.*
- **Snippets / templates** with placeholders.
- **Unlimited history** + advanced retention rules.
- **Custom themes / appearance** (accent, popup size, density).
- **Advanced rules:** per-app ignore/allow, transform-on-paste (trim, case, JSON
  pretty-print), regex replacements.
- **Multiple pasteboards / stacks.**

Free tier keeps: text/image/RTF/file capture, search (fuzzy/exact/regex), paste,
pin/delete, privacy filters, launch-at-login — i.e. everything today.

## Recommended phased plan

1. **Phase 0 — now (free, pre-account):** open source, build-from-source, personal
   use. Add a `FUNDING.yml` / Sponsors button and a Buy-Me-a-Coffee link when
   ready. No code needed.
2. **Phase 1 — first release (Model A):** ship a DMG via GitHub Releases (the
   tag-based workflow already exists) with the on-demand update check; optionally
   pay the $99 to notarize and add a free Mac App Store build. Donation-funded.
3. **Phase 2 — if there's traction (Model C):** add a one-time **Pro** IAP with
   the first 1–2 Pro features (iCloud sync is the flagship). Introduce a small
   licensing layer (StoreKit 2) and Pro feature flags.

## Technical groundwork (for Phase 2)

Kept minimal and inert until a model is chosen:

- A `ProEntitlements` gate (single source of truth: `isPro`), defaulting to
  `true` in DEBUG and `false` otherwise, read by any Pro-gated feature.
- StoreKit 2 purchase/restore flow behind that gate (App Store) — or a license-key
  check for direct sales.
- Feature flags so Pro features degrade gracefully to the free behavior.

None of this ships until **TBD: model chosen** (A / B / C).

## Open decisions (TBD)

- [ ] Model: **A**, **B**, or **C**? (recommend A → C.)
- [ ] Price point (if B/C): one-time, ~$4.99–$9.99.
- [ ] First Pro feature (if C): iCloud sync vs snippets.
- [ ] Funding links: GitHub Sponsors, Buy Me a Coffee, Gumroad?
- [ ] App Store: free with Pro IAP, or paid upfront?

## Guardrails

- Never gate a security/privacy feature behind Pro (blocklist, concealed-type
  filtering, clear-history stay free).
- Never add analytics/tracking to justify pricing.
- A purchased Pro license is restorable and tied to the user's Apple ID (App
  Store) or a license key (direct) — no online check that can lock people out.
