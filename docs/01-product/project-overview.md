---
title: 'EcoCampus Product Overview'
package_doc_id: ECO-01
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§1–6, 21–27'
prior_document_mapping: 'DOC-006'
priority_scope: 'BASE'
date: '2026-10-10'
---

# EcoCampus Product Overview

> **Path:** `docs/01-product/project-overview.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§1–6, 21–27; legacy registry: DOC-006.  
> **Decision gates:** `DEC-001`, `DEC-012`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Executive summary — PRD baseline
EcoCampus is an **AI-Powered Campus Sustainability & Issue Intelligence Platform**. Tagline: **Report. Resolve. Improve.** Students and faculty/staff identify problems; a student-facing Flutter app makes photo reporting simple; Gemini can suggest issue category, severity, department and text; administrators organize assignments and resolution; campus-level insights expose hotspots and estimated sustainability improvement.

The PRD specifies a **three-week, two-developer** delivery, mobile **Android/iOS** and a **web administrative dashboard**. North star: `OBSERVE → REPORT → UNDERSTAND → PRIORITIZE → RESOLVE → MEASURE → PREVENT` (PRD §27).

## Problem and outcomes — PRD §§2–3
| Pain point | Student/admin consequence | Outcome to validate |
|---|---|---|
| Reporting channel unknown or inconvenient | Observed problems stay invisible | A report created in under 60 seconds (target) |
| No progress visibility | Low trust, repeat submissions | Reporter sees lifecycle and resolution notes |
| Repeated incidents reported separately | Fragmented operational view | P1 duplicate signals and consolidated attention |
| No reliable location comparison | Fixes miss hotspots | P1 map, recurring area and building views |
| No demonstration of impact | Sustainability work hard to explain | Estimated—not measured—water/energy/waste impact |
| Little participation feedback | Underreporting | EcoPoints P0; leaderboard P1; challenges P2 |

## Target people and jobs-to-be-done
**Student:** detect → capture/choose photo → inspect editable AI guesses → select Building/Floor/Area → submit → track. Must handle AI outage through manual entry.

**Administrator:** review all campus issues, filter/search, override suggested severity/priority where authorized, assign departments, reject invalid issues, track status and resolution, compare campus/building trends.

**Department staff:** view appropriately assigned issues; change allowed statuses and write resolution notes. Whether staff uses the same web shell is `DEC-010`, still proposed.

**Faculty/staff as reporters:** named among primary users in header, but registration/report permissions are only specified in detail for Student. Do not introduce a new reporter role without an explicit decision.

## Feature slices and honest claims
| Layer | P0 contract | P1 expansion | P2 stretch |
|---|---|---|---|
| Submission | Auth; home; photo; AI; location; report history | Duplicates; priority | Advanced image similarity |
| Operations | Admin overview; department assignment; status; basic analytics | Recurrence, hotspots, 2D map, building scores | AI Advisor and simulator |
| Engagement | EcoPoints | Leaderboard | Eco Challenges |
| Communication | Tracking and visible states | — | Advanced notifications |
| Impact | Plain estimates only where applicable | Impact calculations | Intervention scenarios, explicit assumptions |

**Source nuance:** PRD §17 describes event notifications, but §21 classifies *advanced notifications* as P2; the mechanism and MVP delivery are unresolved under `DEC-011`.

## User-visible promise and credibility constraints
1. Reporting is easy; user corrections override AI suggestions before submission.
2. Location is selectable without GPS; never claim precise sensor positioning.
3. The report's progress is visible to its reporter; issue history is auditable.
4. Campus improvement figures must say **estimated** without verified meter or sensor data (PRD §14).
5. Map uses 2D custom SVG for MVP—not a 3D campus digital twin (PRD §§9, 18–19).
6. Anonymous/personal detail exposure must not be inferred from 'nearby issues' (DEC-006).

## Success criteria and planned measurement
| PRD §23 target | Proposed measurement approach (not yet approved) | Evidence artifact |
|---|---|---|
| Submission <60 sec | Controlled start-to-confirm timestamp, median/p95 recorded separately | Timed test videos/logs |
| AI classification <10 sec | Server/client correlation IDs, network and inference time split | Structured traces |
| Successful submission >95% | Completed reports divided by attempts in declared test conditions | Run summary |
| Automatic categorization | Curated supported category images + manual corrections | Labeled fixture report |
| Status visibility | Student reads confirmed state changes | E2E trace |
| Estimated impact | Resolves supported example → recalculates estimate, labeled | Formula and source fixtures |
| Recurring hotspots | Seed historical repetition → insight appears | Deterministic fixture |

## Non-goals / future only — PRD §4
No full 3D digital twin, IoT sensor integration, real-time utility monitoring, automatic physical repairs, drone/satellite monitoring, complex AR navigation, full ERP, payment/reward marketplace or advanced CV model training. Roadmap examples include AR, real sensors, 3D and predictive maintenance (PRD §21).

## Demonstration narrative — PRD §25
Overflowing waste bin photographed → Gemini suggestions reviewed → possible duplicate (P1) → admin queue and department assignment → recurring cafeteria hotspot (P1) → optional AI insight (P2) → resolve → estimated impact update (P1) → EcoPoints and P1 leaderboard → score recalculation (P1). For each demo beat show only working features and identify seeded estimates.

## Product boundaries and approval requirements
- No numerical Eco Score formula or priority algorithm is specified by the PRD; require `DEC-001` and `DEC-002` before coding.
- Example waste and water savings are illustrative, not outcomes measured at campus (`DEC-009`).
- Campus identity/building list is not provided; obtain canonical locations (`DEC-008`).
- University email restriction is optional, not automatically mandatory (PRD §7.1).
- Project owner, campus stakeholder, product approver, and deployment target remain to be assigned.


## Agent acceptance checklist (proposed)

- [ ] Reads consistently with the 12/7/5 feature split in PRD §21.
- [ ] Explicitly names student, administrator, department staff and the unresolved faculty reporter policy.
- [ ] Every numerical performance claim is marked target; every impact/simulator value is marked estimate.
- [ ] No demo step represents a P1/P2 capability as built without verification.

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
| `REQ-PRD-001` | Product is a centralized, AI-assisted campus issue reporting and sustainability intelligence platform | §§1–2, 26 | BASE | — |
| `REQ-PRD-002` | Product shall support students reporting campus sustainability and infrastructure issues | §§1–2, 5, 26 | BASE | — |
| `REQ-PRD-003` | University administrators must have actionable campus issue insights | §§1–3, 5.2 | BASE | — |
| `REQ-NONGOAL-001` | Exclude Full 3D digital twin from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-002` | Exclude IoT sensor integration from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-003` | Exclude Real-time electricity/water monitoring from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-004` | Exclude Automatic physical repair from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-005` | Exclude Drone or satellite monitoring from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-006` | Exclude Complex augmented reality navigation from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-007` | Exclude Full university ERP integration from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-008` | Exclude Payment or reward marketplace from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-009` | Exclude Advanced computer vision model training from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NS-001` | Product north-star lifecycle is Observe → Report → Understand → Prioritize → Resolve → Measure → Prevent | §27 | BASE | — |

13 source-linked rows displayed of 13 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
