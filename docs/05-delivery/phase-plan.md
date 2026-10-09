---
title: '21-Day Two-Developer Phased Implementation Plan'
package_doc_id: ECO-21
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§21–25'
prior_document_mapping: 'DOC-038; DOC-039'
priority_scope: 'PLAN'
date: '2026-10-10'
---

# 21-Day Two-Developer Phased Implementation Plan

> **Path:** `docs/05-delivery/phase-plan.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§21–25; legacy registry: DOC-038; DOC-039.  
> **Decision gates:** `DEC-004`, `DEC-006`, `DEC-007`, `DEC-008`, `DEC-010`, `DEC-011`, `DEC-012`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Source schedule — PRD §22
| Days | PRD deliverable | Acceptance evidence / candidate PR |
|---|---|---|
| 1–2 | Setup, UI system, Supabase/database/auth | Clean build, migrations, RLS smoke, login | 
| 3–5 | Student home, report, camera/storage/location | Capture → preview → valid location state |
| 6–7 | Gemini integration, result edit/confirm, report creation | AI + manual fallback through saved report |
| 8–10 | Admin dashboard, assignment, status flow | Report moves through assigned/in-progress/resolved |
| 11–12 | Priority engine, duplicate detection | Deterministic P1 fixtures and explainable queue |
| 13–14 | Campus map, building profiles, analytics | Seed building selection and chart queries |
| 15–16 | EcoPoints, leaderboard, achievements | Award once + rank computed correctly |
| 17 | Impact engine, campus Eco Score | Documented formulas + qualified estimates |
| 18 | Recurrence/hotspots | Reproducible building/time insights |
| 19 | Advisor/What-If differentiator | Stretch only if P0/P1 stable |
| 20 | Polish, testing, errors, performance | E2E, RLS, failure-path evidence |
| 21 | Demo, pitch, backup video, final fixes | Live scripted flow + fallback and judge assets |

## Two-developer parallel lanes (proposal)
**Developer A:** Flutter/Riverpod mobile screens, auth integrations, photo/location UX, report tracking, student rewards/map UI.

**Developer B:** Supabase migrations/RLS, Edge Functions + Gemini, Next.js Admin/Staff app, analytics/algorithms, deployment.

**Shared ownership:** product rules, integration contracts, UI tokens, approved decision gates, integration tests and demo story. Both developers review each other's privileged/data-access changes; actual assignments await team approval.

## Dependencies and critical path
`DEC-004/006/007/008/010/011 approvals → auth/database/media policy → report submission → admin assignment/status → tracking → points ledger → higher-tier algorithms → demo`. Any blocked decision must be logged; do not 'work around' privacy or permission policies.

## Phase contract (proposed; small PR per completed phase)
1. Create branch `phase/NN-feature-slug` from tested main.
2. Record `REQ-*`, `TEST-*`, UX/contracts and P-tier in PR description.
3. Make cohesive implementation + tests + migrations in same phase if needed.
4. Run code formatting, static check, unit/integration and mandatory RLS tests.
5. Record screenshots/logs/evidence, migration state, risk and rollback notes.
6. Open PR, request other developer review, address blocking comments, merge only after passing gates.
7. Update requirement status and demo fixture after merge; avoid merging unreviewed partially implemented phases.

## Day-level operational plan — proposal
| Day | Developer A | Developer B | Integration checkpoint |
|---|---|---|---|
| 1 | Flutter skeleton, theme, auth screens | Supabase project/env/migrations | Build + identity contracts |
| 2 | Login/register/profile UX | Roles/RLS, seed locations | Cross-account access tests |
| 3 | Home and camera/gallery | Media bucket and upload auth | Image privacy |
| 4 | Editable report form | Report schema/location validation | Create draft model |
| 5 | Location picker/submit states | Create report API + E2E fixture | Submission contract |
| 6 | Analysis/loading/manual fallback | Gemini secure Edge integration | Invalid provider output |
| 7 | Confirm/receipt/own history | Idempotency/errors + trace | P0 submit path |
| 8 | Report timeline | Admin queue/page skeleton | Status visibility |
| 9 | Track status + resolution display | Assignment/RLS/Staff views | Transition guards |
| 10 | Polish mobile tracking | Admin lifecycle/notes | Full P0 workflow |
| 11 | P1 duplicate preview | Candidate matching | Privacy/false duplicate |
| 12 | Queue priority UI | Scorer, engine tests | P1 priority source |
| 13 | Map/list alternative | SVG/building aggregates | Location join checks |
| 14 | Building profile | Admin analytics/charts | Mapping/metric verification |
| 15 | Points balance/history | Transactional points ledger | Idempotency |
| 16 | Optional leaderboard views | Ranking/achievement helpers | Reward reconciliation |
| 17 | Eco Score/impact UI | Formula implementation + unit tests | Estimate disclosure |
| 18 | Hotspot screens | Recurrence aggregates | Historical seed validation |
| 19 | Optional P2 UX | Optional Advisor/simulator or stability debt | Scope decision gate |
| 20 | Device QA/fixes | Security/perf/deployment rehearsal | Release candidate |
| 21 | Live walkthrough | Monitoring/recovery/demo backup | Judge-ready release |

## Risk and scope controls
- AI API outage → manual fallback.
- No campus SVG master data → textual building fallback, label map as blocked.
- Location inaccuracies → mandatory Building/Floor/Area, optional GPS.
- Time pressure → P0 before P1, P1 before P2, freeze new major work around Days 19–20 (PRD §24).
- Estimate uncertainty → show methodology and `estimated`, never manufactured sensor data.

## Definition of done
Source/tests/docs committed; each feature has traceable acceptance evidence; server authorization proved; no critical bugs; role UI usable; demo fixtures reproducible; one narrow reviewed PR; deployment smoke checks and known limitations documented.


## Agent acceptance checklist (proposed)

- [ ] Team can map every PRD day window to a deliverable and proposed reviewed PR.
- [ ] P0 full reporting and resolution tested before stretch work.
- [ ] Decisions and technical dependencies are explicit instead of blocking silently.
- [ ] Phase-specific automated checks and rollback information accompany PRs.

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
| `REQ-TECH-016` | Version control uses Git and GitHub | §§18–19 | BASE | — |
| `REQ-RISK-001` | Allow manual category/description fallback for Gemini API failure | §24 | CONTROL | DEC-007 |
| `REQ-RISK-002` | Prefer building/floor/area selection to GPS-only location | §24 | CONTROL | DEC-008 |
| `REQ-RISK-003` | Prioritize P0 before P1 and P2 to prevent scope expansion | §24 | CONTROL | DEC-012 |
| `REQ-RISK-004` | Permit editing of weak AI results and avoid AI-blocked reporting | §24 | CONTROL | DEC-007 |
| `REQ-RISK-005` | Freeze major feature work around day 19–20 to allow polishing/tests | §24 | CONTROL | DEC-012 |
| `REQ-PLAN-001` | Project setup, UI system, Supabase, database and authentication | §22 | PLAN | — |
| `REQ-PLAN-002` | Student home/report flow, camera/upload, storage and location | §22 | PLAN | — |
| `REQ-PLAN-003` | AI integration, result confirmation and report creation | §22 | PLAN | — |
| `REQ-PLAN-004` | Admin dashboard, issue management, assignment and status | §22 | PLAN | — |
| `REQ-PLAN-005` | Smart priority and duplicate detection | §22 | PLAN | — |
| `REQ-PLAN-006` | Campus map, building profiles and analytics | §22 | PLAN | — |
| `REQ-PLAN-007` | EcoPoints, leaderboard and achievements | §22 | PLAN | — |
| `REQ-PLAN-008` | Impact calculations and Campus Eco Score | §22 | PLAN | — |
| `REQ-PLAN-009` | Recurring issue detection and hotspots | §22 | PLAN | — |
| `REQ-PLAN-010` | AI Advisor / What-If optional differentiator | §22 | PLAN | DEC-012 |
| `REQ-PLAN-011` | UI polish, testing, errors and performance | §22 | PLAN | DEC-012 |
| `REQ-PLAN-012` | Demo, presentation, backup video and final fixes | §22 | PLAN | DEC-012 |
| `REQ-NONGOAL-001` | Exclude Full 3D digital twin from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-002` | Exclude IoT sensor integration from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-003` | Exclude Real-time electricity/water monitoring from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-004` | Exclude Automatic physical repair from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-005` | Exclude Drone or satellite monitoring from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-006` | Exclude Complex augmented reality navigation from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-007` | Exclude Full university ERP integration from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-008` | Exclude Payment or reward marketplace from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-009` | Exclude Advanced computer vision model training from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NS-002` | Defer features that do not improve the product north-star loop | §27 | CONTROL | DEC-012 |

28 source-linked rows displayed of 28 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
