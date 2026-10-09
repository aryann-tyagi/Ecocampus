---
title: 'Environments, Secrets, Builds and Deployment Operations'
package_doc_id: ECO-14
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§18–20, 22, 24'
prior_document_mapping: 'DOC-040; DOC-043'
priority_scope: 'CROSS'
date: '2026-10-10'
---

# Environments, Secrets, Builds and Deployment Operations

> **Path:** `docs/03-engineering/deployment-env.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§18–20, 22, 24; legacy registry: DOC-040; DOC-043.  
> **Decision gates:** `DEC-006`, `DEC-007`, `DEC-011`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Environment strategy — proposed
| Environment | Purpose | Data | Secret policy |
|---|---|---|---|
| Local | Developer iteration (2 developers) | Local/test project or sanitized fixtures | `.env.local` untracked |
| Preview/staging | Integrated PR tests and demo rehearsal | Dedicated non-production campus seeded data | Separate project keys and service credentials |
| Production/demo | Judge session / controlled release | Approved seed+real pilot only if authorized | Rotation-ready deployment secrets |

**Source fact:** PRD chooses Supabase and Edge Functions, Flutter and Next.js; it does **not** name mobile signing service, Next.js host, domain, CI platform, regions, staging setup or FCM project. Record all under DEC-011.

## Configuration inventory (proposed names)
| Name | Consumer | Public? | Notes |
|---|---|---|---|
| `SUPABASE_URL` | Flutter/web | Yes | Project-specific endpoint |
| `SUPABASE_ANON_KEY` or publishable key | Flutter/web | Yes | Must be guarded by RLS; never use service-role |
| `SUPABASE_SERVICE_ROLE_KEY` | Trusted functions only | **No** | Never in client bundle |
| `GEMINI_API_KEY` | Edge Function only | **No** | Secrets manager, no logs |
| `FCM_*` server credential | Trusted notifier only | **No** | Only if push implemented |
| `NEXT_PUBLIC_*` | Next.js browser | Yes by definition | Never use for privileged credentials |
| `APP_ENV` | Backend/web/app | Safe identifier | Determine runtime-specific names |

## Suggested repository layout (implementation proposal)
```text
EcoCampus/
├── apps/mobile/          # Flutter
├── apps/admin/           # Next.js
├── supabase/functions/   # Gemini & controlled APIs
├── supabase/migrations/  # Postgres/RLS
├── docs/                 # versioned contracts
└── .github/workflows/    # CI if selected
```

## Setup and bootstrap checklist
1. Agree Node/Dart/Flutter SDK versions in lockfiles and tool version files.
2. Create Supabase project(s), local CLI config, auth redirect URLs, allowed origins and storage buckets.
3. Apply ordered migrations and RLS; run authenticated/unauthorized policy smoke tests.
4. Seed known campus Building/Floor/Area master data only after DEC-008.
5. Configure Gemini API server-side and check provider quota; validate manual fallback under outage.
6. Deploy Next.js to approved host with staging redirect and server/client secret audit.
7. Configure Flutter Android/iOS IDs/signing/notification permissions only if required; document devices tested.
8. Verify monitoring/correlation IDs and safe error messages before live demo.

## Proposed CI pipeline
`checkout → dependency lock validation → Flutter analyze/test → Next.js lint/typecheck/test/build → Edge Function lint/tests → SQL migration/RLS tests → secret scan → preview deploy (on PR) → human review → guarded merge → release smoke tests`.
Commands and versions must be fixed to actual repository once code exists; do not claim these CI checks already pass.

## Rollback/recovery plan
- Web: retain last known-good build deployment for rollback.
- Edge Functions: use versioned deploy and reversible config; no secret in code.
- DB: practice restoring from verified backup; for nonreversible schema changes prefer forward-fix migration and explicit recovery plan.
- Mobile: consider staged distribution and compatibility with backend schema; binary rollback differs from web.
- Demo: have sanitized offline video and seeded account fallback, but never misrepresent video as a live deployment.

## Release entry/exit gates
- Approved DEC-011 deployment owner, project URLs and environment boundary.
- No unapproved role/data access or secret leakage (DEC-006).
- P0 end-to-end demo passes from fresh seeded user and empty photo cache.
- Missing P1/P2 explicitly indicated, not faked.
- Source artifact, commit hash, migration versions, smoke results and rollback owner recorded.


## Agent acceptance checklist (proposed)

- [ ] No privileged key appears in Flutter or Next.js public bundle.
- [ ] A fresh environment can run migrations + seed data deterministically.
- [ ] Staging and production credentials/data are not intermingled.
- [ ] API/DB/mobile version compatibility and rollback procedure are recorded.
- [ ] Demo mode has truthful seeded-data disclosures.

## Agent execution protocol

1. Read this document together with the original PRD, approved decision register and relevant sibling specifications before modifying code.
2. Identify exact feature tier, acceptance scenarios, data ownership and denied-role tests. Distinguish requirements from proposed design choices.
3. Do not implement a blocked formula, privacy policy, status transition or reward event until the listed decision gate is approved.
4. Keep changes in a narrowly scoped branch/PR with migrations, typed contracts, automated tests, screenshots/log evidence and rollback considerations when relevant.
5. Verify behavior on an actual clean staging configuration. Record `PASS`, `FAIL`, `BLOCKED` or `NOT_RUN` against source-linked test IDs; never claim passing tests without running them.
6. Update the requirement traceability and decision record when contracts change; never silently renumber existing IDs.

## Source-backed requirement linkage

The rows below are extracted from the previously authored 217-row EcoCampus requirements traceability matrix. This is a **cross-reference**, not evidence of execution or approval.

| Requirement ID | Source statement (paraphrase) | PRD citation | Scope | Decision gate |
|---|---|---|---|---|
| `REQ-TECH-001` | Student application targets Android and iOS | §§18–19 | BASE | DEC-011 |

1 source-linked rows displayed of 1 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
