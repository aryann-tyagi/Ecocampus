---
title: 'Next.js Admin and Staff Screen Specification'
package_doc_id: ECO-07
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§5.2–5.3, 8–11, 14–17, 21'
prior_document_mapping: 'DOC-014'
priority_scope: 'P0/P1/P2'
date: '2026-10-10'
---

# Next.js Admin and Staff Screen Specification

> **Path:** `docs/02-design/admin-staff-screen-spec.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§5.2–5.3, 8–11, 14–17, 21; legacy registry: DOC-014.  
> **Decision gates:** `DEC-001`, `DEC-002`, `DEC-004`, `DEC-006`, `DEC-009`, `DEC-010`, `DEC-013`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Application shell (proposed route scheme)
- Framework: Next.js, TypeScript, Tailwind; Recharts for graphs (PRD §19).
- Signed-in, server-authorized pages: `/admin/overview`, `/admin/issues`, `/admin/issues/[id]`, `/admin/buildings`, `/admin/analytics`, `/admin/impact`, `/admin/advisor` (P2), `/admin/simulator` (P2).
- Staff variant: `/staff/assignments` and `/staff/assignments/[id]`, or protected shared shell—pending `DEC-010`.
- Authentication and access checks run on server/data access as well as hiding restricted actions in UI.

## AD-01 — Login / unauthorized
Display credentials sign-in, error/retry, role-aware destination. A Student login must not become Admin just by navigating to an admin URL. Authenticated but unauthorized gets a non-leaking 403 page with a clear return action.

## AD-02 — Overview (P0)
| Widget from PRD §11 | Data definition / source needed | Null state |
|---|---|---|
| Campus Eco Score | P1 score model; P0 presentation shell | Pending calculation, no invented number |
| Active issues | Open states after approved lifecycle policy | 0 + explanatory label |
| Critical issues | Current severity / eligible statuses | 0 |
| Resolved issues | Audited resolved status | 0 |
| Avg resolution time | Resolution timestamp - creation timestamp (proposal) | N/A if no resolutions |
| Environmental impact | P1 estimates with qualified units | Not calculated |

Include filtered issue queue and chart cards without silently activating higher-tier calculations.

## AD-03 — Issue queue (P0)
- Table columns: report ID, category, severity, location, status, created time, department, optional priority (P1), latest action.
- Controls: search, status, category, building, department, time window; paginated/sorted server-side at scale (proposed).
- P0 queue sorting fallback is `DEC-002`; do not pretend illustrative `81/100` is computed.
- Actions: view/assign/change status/reject/mark duplicate **only if permitted and implemented**.
- Empty, loading, error, invalid-filter and permission states all rendered.

## AD-04 — Issue detail / action drawer (P0)
- Show source photo with authorized signed access, reporter safe identity according to policy, final submitted fields, separate AI suggestions if retained, location chain, status and timestamp history.
- Admin actions: assign/reassign department; override severity (PRD §7.5); change priority (P1 or gate); update status, add resolution/rejection notes.
- Staff actions: only assigned issue status/note/resolve, no general assignment or user role management.
- Require confirmation for destructive/terminal actions. On save, send expected version to avoid lost updates (proposed).

## AD-05 — Assignments and staff work queue (P0)
- Filter by department/current assignment; show task age and severity (do not fabricate SLA clock).
- Start/resolve buttons governed by approved transitions; resolution note required if approved under DEC-004.
- Handle reassignment during an open staff page: show conflict and refresh, not silent overwrite.

## AD-06 — Analytics (P0 shell; P1 advanced)
- P0: issue distribution by category, summary building comparisons and resolution performance appropriate to available data.
- P1: trend lines, recurring hotspots, map, score and calculated environmental impact.
- Display scope (campus/building/period), data refresh time, empty denominator handling, estimates vs measured indicators.

## AD-07 — Building map / profiles (P1)
- Interactive SVG highlighting each building; select to open scores, active/resolved counts, category breakdown and recurrence.
- Legend accessible beyond color; list view for keyboard or small-screen access.
- Map geometry and score source remain DEC-001/008; no invented campus plan.

## AD-08 — AI Advisor / What-If (P2)
- Advisor query examples follow PRD §15; outputs must cite query/time window/source data and say when evidence is missing.
- What-If scenario shows baseline, proposed interventions, projected difference, assumptions and a conspicuous `Scenario estimate, not a guarantee` notice.
- Never display P2 widget as enabled before server authorization/quality gates.

## Error, accessibility and evidence requirements
- Filter state is URL-restorable where sensible (proposal); never put secrets or private photos in URLs.
- Keyboard operability for table actions, focus management in dialogs, accessible chart data tables, readable colors/status labels.
- Error handling: expired login → secure redirect; 403 → no sensitive data; stale row → conflict and refresh; API unavailable → retry banner.
- Audit history must identify status/assignment changes with actor and time as determined by approved schema.


## Agent acceptance checklist (proposed)

- [ ] Admin can discover, filter and act on reports using only permitted operations.
- [ ] Assigned staff cannot see/edit unrelated department issues.
- [ ] Empty and unauthorized chart states never invent data or show NaN.
- [ ] PRD P1/P2 features do not obstruct P0 issue resolution.

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
| `REQ-GOAL-003` | Administrators receive a queue supporting prioritization of issues | §3 (G3) | BASE | DEC-002 |
| `REQ-ROLE-002` | Campus Administrators monitor, assign, track and analyze issues | §5.2 | BASE | DEC-010 |
| `REQ-ROLE-003` | Department Staff can view assigned issues, update statuses, add resolution notes and mark resolved | §5.3 | BASE | DEC-004, DEC-010 |
| `REQ-REPORT-012` | Allow administrators to override the AI severity recommendation | §7.5 | P0 | DEC-004, DEC-010 |
| `REQ-ADMIN-001` | Show Campus Eco Score on administrator overview | §11 | CROSS | DEC-001, DEC-009 |
| `REQ-ADMIN-002` | Show count of active issues | §11 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-003` | Show count of critical issues | §11 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-004` | Show resolved issues count | §11 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-005` | Show average resolution time | §11 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-006` | Show estimated environmental impact | §11 | CROSS | DEC-001, DEC-009 |
| `REQ-ADMIN-007` | Provide issue list viewing | §11.1 | P0 | DEC-002 |
| `REQ-ADMIN-008` | Provide issue filtering | §11.1 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-009` | Provide issue search | §11.1 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-010` | Allow department assignment | §11.1 | P0 | DEC-004, DEC-010 |
| `REQ-ADMIN-011` | Allow change of issue priority | §11.1 | P0 | DEC-002 |
| `REQ-ADMIN-012` | Allow issue status changes | §11.1 | P0 | DEC-004, DEC-010 |
| `REQ-ADMIN-013` | Allow resolution notes | §11.1 | P0 | DEC-004, DEC-010 |
| `REQ-ADMIN-014` | Allow marking duplicate reports | §11.1 | CROSS | DEC-004, DEC-010 |
| `REQ-ADMIN-015` | Allow rejection of invalid reports | §11.1 | CROSS | DEC-004, DEC-010 |
| `REQ-ADMIN-016` | Show issue distribution analytics | §11.2 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-017` | Show building comparison analytics | §11.2 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-018` | Show resolution performance analytics | §11.2 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-019` | Show report trend analytics | §11.2 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-020` | Show recurring problem analytics | §11.2 | CROSS | DEC-006, DEC-010 |
| `REQ-NOTIF-008` | Administrator notification event: Critical issue | §17.2 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-009` | Administrator notification event: Issue spike | §17.2 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-010` | Administrator notification event: SLA approaching | §17.2 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-011` | Administrator notification event: Recurring issue detected | §17.2 | CROSS-NOTIFY | DEC-011, DEC-012 |

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
