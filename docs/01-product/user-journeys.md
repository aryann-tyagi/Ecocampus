---
title: 'Role-Based User Journeys and Interaction Flows'
package_doc_id: ECO-03
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§5–7, 11, 17, 25'
prior_document_mapping: 'DOC-011; DOC-013; DOC-014'
priority_scope: 'CROSS'
date: '2026-10-10'
---

# Role-Based User Journeys and Interaction Flows

> **Path:** `docs/01-product/user-journeys.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§5–7, 11, 17, 25; legacy registry: DOC-011; DOC-013; DOC-014.  
> **Decision gates:** `DEC-004`, `DEC-006`, `DEC-007`, `DEC-008`, `DEC-010`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Actors, starting state and outcomes
| Actor | Entry point | Core intent | Successful outcome |
|---|---|---|---|
| Student | Flutter, authenticated | Report issue with minimal effort | Report ID, status visible in My Reports |
| Student | My Reports | Find progress | Current state, timeline, resolution notes |
| Admin | Web dashboard, authenticated | Triage and route actionable issue | Assignment and history persisted |
| Staff | Authorized task queue | Carry out and document repair | Resolved status and note recorded |
| Admin | Analytics | Learn which areas need attention | Reproducible building/time-based insight |

## Journey J-01 — Student submits an issue (P0)
1. Student signs in, arrives on Home and selects prominent **Report Issue** action.
2. Student chooses camera or photo library; cancellation returns to previous state without storing a report.
3. App shows capture preview; student can replace the photo.
4. App submits authorized image for Gemini analysis; loading is visible and cancellable in UI.
5. AI returns proposed `issue`, `category`, `severity`, `department`, `description` (PRD §7.3). Student can edit all AI-generated information before submission.
6. Student selects **Building → Floor → Area**; GPS, if present, is supplementary, never blocking.
7. App validates inputs, confirms details and submits once with retry protection (idempotency design proposed).
8. System returns a trackable report ID and initial `REPORTED` state; report appears in owned report list.

**Alternates:** no camera permission → gallery/manual alternative; AI timeout/unavailable → manual category/description and other required fields; invalid location → reopen location picker; network failure → explicit retry, not invisible duplication.

## Journey J-02 — Duplicate candidate detected (P1)
When enabled, category/location/text/time comparison finds a candidate. Show a minimal authorized summary, potential similarity label and choices **Join Existing Issue** or **Report Anyway** as in PRD §8.2. Never expose the prior student's email, personal image or staff-only notes. Joining semantics and duplicate threshold remain `DEC-003` and visibility remains `DEC-006`.

## Journey J-03 — Admin triage to assignment (P0)
1. Admin signs in; sees active/critical/resolved metrics and queue.
2. Admin filters/searches by available category, area, severity, date, status.
3. Opens issue details including photo subject to access policy and AI suggestions vs final student edits.
4. Determines validity and target department; if suggested department is wrong, changes it.
5. Assigns to a department/authorized staff member per agreed model and saves; status is `ASSIGNED` with history.
6. Staff access is limited to assigned responsibilities. Critical alerts are advanced/conditional (`DEC-011`).

**Alternates:** department removed → cannot assign; concurrent assignment → conflict/refresh; invalid report → admin rejection only if state approved, with reason.

## Journey J-04 — Staff resolves and student tracks (P0)
1. Staff sees permitted assignments, opens issue, starts work (`ASSIGNED → IN_PROGRESS`).
2. Staff enters resolution note and marks `RESOLVED`; server enforces transition permissions.
3. State change appears on student's report with update time and public resolution details.
4. When applicable, trusted server evaluates P0 EcoPoints rules and P1 impact calculation.
5. Student sees updated report without being able to alter staff/admin fields.

**Alternates:** staff from wrong department receives 403; attempt to resolve nonexistent/changed report returns controlled conflict; retry must not award twice; reopening still unapproved.

## Journey J-05 — Admin identifies hotspot and impact (P1)
Choose a building/time window; inspect recurring category trend; open linked issue evidence; check whether priority comes from explainable factors; view estimated savings with unit and method disclosure. Example Block B water trend in PRD §10 is demo data, not verified history.

## Journey J-06 — Engagement and stretch enhancements
P0 points credited on approved eligible events; P1 leaderboard reflects trusted ledger and time scope; P2 challenge progression and AI Advisor/What-If are explicitly labelled not shipped until independently verified.

## Navigation and required UI states
| Step | Loading | Empty | Error | Success |
|---|---|---|---|---|
| Auth | Signing in | First registration | Invalid credentials/network | Home |
| Photo/AI | Preparing/analyzing | No image | Unsupported file/timeout | Editable result |
| Location | Fetching campus list | No locations configured | Data fetch failure | Selected hierarchy |
| Submit | Submitting | — | Form invalid/retry conflict | ID/status receipt |
| Report history | Fetching own reports | No reports yet | Permission/offline | Report list |
| Staff actions | Saving transition | No assignment | Unauthorized/concurrent edit | Updated history |

## Journey invariants for agents
- Report identity and owner derive from verified credentials, never from a modifiable client field.
- Student-facing timeline must not show internal-only administrative notes unless authorized.
- No lifecycle transition or EcoPoints event can be triggered by optimistic UI alone.
- Demo scripts must use deterministic seed users and preloaded historical issues without implying live campus measurements.


## Agent acceptance checklist (proposed)

- [ ] J-01 works end to end with editable Gemini result and with manual fallback.
- [ ] Admin-to-staff handoff has distinct permissions and audit evidence.
- [ ] All alternate paths (cancel, error, retry, empty, unauthorized) produce explainable UI states.
- [ ] P1/P2 journeys are independently gated and do not block P0.

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
| `REQ-PRD-002` | Product shall support students reporting campus sustainability and infrastructure issues | §§1–2, 5, 26 | BASE | — |
| `REQ-GOAL-001` | Student reporting journey targets completion in under 60 seconds | §§3 (G1), 23 | TARGET | — |
| `REQ-GOAL-003` | Administrators receive a queue supporting prioritization of issues | §3 (G3) | BASE | DEC-002 |
| `REQ-ROLE-001` | Provide Student role with fast reporting, photo, location and tracking | §5.1 | BASE | DEC-006 |
| `REQ-ROLE-002` | Campus Administrators monitor, assign, track and analyze issues | §5.2 | BASE | DEC-010 |
| `REQ-ROLE-003` | Department Staff can view assigned issues, update statuses, add resolution notes and mark resolved | §5.3 | BASE | DEC-004, DEC-010 |
| `REQ-FLOW-001` | Support observe → photograph → AI suggestion → confirm location → submit report sequence | §6 | CROSS | DEC-007, DEC-008 |
| `REQ-AUTH-001` | Student app supports student registration | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-002` | Student app supports login | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-003` | Student app supports logout | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-004` | Student app supports password reset | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-005` | Student app supports profile maintenance | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-HOME-001` | Display Campus Eco Score on student home | §7.2, §21 | P0-SHELL | DEC-001 |
| `REQ-HOME-002` | Display personal impact on student home | §7.2, §21 | P0-SHELL | — |
| `REQ-HOME-003` | Display active challenge on student home | §7.2, §21 | P0-SHELL | DEC-012 |
| `REQ-HOME-004` | Display nearby issues on student home | §7.2, §21 | P0-SHELL | DEC-006, DEC-008 |
| `REQ-HOME-005` | Provide prominent Report Issue action | §7.2, §21 | P0-SHELL | — |
| `REQ-REPORT-001` | Offer camera capture for an issue photograph | §7.3 | P0 | — |
| `REQ-REPORT-002` | Offer photo selection/upload from device | §7.3 | P0 | — |
| `REQ-REPORT-004` | Show AI-suggested issue type | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-005` | Show AI-suggested issue category | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-006` | Show AI-suggested severity | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-007` | Show AI-suggested department | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-008` | Show AI-generated description | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-009` | Allow user to edit AI-generated fields before submission | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-012` | Allow administrators to override the AI severity recommendation | §7.5 | P0 | DEC-004, DEC-010 |
| `REQ-REPORT-013` | Let student select Building → Floor → Area for MVP location | §7.6 | P0 | DEC-008 |
| `REQ-TRACK-001` | List student active reports | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-002` | List student resolved reports | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-003` | Show report details | §7.7 | P0 | DEC-004, DEC-006 |

30 source-linked rows displayed of 72 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
