## CURRENT OWNER INSTRUCTION — STANDING DEVELOPMENT DELEGATION (2026-11-12)

**Read first, before the older DISCOVERY ONLY text below:** https://github.com/fullstackfull/lavkoo/blob/main/docs/gcc/AUTONOMOUS_DEVELOPMENT_CHARTER.md

The owner has approved **continuous independent development** on isolated feature branches across all three LAVKOO repositories. This later written authorization overrides earlier Discovery-only / single-test-PR approval limits **for branch coding, isolated testing, CI repair, and reviewed immediate pushes/draft PRs**. Do **not** repeatedly ask the owner to approve routine coding decisions. Choose safe reversible technical solutions, implement real code in small increments, self-review, commit and push immediately, open draft PRs, then continue another independent task.

**Still forbidden without separate approval:** merging into main, production deploy/release, production DB access/migration/export/backup, real payments/shipping, credentials rotation, force-push or history rewrite, destructive financial/data changes, weakening security gates. G0 stays open and GCC implementation must not merge/release before its gates. For financial/security-sensitive work, development in a feature branch is permitted, but merging/release requires appropriate review. No seller app version change without verified release/minimum evidence. Preserve Saudi behavior and six-market approved design.

This instruction is **active now**. The historical restrictions and existing audit requirements below are preserved for record, but any conflicting blanket ban on isolated coding is superseded by this signed owner delegation.

---
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
