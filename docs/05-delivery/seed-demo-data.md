---
title: 'Deterministic Seed Data and Hackathon Demo Fixtures'
package_doc_id: ECO-23
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§7–16, 22–25'
prior_document_mapping: 'DOC-041'
priority_scope: 'PLAN'
date: '2026-10-10'
---

# Deterministic Seed Data and Hackathon Demo Fixtures

> **Path:** `docs/05-delivery/seed-demo-data.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§7–16, 22–25; legacy registry: DOC-041.  
> **Decision gates:** `DEC-001`, `DEC-003`, `DEC-005`, `DEC-006`, `DEC-008`, `DEC-009`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Principles
Use fictional, sanitized, **clearly labeled demo data**. Never seed students' real identities, unlicensed photographs or claim PRD sample trends are campus measurements. The PRD includes illustrative Block A/Block B/Library/Canteen map scores and hotspot/impact figures; they are not verified real-world data.

## Proposed fixture namespaces
- `seed/reference/`: official/approved buildings, floors, areas and departments (pending DEC-008).
- `seed/demo/`: synthetic accounts, report histories, status events, assignments and sample AI classifications.
- `seed/media/`: rights-cleared test images with explicit permissions and alt labels.
- `seed/expected/`: expected aggregate values and formulas for deterministic tests.

## Sample fictional campus setup — proposal only
| Building | Floor | Area | Example case |
|---|---|---|---|
| Block A | Ground | Main Entrance | Unnecessary lighting |
| Block A | First | Room 204 | Broken light |
| Block B | Ground | Cafeteria Entrance | Overflowing waste bin |
| Block B | First | Washroom | Water leak |
| Library | Ground | Reading Area | Cleanliness problem |
| Canteen | Ground | Waste Collection | Segregation complaint |

**Warning:** These names are derived from PRD examples, not a confirmed campus registry. Keep fixture UUIDs stable but not production-authoritative.

## Demo identities (fictional)
| Alias | Role | Intended permission assertion |
|---|---|---|
| `student_alpha@demo.invalid` | Student | Own photo/report/points; no staff mutation |
| `student_beta@demo.invalid` | Student | Cannot read Alpha private items |
| `staff_housekeeping@demo.invalid` | Staff | Can resolve only assigned housekeeping work |
| `staff_maintenance@demo.invalid` | Staff | Wrong-department access negative |
| `campus_admin@demo.invalid` | Admin | Assign, audit status, review authorized metrics |

Domains above are placeholders only; Supabase Auth may reject `.invalid` depending on setup. Use an explicitly controlled testing email mechanism, not real inboxes, when provisioning.

## Core issue fixtures
| Case ID | Seed photo concept | Category | Severity | Expected scenario |
|---|---|---|---|---|
| FIX-01 | Overflowing bin near cafeteria | waste | medium | Photo → AI suggestion → report |
| FIX-02 | Same bin photographed later | waste | medium | P1 duplicate candidate |
| FIX-03 | Leaking tap in Block B | water | high | Assign maintenance, resolve and estimate |
| FIX-04 | Broken light in Block A | electricity | low | Different category/location |
| FIX-05 | Damaged campus greenery | greenery | medium | Correct category coverage |
| FIX-06 | Ambiguous corridor scene | other | low | Manual edit/fallback |
| FIX-07 | Severe visible water leakage | water | critical | Admin severity triage and priority |
| FIX-08 | Clear unrelated photo | other | low | AI uncertainty/manual review |

## Historical hotspot sample
For a demo-only Block B water trend, seed `June:2, July:4, August:6, September:9, October:12` as given in PRD §10. Use a declared **fixture year** (not claimed to be current year). Ensure generated reports meet the approved recurrence counting policy; count cannot be altered by duplicate supporter joins.

## Reproducible seeding sequence
1. Seed canonical location and departments after approval or namespaced demo alternative.
2. Create test identities with supported Auth admin tooling, recording secure fixture IDs separately.
3. Seed reports, media links, status history and assignments with deterministic timestamps.
4. Seed points ledger through policy-consistent events, not direct mutable balances.
5. Calculate approved P1 aggregates from canonical data rather than hardcoding chart values.
6. Run assertions for expected counts, privacy isolation, state transitions and fixture references.
7. Provide `reset-demo` procedure restricted to staging/demo project only; NEVER run destructive fixture reset on production data.

## Demo verification map
| Judge step (PRD §25) | Fixture / live action |
|---|---|
| Student captures overflow | Live use FIX-01 approved image |
| AI classifies | Live Edge invocation or disclose manual fallback |
| Possible duplicate | Pre-seed FIX-02 and enable P1 detection |
| Admin sees queue | Reauthenticate as Admin and open new record |
| Cafeteria hotspot | Historical synthetic waste fixture (not Block B water trend unless explicitly switching scenario) |
| Advisor recommendation | Only if P2 truly implemented and evidence accessible |
| Staff resolves | Real authorized status transition |
| Impact recalculated | Only P1 formula with estimate label |
| Points/leaderboard | P0 points, P1 ranking separately |
| Campus score update | Only validated P1 computation; else omit demo beat |

## Fixture security/privacy
Use no personal student names, real email accounts, identifiable third-party faces or location EXIF unless explicitly consented. Keep demo photos access-protected and stable, prevent unbounded seeding in production, and mark screenshots `synthetic demonstration`.


## Agent acceptance checklist (proposed)

- [ ] Seeding is repeatable without private personal data or real-campus claims.
- [ ] Fixture students have independently testable access boundaries.
- [ ] Historical hotspot series matches seeded records and period labels.
- [ ] Every active judge-demo beat has a corresponding working fixture and test.
- [ ] No destructive demo reset can target production.

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
| `REQ-DEMO-001` | Student photographs overflowing waste bin | §25 | DEMO | DEC-012 |
| `REQ-DEMO-002` | AI classifies issue, category, severity and department | §25 | DEMO | DEC-012 |
| `REQ-DEMO-003` | System identifies potential duplicate | §25 | DEMO | DEC-012 |
| `REQ-DEMO-004` | Administrator receives prioritized report | §25 | DEMO | DEC-012 |
| `REQ-DEMO-005` | Dashboard reveals recurring cafeteria hotspot | §25 | DEMO | DEC-012 |
| `REQ-DEMO-006` | AI Advisor recommends operational change | §25 | DEMO | DEC-012, DEC-013 |
| `REQ-DEMO-007` | Admin moves issue through reported/assigned/in progress/resolved | §25 | DEMO | DEC-012 |
| `REQ-DEMO-008` | Impact metrics update | §25 | DEMO | DEC-012 |
| `REQ-DEMO-009` | Student receives EcoPoints and leaderboard changes | §25 | DEMO | DEC-012 |
| `REQ-DEMO-010` | Campus Eco Score updates | §25 | DEMO | DEC-012 |

10 source-linked rows displayed of 10 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
