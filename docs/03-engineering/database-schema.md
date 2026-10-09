---
title: 'PostgreSQL Database Schema and Migration Contract'
package_doc_id: ECO-10
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§5–14, 17, 20–21'
prior_document_mapping: 'DOC-019'
priority_scope: 'CROSS'
date: '2026-10-10'
---

# PostgreSQL Database Schema and Migration Contract

> **Path:** `docs/03-engineering/database-schema.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§5–14, 17, 20–21; legacy registry: DOC-019.  
> **Decision gates:** `DEC-001`, `DEC-003`, `DEC-004`, `DEC-005`, `DEC-006`, `DEC-008`, `DEC-009`, `DEC-010`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Modeling status
**This is a candidate relational model, not an existing applied database schema.** The PRD specifies PostgreSQL via Supabase but does not supply SQL table definitions. Resolve approval gates before production migrations. Prefer UUID identifiers and timestamps with timezone as proposed conventions.

## Entity catalog (proposed)
| Table | Key / illustrative columns | Purpose / relationship | Tier |
|---|---|---|---|
| `profiles` | `user_id PK/FK auth.users`, display_name, role | Identity-visible metadata (never passwords) | P0 |
| `departments` | id, name, active | Assignment target | P0 |
| `buildings` | id, name, slug, active, svg_region_key | Top-level location | P0; SVG P1 |
| `floors` | id, building_id FK, label, sort_order | Child of Building | P0 |
| `areas` | id, floor_id FK, name, active | Child of Floor | P0 |
| `reports` | id, reporter_id, area_id, category, severity, description, issue_label, status, created_at | Authoritative submitted report | P0 |
| `report_media` | id, report_id, storage_path, mime_type, uploader_id | Private photo associations | P0 |
| `report_assignments` | id, report_id, department_id, assignee_id?, assigned_by, assigned_at | Assignments; exact cardinality pending DEC-010 | P0 |
| `report_status_events` | id, report_id, from_status, to_status, actor_id, note, occurred_at | Append-only workflow audit | P0 |
| `points_ledger` | id, user_id, event_key UNIQUE, points_delta, report_id?, reason | Reward source of truth | P0 |
| `notification_events` | id, event_type, recipient_id, reference_id, delivery_status | Delivery bookkeeping | P2/conditional |
| `report_supporters` | report_id/issue_id, user_id, joined_at | P1 duplicate joining if approved | P1 |
| `duplicate_candidates` | source_report, matched_report, score, evidence | Algorithm results; avoid cross-user photo leak | P1 |
| `building_score_snapshots` | building_id, score_version, window, value, breakdown | Historical reproducible score | P1 |
| `impact_estimates` | report_id, metric_key, unit, value, method_version | Qualified modeled impacts | P1 |
| `challenge_definitions` / `challenge_participation` | challenge, user, progress | Optional Eco Challenges | P2 |

## Important SQL constraints — proposed
```sql
-- Illustrative sketch: names and exact constraints require schema approval.
create type public.report_status as enum
  ('REPORTED', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED');
create type public.issue_category as enum
  ('waste','water','electricity','infrastructure','greenery','cleanliness','other');
create type public.issue_severity as enum
  ('low','medium','high','critical');
-- reports.reporter_id references auth.users(id); area_id references areas(id).
-- points_ledger.event_key unique prevents one event being rewarded twice.
-- report_status_events rows should be immutable to ordinary client roles.
```
**Caution:** Optional `REJECTED` and `DUPLICATE` status choices require DEC-004. Prefer not to deploy a hard-to-extend enum without agreement about migration strategy.

## Row-level authorization intent
- `profiles`: self read/edit permitted profile columns; privileged role assignment only via trusted admin flow.
- `reports`: Student reads own, creates own; no Student write of privileged status fields. Admin reads/manages campus reports; Staff scope to assigned department only (`DEC-006/010`).
- `report_media`: private reference; signed access only after report-level authorization.
- `report_status_events`, `report_assignments`, `points_ledger`: never editable directly by a Student.
- `buildings/floors/areas`: authenticated read for active records; privileged writes only.
- `analytics`: personal data minimization and aggregation boundaries reviewed before exposing APIs.

## Index plan — proposed
- `reports(reporter_id, created_at DESC)` for own history.
- `reports(status, severity, created_at)` for admin queue.
- `reports(area_id, category, created_at)` for P1 hotspot/duplicate narrowing.
- `report_assignments(department_id, assigned_at)` for staff workloads.
- `report_status_events(report_id, occurred_at)` for timeline.
- `points_ledger(user_id, created_at)` + unique event_key for ranking and deduplication.
- Spatial GPS index only if geospatial search is approved; location hierarchy is MVP source of truth.

## Migration discipline
1. Number migration files monotonically and commit to source control; no manual production-only edits.
2. Create enums/lookups and campus hierarchy before dependent reports.
3. Add constraints/foreign keys before exposing writes; apply RLS policies and tests in same phase.
4. Seed reference locations separately from demo/production data.
5. For schema changes, add forward migration + tested rollback/restore plan; prefer additive changes.
6. Generate and check typed API client models after migrations; never trust untyped strings for enum/status.

## Proposed transaction boundaries
- `create_report`: verify user + location + media ownership and insert report atomically as far as possible.
- `transition_report`: validate actor/current state + append event in one transaction; optional event ledger issuance idempotent.
- `award_points`: unique `event_key` and origin authorization.
- `calculate_impacts`: versioned, repeatable derived results; no fake sensor readings.

## Privacy and retention unknowns
No explicit retention duration, deletion policy, campus tenant model, or formal audit retention period appears in PRD. List as pending policy/decision instead of assuming GDPR/Indian DPDP-specific implementation. Additional campuses/tenants are out of current scope until approved.


## Agent acceptance checklist (proposed)

- [ ] All proposed FK relationships have a valid creation/migration order.
- [ ] RLS denies Student modifications to points, assignments, staff fields and others’ reports.
- [ ] Repeated reward event key causes zero additional credit.
- [ ] Report area belongs to an existing floor/building; malformed relations are rejected.
- [ ] Migrations and rollback/restore are tested on a clean environment.

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
| `REQ-REPORT-014` | Allow optional GPS coordinates without making GPS compulsory | §7.6 | P0 | DEC-008 |
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
| `REQ-TECH-008` | Relational database uses PostgreSQL | §§18–19 | BASE | — |

16 source-linked rows displayed of 16 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
