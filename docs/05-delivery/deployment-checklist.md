---
title: 'Release, Security and Deployment Checklist'
package_doc_id: ECO-24
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§18–24'
prior_document_mapping: 'DOC-040; DOC-043'
priority_scope: 'QUALITY'
date: '2026-10-10'
---

# Release, Security and Deployment Checklist

> **Path:** `docs/05-delivery/deployment-checklist.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§18–24; legacy registry: DOC-040; DOC-043.  
> **Decision gates:** `DEC-006`, `DEC-007`, `DEC-011`, `DEC-012`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Document purpose
Operational preflight for deploy of Flutter app, Next.js admin and Supabase backend. These are **planned checks**, not tasks already completed. A demo build can be released only after the agreed P0 release gates pass.

## A — Before any deployment
- [ ] Owners and environment addresses confirmed in DEC-011.
- [ ] All P0-blocking decisions approved or explicit exclusions/fallbacks authorized.
- [ ] Git commit SHA, dependencies/lockfiles, SDK versions and migrations recorded.
- [ ] `.env*` files, tokens, signing materials and service-role credentials are not committed.
- [ ] Latest migrations applied in correct order to clean staging; clean rollback/restore path documented.
- [ ] RLS enabled, table grants reviewed, private bucket policies tested with real roles.
- [ ] Auth redirect URL(s), allowed origins, password-reset flows and staff/Admin bootstrap verified.

## B — Supabase and AI
- [ ] Production/staging database is not accidentally pointing at developer data.
- [ ] Gemini API key stored in Edge Function secrets only; no Flutter or public browser value.
- [ ] Edge deploy path authenticated and input bound; image ownership verified.
- [ ] Structured JSON validator rejects invalid category/severity/department.
- [ ] AI timeout, invalid output and quota failure trigger manual report entry.
- [ ] Data log redaction covers emails, tokens, private images and model payloads.
- [ ] Function retry, rate-limit and error responses confirmed.

## C — Flutter Android/iOS
- [ ] Package/bundle identifiers and signing profiles set, with ownership recorded.
- [ ] Camera/photos permission copy matches actual access; denial fallback works.
- [ ] Supabase Auth login/register/reset and session restore tested on target physical devices.
- [ ] Building/Floor/Area selection works without GPS permission.
- [ ] Student can save/edit AI suggestions and manually submit during outage.
- [ ] Upload flow preserves report on interruption/retry; test no duplicate submission.
- [ ] Report list/detail displays own updates and not other users' private content.
- [ ] Screens responsive, accessible and non-crashing on supported device sizes.

## D — Next.js Admin/Staff
- [ ] Production build succeeds with all type/lint/build checks.
- [ ] Admin routes require server-side role authorization and deny Student direct URLs.
- [ ] Staff can view/resolve only approved assignments; cross-department negatives pass.
- [ ] Changes update audited history and reporter-visible state correctly.
- [ ] Empty dashboard/zero-denominator charts render without misleading scores.
- [ ] Optional P1/P2 navigation is hidden/marked unavailable when not deployed.
- [ ] Resource/photo links do not expose unrestricted public storage access.

## E — Data integrity and reward logic
- [ ] REPORTED → ASSIGNED → IN_PROGRESS → RESOLVED workflow tested end to end.
- [ ] Rejected/Duplicate optional states only enabled when decisions approved.
- [ ] EcoPoints event repeats credit at most once and respect validity policy.
- [ ] P1 duplicate joins do not inflate rank/impact/score if deployed.
- [ ] Impact values carry `estimated`, units, method version and date range.
- [ ] Score model version and coefficients approved before numerical display.

## F — Observability, recovery and contingency
- [ ] Request IDs propagate from Flutter/admin to Edge Function and DB event where possible.
- [ ] Health/error dashboards show login, upload, API and failed transition issues without private content.
- [ ] Known-good web/backend revision available and rollback steps rehearsed.
- [ ] Backup of stateful data verified and restoration responsibility assigned.
- [ ] If FCM included: push permission denied/stale token tests pass; if excluded: UI still shows status.
- [ ] Backup demo video and local seeded screenshot deck prepared and labeled.

## G — Launch smoke test (minimum)
1. In a clean browser/mobile session, sign in as Demo Student.
2. Select/upload representative report photo; verify AI output or manual fallback.
3. Choose actual seeded Building → Floor → Area; submit and retain report ID.
4. Sign in as Admin; locate exact report, assign permitted department.
5. Sign in as matching Staff; move status to progress then resolved with note.
6. Sign back in as Student; verify status/history and eligible P0 points.
7. Check unauthorized student/staff access, API logs and user-visible estimate labels.
8. Record screenshots, commit, build and seeded dataset revision.

## Go/no-go record
```text
Release name / commit:
Env / URLs / build IDs:
Migration versions:
P0 smoke: PASS / FAIL / BLOCKED
Security/RLS: PASS / FAIL / BLOCKED
AI fallback: PASS / FAIL / BLOCKED
Open P0 issues:
Approved deferred P1/P2:
Approver / date:
Rollback owner and path:
Decision: GO / NO-GO
```


## Agent acceptance checklist (proposed)

- [ ] No production/demonstration release proceeds with open critical authorization issue.
- [ ] Smoke test completes core cross-role workflow.
- [ ] All optional feature claims match verified deployment capabilities.
- [ ] Rollback and source build IDs are recorded for operational recovery.
- [ ] Final go/no-go is signed by a human owner.

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
