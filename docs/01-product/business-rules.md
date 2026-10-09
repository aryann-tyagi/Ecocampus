---
title: 'Business Rules, Constraints and Invariants'
package_doc_id: ECO-04
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§6–8, 11–14, 17, 20–21'
prior_document_mapping: 'DOC-011; DOC-030; DOC-032'
priority_scope: 'CROSS'
date: '2026-10-10'
---

# Business Rules, Constraints and Invariants

> **Path:** `docs/01-product/business-rules.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§6–8, 11–14, 17, 20–21; legacy registry: DOC-011; DOC-030; DOC-032.  
> **Decision gates:** `DEC-001`, `DEC-002`, `DEC-003`, `DEC-004`, `DEC-005`, `DEC-006`, `DEC-007`, `DEC-008`, `DEC-009`, `DEC-010`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Canonical definitions
**Report**: an individual authenticated student's submitted observation. **Issue**: the actionable unit triaged/resolved by campus administration. The PRD uses 'report' and 'issue' interchangeably; preserving separate entities is a proposed schema choice, not established source behavior (`DEC-003`).

**Valid report:** PRD mentions rewards for *valid* reports but never defines verification actor or timing. Define in `DEC-005` before awarding.

**Department:** organizational destination such as Housekeeping for a waste problem; department taxonomy/configuration not supplied.

## Classification and severity — PRD §§7–8
| Category | PRD value | Recommended canonical enum key (proposal) |
|---|---|---|
| Waste | Waste | `waste` |
| Water | Water | `water` |
| Electricity | Electricity | `electricity` |
| Infrastructure | Infrastructure | `infrastructure` |
| Greenery | Greenery | `greenery` |
| Cleanliness | Cleanliness | `cleanliness` |
| Other | Other | `other` |

Severity definitions: **Low** minor limited impact; **Medium** affects a small area or group; **High** significant campus impact; **Critical** potentially dangerous or highly damaging. Gemini suggests and Admin can override; the reporter can edit AI suggestions before submission.

## Lifecycle — PRD §7.7
Core states: `REPORTED → ASSIGNED → IN_PROGRESS → RESOLVED` (`IN PROGRESS` is PRD display spelling). `REJECTED` and `DUPLICATE` are optional. Transition authority, quick resolution, reopening, reversal rules and terminal-state meaning require `DEC-004`.

| Candidate transition | Actor (proposal) | Data invariant |
|---|---|---|
| reported → assigned | Admin | Existing department; auditable actor |
| assigned → in_progress | Assigned staff/Admin | Current assignment matches requester |
| in_progress → resolved | Assigned staff/Admin | Resolution note captured |
| reported/assigned → rejected | Admin, if approved | Reason mandatory |
| report → duplicate | Admin/system, if approved | Canonical link and no self-link |

## Privacy and ownership invariants
1. Every write derives `auth.uid()` and role on the server.
2. Student may create/read own reports; cannot update admin-controlled status, assignment, final priority, points or another student's record.
3. Staff sees and updates only authorized department tasks; Admin has campus-level management subject to audit.
4. Student nearby/duplicate previews cannot disclose owner identity, private photo or internal notes without approved cross-user policy (`DEC-006`).

## EcoPoints — PRD §12.1
| PRD event | Displayed points | Unresolved semantics |
|---|---:|---|
| Valid issue report | +30 | Who validates, when credited |
| Issue resolved | +20 | Beneficiary, duplicate supporters and reversals |
| Critical valid report | +50 | Replaces or adds to +30 |
| Complete challenge | +100 | P2-only; definition of completion |

**Proposed implementation:** server-authoritative ledger with unique event IDs and compensating reversals; do not implement +80 for critical reports without approval.

## Priority, duplicates, impact and score
- Duplicate detection P1 uses location, category, description similarity, time proximity and image similarity **where available** (PRD §8.2). No cutoff prescribed.
- Smart priority P1 uses severity, reports count, recurrence, age, location impact (PRD §8.3); numerical weights/caps undefined.
- Building Eco Score P1 and campus home score presentation have illustrative numbers but no official formula (`DEC-001`).
- Water (L), electricity (kWh) and waste (kg) outputs must visibly state **estimate** unless supported by measured data (`DEC-009`).
- Joining duplicates must not cause double-counted environmental benefit or gaming, pending `DEC-003/005/009`.

## Canonical location
For MVP enforce a valid, active `building_id → floor_id → area_id` hierarchy, not freeform guessed names. Campus buildings, floor IDs and SVG pins require approved seed data. GPS is optional, and current GPS permission failure must not block submission (`DEC-008`).

## Transaction and concurrency rules — proposed
- Save status + history atomically; make repeated transitions conflict rather than silently repeating events.
- Award points once per approved event; only trusted backend creates ledger entries.
- Recalculate derived analytics from current authoritative reports and histories, not a client editable score.
- Avoid hard deletion of historical audits; retention specifics need human decision.

## Explicit boundaries
Do not interpret sample `91%` duplicate, `24/81/94` priority, `82→88` What-If or liters/kWh figures as calibrated system outcomes. They are examples in the PRD.


## Agent acceptance checklist (proposed)

- [ ] Severity and category values match the original PRD.
- [ ] Students cannot perform assignment/status/points mutations via direct API.
- [ ] Repeated backend events do not double-award or double-record terminal transitions.
- [ ] Every proposed rule is linked to a decision gate.

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
| `REQ-GOAL-003` | Administrators receive a queue supporting prioritization of issues | §3 (G3) | BASE | DEC-002 |
| `REQ-GOAL-006` | Recognize student contribution through EcoPoints; richer achievements, challenges and leaderboards depend on their respective P1/P2 scopes | §3 (G6), §21 | CROSS | DEC-005, DEC-012 |
| `REQ-ROLE-001` | Provide Student role with fast reporting, photo, location and tracking | §5.1 | BASE | DEC-006 |
| `REQ-ROLE-002` | Campus Administrators monitor, assign, track and analyze issues | §5.2 | BASE | DEC-010 |
| `REQ-ROLE-003` | Department Staff can view assigned issues, update statuses, add resolution notes and mark resolved | §5.3 | BASE | DEC-004, DEC-010 |
| `REQ-FLOW-001` | Support observe → photograph → AI suggestion → confirm location → submit report sequence | §6 | CROSS | DEC-007, DEC-008 |
| `REQ-FLOW-002` | Run duplicate detection and smart priority in issue processing when their features are enabled | §6, §21 | P1 | DEC-002, DEC-003 |
| `REQ-FLOW-003` | Resolve issue through administrator/staff workflow and make updated state visible to the reporting student | §6, §7.7 | CROSS | DEC-004, DEC-011 |
| `REQ-FLOW-004` | Award EcoPoints on eligible reporting/resolution actions | §6, §12.1 | CROSS | DEC-005 |
| `REQ-REPORT-012` | Allow administrators to override the AI severity recommendation | §7.5 | P0 | DEC-004, DEC-010 |
| `REQ-REPORT-015` | Create a trackable report after student confirmation | §§7.3, 24 | P0 | DEC-004 |
| `REQ-TRACK-001` | List student active reports | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-002` | List student resolved reports | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-003` | Show report details | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-004` | Show current report status | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-005` | Show resolution notes | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-006` | Show original submission date | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-007` | Support normal states REPORTED → ASSIGNED → IN PROGRESS → RESOLVED | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-008` | Consider REJECTED and DUPLICATE as optional—not required for P0 | §7.7 | OPTION | DEC-004, DEC-006 |
| `REQ-DUP-001` | Compare report category when detecting potential duplicate | §8.2, §21 | P1 | DEC-003, DEC-006 |
| `REQ-DUP-002` | Compare building/floor/area location when detecting duplicate | §8.2, §21 | P1 | DEC-003, DEC-006 |
| `REQ-DUP-003` | Compare description similarity | §8.2, §21 | P1 | DEC-003, DEC-006 |
| `REQ-DUP-004` | Use time proximity as duplicate signal | §8.2, §21 | P1 | DEC-003, DEC-006 |
| `REQ-DUP-005` | Use image similarity when available (advanced image similarity remains P2) | §8.2, §21 | P2 | DEC-003, DEC-006 |
| `REQ-DUP-006` | Display possible duplicate and existing issue information | §8.2, §21 | P1 | DEC-003, DEC-006 |
| `REQ-DUP-007` | Offer Join Existing Issue action | §8.2, §21 | P1 | DEC-003, DEC-006 |
| `REQ-DUP-008` | Offer Report Anyway action | §8.2, §21 | P1 | DEC-003, DEC-006 |
| `REQ-PRIO-001` | Smart priority considers severity | §8.3, §11.1 | P1 | DEC-002 |
| `REQ-PRIO-002` | Smart priority considers number of reports | §8.3, §11.1 | P1 | DEC-002 |

30 source-linked rows displayed of 59 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
