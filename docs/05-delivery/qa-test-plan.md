---
title: 'EcoCampus Test Strategy, Matrix and Release Gates'
package_doc_id: ECO-22
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§20, 23–25'
prior_document_mapping: 'DOC-035; DOC-036; DOC-037'
priority_scope: 'QUALITY'
date: '2026-10-10'
---

# EcoCampus Test Strategy, Matrix and Release Gates

> **Path:** `docs/05-delivery/qa-test-plan.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§20, 23–25; legacy registry: DOC-035; DOC-036; DOC-037.  
> **Decision gates:** `DEC-001`, `DEC-002`, `DEC-003`, `DEC-004`, `DEC-005`, `DEC-006`, `DEC-007`, `DEC-008`, `DEC-009`, `DEC-010`, `DEC-011`, `DEC-012`, `DEC-013`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Traceability and test policy
Existing `docs/00-control/requirements-traceability.md` defines **217 stable atomic requirement IDs** and 217 corresponding **proposed TEST IDs**, not executed tests. Use the IDs as regression inventory; this document defines test types, fixtures, priorities and evidence. No tests are claimed to have passed.

## Test layers — recommended
| Layer | Objective | Tool examples (choices not fixed by PRD) |
|---|---|---|
| Pure unit | Validators, severity mappings, score functions, point eligibility | Dart `flutter_test`, TypeScript unit runner |
| Widget/component | Forms, loading/error/empty states, accessible labels | Flutter widget tests, React testing library |
| API contract | JWT, input/output, rate limit, provider fallback, idempotency | HTTP contract tests |
| DB/RLS integration | Cross-account isolation, Staff assignment, mutation guards | SQL policies with real token contexts |
| E2E mobile+admin | Student submit → Admin assign → Staff resolve → Student track | Mobile/web test harness on staging |
| Security/abuse | Privilege escalation, unauthorized photo, replay attacks | AuthZ suite and secret scanning |
| Perf/reliability | Submission <60 sec, Gemini <10 sec, >95% success target | Tracing and repeatable synthetic runs |
| Human UAT/demo | Actual two-developer device walkthrough and judge rehearsal | Signed checklist, video with fixtures |

## P0 acceptance suites
| ID | Scenario | Expected oracle |
|---|---|---|
| QA-P0-01 | Register, login, logout, reset password | Correct identity lifecycle; no private stale cache |
| QA-P0-02 | Select photo from camera/gallery | Authorized image accessible only to owner/privileged staff |
| QA-P0-03 | Valid image classified by Gemini | Editable issue/category/severity/department/description |
| QA-P0-04 | Gemini 503/timeout/malformed JSON | Student continues with manual entry |
| QA-P0-05 | Building-floor-area mismatch | Submission blocked; hierarchy error shown |
| QA-P0-06 | Report submission repeated after timeout | No duplicate issue/points under approved idempotency |
| QA-P0-07 | Admin assigns department | Authorized transition and auditable history |
| QA-P0-08 | Staff from unrelated department attempts resolve | Access denied |
| QA-P0-09 | Staff resolves with approved note | Reporter sees new status/details |
| QA-P0-10 | Valid eligible EcoPoints event replayed | Awarded once, amount respects DEC-005 |
| QA-P0-11 | Dashboard empty data | Sensible zero/empty state, no invented score |
| QA-P0-12 | Student attempts server-side status edit | Denied by RLS/mutation API |

## P1/P2 suites
- Duplicate: same-location near text; different-building text; resolved candidate; redacted preview; join/report anyway; repeated join.
- Priority: numeric bounds, deterministic weights, factor monotonicity, override permission/audit, fallback sorting.
- Map: correct SVG key match, missing building, no geometry, accessible text list.
- Recurrence: per-period counts, duplicate collapse, thin data, timezone boundary.
- Eco Score/impact: formula version, no-data states, units, estimate disclosure, reopen adjustment.
- Leaderboard: ledger sum, month/campus rankings, ties, privacy and reversals.
- Advisor/What-If (P2): data evidence grounding, admin-only access, no live writes, scenario warning, injection handling.
- Advanced notifications (P2): delivery retries, deduplication, denied FCM permission, stale token cleanup.

## Non-functional measurement harness
| PRD metric | Instrumentation proposal | Reporting rule |
|---|---|---|
| Report <60 sec | Time from CTA to confirmation across declared device/network | Include test device and percentile; no unsupported universal claim |
| AI <10 sec | From analysis request until validated suggestions UI | Track failures/timeouts separately |
| Submission success >95% | `successful valid attempts / all valid attempts` in fixed run | State attempt definition and sample size |
| Student status visibility | Verify own report refetch after admin change | Test permission and stale realtime |
| Impact estimation | Check supported resolved issue and labeling | Tests only after DEC-009 coefficients approved |
| Hotspot detection | Verify seeded trend returned | Tests only when P1 feature enabled |

## Required security negatives
- Student A cannot retrieve B's report and photograph, direct URL or crafted database query.
- Student cannot set role=admin, modify points, assign department or change status.
- Staff cannot alter unassigned issues or read unrelated internal notes.
- API with invalid/missing JWT gets denied and reveals no hints about private records.
- Gemini key/service-role secret never appears in client bundle or logs.
- Provider text and image descriptions cannot become executable SQL or HTML injection.

## Evidence format — proposed
```text
TEST-ID:
REQ-ID:
Environment / commit / migration:
Fixture / prerequisite:
Steps / input:
Expected:
Observed:
Result: PASS | FAIL | BLOCKED | NOT_RUN
Artifacts (video/log/screenshot):
Reviewer/date:
```

## Release-blocking criteria
- Any unauthorized RLS/media/admin access is critical and blocks release.
- No fallback path when AI fails blocks P0.
- Report creation/lifecycle impossible on clean staging blocks release.
- P1/P2 failing tests do not justify pretending features are present; disable/defer safely.
- Unexecuted tests remain `NOT_RUN` or `BLOCKED`, not 'pass by design'.

## Regression cadence
Run unit + lint/typecheck on every PR; RLS/API tests on backend change; E2E after report/assignment changes; full release smoke on Day 20/21. Keep requirements-to-test evidence index as single source of progress.


## Agent acceptance checklist (proposed)

- [ ] All P0 functional flows have positive and negative test scenarios.
- [ ] All 217 planned `TEST-*` IDs remain traceable without renumbering.
- [ ] Security/RLS failures are release blockers even when UI seems correct.
- [ ] Latency/success measurements state samples, environment and caveats.
- [ ] No unexecuted test is falsely reported as passed.

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
| `REQ-GOAL-001` | Student reporting journey targets completion in under 60 seconds | §§3 (G1), 23 | TARGET | — |
| `REQ-REPORT-016` | AI unavailability must not prevent manual category/description reporting | §§7.3, 24 | P0 | DEC-007 |
| `REQ-AI-003` | Remain operable when AI API fails or analysis output is unsuitable | §24 | P0 | DEC-007 |
| `REQ-KPI-001` | Reporting time target: <60 seconds | §23 | TARGET | — |
| `REQ-KPI-002` | AI classification time target: <10 seconds | §23 | TARGET | DEC-007 |
| `REQ-KPI-003` | Submission success target: >95% | §23 | TARGET | — |
| `REQ-KPI-004` | Supported-category issue routing is automatic when AI is successful | §23 | TARGET | DEC-007 |
| `REQ-KPI-005` | Student can see resolution status | §23 | TARGET | — |
| `REQ-KPI-006` | Resolved supported issues produce estimated impact | §23 | TARGET | DEC-009 |
| `REQ-KPI-007` | Historical reports surface recurring hotspots | §23 | TARGET | DEC-003, DEC-008 |
| `REQ-RISK-001` | Allow manual category/description fallback for Gemini API failure | §24 | CONTROL | DEC-007 |
| `REQ-RISK-002` | Prefer building/floor/area selection to GPS-only location | §24 | CONTROL | DEC-008 |
| `REQ-RISK-003` | Prioritize P0 before P1 and P2 to prevent scope expansion | §24 | CONTROL | DEC-012 |
| `REQ-RISK-004` | Permit editing of weak AI results and avoid AI-blocked reporting | §24 | CONTROL | DEC-007 |
| `REQ-RISK-005` | Freeze major feature work around day 19–20 to allow polishing/tests | §24 | CONTROL | DEC-012 |

15 source-linked rows displayed of 15 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
