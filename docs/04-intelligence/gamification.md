---
title: 'EcoPoints, Levels, Achievements, Rankings and Challenges'
package_doc_id: ECO-19
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§3, 12–13, 17, 21'
prior_document_mapping: 'DOC-032'
priority_scope: 'P0/P1/P2'
date: '2026-10-10'
---

# EcoPoints, Levels, Achievements, Rankings and Challenges

> **Path:** `docs/04-intelligence/gamification.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§3, 12–13, 17, 21; legacy registry: DOC-032.  
> **Decision gates:** `DEC-003`, `DEC-004`, `DEC-005`, `DEC-006`, `DEC-012`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Feature tier mapping
| Capability | PRD classification | Required behavior |
|---|---|---|
| EcoPoints | P0 | Recognize approved valid reporting/resolution events |
| Campus/monthly/challenge leaderboard | P1 | Rank users based on trusted points |
| Levels and achievements | Described PRD §12, exact MVP tier not independently explicit | Define delivery gate with Product Lead |
| Eco Challenges | P2 | Track participants, reports, points, completion % |
| Challenge/reward notifications | P2 advanced delivery | Depends on DEC-011/012 |

## PRD reward table (source-backed)
| Action | Point value |
|---|---:|
| Valid issue report | +30 |
| Issue resolved | +20 |
| Critical valid report | +50 |
| Complete challenge | +100 |

**Unresolved:** Does +50 replace/add to +30, when is a report 'valid', who earns +20, and how to reverse rejected/reopened/duplicate awards? Requires DEC-005. Do **not** credit +80 for critical reports by silent inference.

## Proposed event-sourced points ledger
```json
{
  "entryId": "uuid",
  "beneficiaryUserId": "uuid",
  "eventKey": "report:uuid:valid",
  "eventType": "VALID_REPORT",
  "pointsDelta": 30,
  "sourceReportId": "uuid",
  "policyVersion": "pending-approval",
  "createdAt": "UTC timestamp"
}
```
Use unique `eventKey`; for a correction, add compensating negative entry, never erase audit trail. Amount above is PRD for valid report, but eligibility remains unapproved.

## Awarding flow — proposed
`report action → trusted eligibility evaluation → unique ledger insert → recompute/read balance → UI update → optional notification`. Student cannot award their own points by modifying profile, status, severity, API payload or offline cache.

## Abuse and fairness controls
- Reject repeated identical event IDs and repeated supporter joins.
- Decide whether one Student can report the same unresolved physical issue repeatedly for credit.
- Enforce privilege check when an Admin validates or rejects an incident.
- Define treatment for changed severity, corrected mistakes, appeal and suspected spam before policy goes live.
- Month/campus ranks must specify timezone, tie policy and visibility of student names.

## Levels and badges (PRD §12)
Labels shown: Level 1 Seed; Level 5 Sprout; Level 10 Guardian; Level 20 Planet Protector. **Level thresholds between these and points-to-level mapping are not given.** Candidate: persist `level` as calculated from approved points threshold table. Do not invent fixed thresholds.

Achievements: First Report, Eco Warrior, Water Saver, Energy Guardian, 10 Issues Reported, 10 Issues Resolved. Exact predicates for thematic badges need approval. Prevent one duplicated report from counting many times.

## Leaderboard interface (P1)
- Views: campus, monthly, and challenge rankings as described in PRD §12.4.
- Source of truth: aggregated ledger, not client provided balance.
- Privacy: approved display name/alias, opt-out/visibility policy pending DEC-006.
- Empty periods show `No eligible activity`; current user row may be shown even outside top N if authorized.
- Reversals should reconcile ranks after recomputation; no hardcoded demo rank.

## Challenges interface (P2)
Examples from PRD §13: Water Week, Energy Week, Clean Campus, Green Campus. For each, define eligibility window, start/end, category, participant enrollment, report counts, completion metric, points award once and status. Source PRD lists challenge names but **not exact pass criteria**.

## Required negative tests
1. Replaying `report:uuid:valid` 10 times credits once.
2. Student calls ledger insert directly and is denied.
3. Changing category to critical locally cannot award higher bonus.
4. Invalid/rejected/duplicated report follows documented adjustment rule.
5. Staff resolution does not improperly receive reporter bonus.
6. Month boundary and leaderboard ties use explicit business timezone/policy.
7. P2 challenge award is absent when challenges are disabled.


## Agent acceptance checklist (proposed)

- [ ] P0 EcoPoints is implemented independently of optional ranking/challenges.
- [ ] Point stacking and validation definitions are approved before production rewards.
- [ ] Credit/deduction actions are auditable and idempotent.
- [ ] Leaderboard totals reconcile to ledger without exposing private identities.
- [ ] Levels and achievements have reviewed thresholds before badges are issued.

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
| `REQ-GOAL-006` | Recognize student contribution through EcoPoints; richer achievements, challenges and leaderboards depend on their respective P1/P2 scopes | §3 (G6), §21 | CROSS | DEC-005, DEC-012 |
| `REQ-FLOW-004` | Award EcoPoints on eligible reporting/resolution actions | §6, §12.1 | CROSS | DEC-005 |
| `REQ-GAME-001` | Award +30 EcoPoints for a valid issue report | §12.1 | P0 | DEC-005 |
| `REQ-GAME-002` | Award +20 EcoPoints when an issue is resolved | §12.1 | P0 | DEC-005 |
| `REQ-GAME-003` | Award +50 EcoPoints for a critical valid report | §12.1 | P0 | DEC-005 |
| `REQ-GAME-004` | Award +100 EcoPoints for completing a challenge | §12.1 | P2 | DEC-005, DEC-012 |
| `REQ-GAME-005` | Provide named levels: Level 1 Seed, Level 5 Sprout, Level 10 Guardian, Level 20 Planet Protector | §12.2 | CROSS | DEC-005 |
| `REQ-GAME-006` | Provide First Report achievement | §12.3 | CROSS | DEC-005 |
| `REQ-GAME-007` | Provide Eco Warrior achievement | §12.3 | CROSS | DEC-005 |
| `REQ-GAME-008` | Provide Water Saver achievement | §12.3 | CROSS | DEC-005 |
| `REQ-GAME-009` | Provide Energy Guardian achievement | §12.3 | CROSS | DEC-005 |
| `REQ-GAME-010` | Provide 10 Issues Reported achievement | §12.3 | CROSS | DEC-005 |
| `REQ-GAME-011` | Provide 10 Issues Resolved achievement | §12.3 | CROSS | DEC-005 |
| `REQ-GAME-012` | Provide campus leaderboard | §12.4 | P1 | DEC-005 |
| `REQ-GAME-013` | Provide monthly leaderboard | §12.4 | P1 | DEC-005 |
| `REQ-GAME-014` | Provide challenge leaderboard | §12.4 | P1 | DEC-005 |
| `REQ-CHAL-001` | Water Week challenge supports reporting water wastage | §13 | P2 | DEC-005, DEC-012 |
| `REQ-CHAL-002` | Energy Week challenge supports reporting unnecessary electricity usage | §13 | P2 | DEC-005, DEC-012 |
| `REQ-CHAL-003` | Clean Campus challenge supports identifying waste hotspots | §13 | P2 | DEC-005, DEC-012 |
| `REQ-CHAL-004` | Green Campus challenge supports reporting damaged greenery | §13 | P2 | DEC-005, DEC-012 |
| `REQ-CHAL-005` | Track challenge participants, reports, points and completion percentage | §13 | P2 | DEC-005, DEC-012 |

21 source-linked rows displayed of 21 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
