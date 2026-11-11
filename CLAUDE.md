# CLAUDE.md — Lavkoo GCC (Seller Flutter)

This is the **Seller Flutter** application. The product/repository was renamed; **do not automatically rename package IDs, bundle IDs, Firebase settings, imports or version numbers**. Existing code remains authoritative.

## Shared GCC plan and multi-Claude handoffs

Canonical backend/planning repository: `fullstackfull/lavkoo`

Read in order at the beginning of every Claude session:

1. https://github.com/fullstackfull/lavkoo/blob/main/docs/gcc/README.md
2. https://github.com/fullstackfull/lavkoo/blob/main/docs/gcc/DECISIONS.md
3. https://github.com/fullstackfull/lavkoo/blob/main/docs/gcc/STATUS.md
4. https://github.com/fullstackfull/lavkoo/blob/main/docs/gcc/COLLABORATION.md
5. https://github.com/fullstackfull/lavkoo/blob/main/docs/gcc/DISCOVERY_PROMPT_01.md

## Session protocol

- GitHub is the shared source of truth across Claude accounts. Check newest handoffs and remote HEAD SHAs, never rely on chat memory.
- GCC phase is **DISCOVERY / static audit only**, with only Markdown audit/handoff writing allowed. No Flutter source edits, backend edits, server/DB changes, deployments, merges or builds until explicitly approved.
- Immediately commit and push each completed documentation checkpoint to GitHub, confirm remote commit SHA and provide link. Canonical multi-repo audit reports belong under `fullstackfull/lavkoo/docs/gcc/audits/`.
- Do not overwrite another agent's reports; write a timestamped handoff in canonical `docs/gcc/handoffs/`.
- Preserve cross-repo API contracts and existing login, payments, notifications, theme, vendor workflows and current app version gating.
- Coordinate approved implementation with backend/customer/seller repositories via workstream-specific branches and PRs. GitHub push is NOT production deployment.

**Do not modify this app's internals as part of GCC documentation setup.**

## GCC-20 — Owner Super Admin Mode

The owner requires this same app to support a **distinct platform Super Admin experience** alongside the existing seller/staff experience. Read https://github.com/fullstackfull/lavkoo/blob/main/docs/gcc/GCC-20-SUPER-ADMIN-MOBILE.md and the central GCC decisions and discovery prompt. During discovery, audit existing seller login, seller guards, control tower, country drilldown and safe platform-admin authentication. **Do not reuse seller tokens for admin access or implement application changes yet.**
