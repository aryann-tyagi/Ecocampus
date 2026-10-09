---
title: 'Campus SVG Map, Recurrence Detection and Hotspots'
package_doc_id: ECO-17
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§7.6, 9–10, 11.2, 21'
prior_document_mapping: 'DOC-027; DOC-031'
priority_scope: 'P1'
date: '2026-10-10'
---

# Campus SVG Map, Recurrence Detection and Hotspots

> **Path:** `docs/04-intelligence/campus-map-hotspots.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§7.6, 9–10, 11.2, 21; legacy registry: DOC-027; DOC-031.  
> **Decision gates:** `DEC-001`, `DEC-002`, `DEC-006`, `DEC-008`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## MVP representation
PRD §9 calls for a **2D interactive campus map** rather than a 3D digital twin. Each building displays an Eco Score and issue information. The asset is custom SVG (PRD §19); actual campus SVG/building coordinates are **not supplied**.

## Canonical location hierarchy
```text
Campus (one MVP institution)
 └─ Building (ID, name, svg_region_key)
     └─ Floor (ID, building_id, display label)
         └─ Area (ID, floor_id, display label)
```
MVP reporting uses Building → Floor → Area; optional GPS may be stored but must not replace this authoritative relation. Approval under DEC-008 required for names, SVG keys and active location list.

## SVG map interaction (P1)
1. Load authorized campus building metadata + current approved score representation.
2. Match `building.svg_region_key` to corresponding `<path>`/`<g>` in SVG.
3. Render textual label and score with legend that is usable without color.
4. On click/tap/keyboard selection, open building profile with active/resolved counts and category breakdown.
5. If no score data, label `Not yet calculated`; never invent value `91` or `61` from PRD sketch.
6. Provide tabular/list fallback when SVG missing or screen reader is used.

## Building profile — PRD §9.1 fields
Eco Score /100; Waste, Water, Energy, Greenery, Maintenance sub-scores; Active Issues, Resolved, Recurring Issues. The PRD gives a sample Block B with `Eco Score 61`, `Active Issues 12`, `Resolved 47`, `Recurring 3`—these are **illustrative UI values**.

## Hotspot/recurrence semantics to decide
- Recurrence window: daily/weekly/monthly? minimum reports? category/location granularity?
- Count distinct **issues** vs **reports/supporters**; avoid inflating repeated reports joined under duplicates.
- Relative vs absolute threshold; campus-wide baselines; building population footfall unavailable.
- Current state vs history: trends must use incident occurrence timestamps and scoped timezone.
- Confidence and small denominators: show absolute counts and date range, not merely 'significant' without statistical definition.

## Proposed deterministic aggregation
```sql
-- Illustration only: counting model depends on DEC-003.
select building_id, category, date_trunc('month', created_at) as month,
       count(distinct report_id) as report_count
from report_building_view
where created_at >= :from and created_at < :to
group by building_id, category, date_trunc('month', created_at);
```
Real implementation must use approved building join, no unsafe raw SQL parameters, and privacy-suitable aggregate views.

## PRD historical trend example
Block B, water issue counts: June 2; July 4; August 6; September 9; October 12. Example recommendation: inspect plumbing infrastructure. This illustrates expected storytelling; **not observed campus measurements** and not a fixed model output.

## Hotspot UI and evidence contract
Each insight must carry location ID, issue category, time range, counts by period, comparison baseline and representative permitted issue links. If the requested interval lacks data, show `insufficient data`. Any recommendation is descriptive operational advice, not proof of cause.

## Failure and integrity cases
- SVG region with no database building: flag data mismatch, hide misleading score.
- Building not present in SVG: include in textual list so issue isn't invisible.
- Rename building: preserve UUID references and migrate SVG key intentionally.
- Invalid floor/area selection: refuse report before submission.
- A single incident reported 20 times: decide deduplicated hotspot counts before using in analytics.
- Reports of sensitive incidents: suppress personally identifying map drill-down in student/public views.

## Test fixtures
Create 3+ buildings including one with zero reports; two floors within a building; two categories with distinct trends; deliberate broken SVG mapping; no-history view; one duplicated incident; timezone-boundary reports. Assert stable counts and correct drill-down.


## Agent acceptance checklist (proposed)

- [ ] Map links to correct building and respects authorized score data.
- [ ] Each reported area maps to its legitimate building/floor hierarchy.
- [ ] No historical seeded series is presented as measured institutional fact.
- [ ] Hotspot result shows date window, count methodology and reasoned recommendation.
- [ ] Keyboard/text list provides access independent of SVG visual interaction.

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
| `REQ-GOAL-004` | Surface recurring issue patterns and campus hotspots | §3 (G4) | P1 | DEC-008 |
| `REQ-REPORT-013` | Let student select Building → Floor → Area for MVP location | §7.6 | P0 | DEC-008 |
| `REQ-REPORT-014` | Allow optional GPS coordinates without making GPS compulsory | §7.6 | P0 | DEC-008 |
| `REQ-MAP-001` | Provide a 2D interactive campus map rather than 3D digital twin | §9 | P1 | DEC-001, DEC-008 |
| `REQ-MAP-002` | Display building-specific Eco Score on map | §9 | P1 | DEC-001, DEC-008 |
| `REQ-MAP-003` | Display building issue information on map | §9 | P1 | DEC-001, DEC-008 |
| `REQ-MAP-004` | Provide building sustainability profile | §9 | P1 | DEC-001, DEC-008 |
| `REQ-MAP-005` | Show example profile dimensions: Waste, Water, Energy, Greenery, Maintenance | §9 | P1 | DEC-001, DEC-008 |
| `REQ-MAP-006` | Show active, resolved and recurring issue totals in building profile | §9 | P1 | DEC-001, DEC-008 |
| `REQ-HOT-001` | Analyze historical reports for repeated problems | §10 | P1 | DEC-008, DEC-003 |
| `REQ-HOT-002` | Detect campus hotspots with unusually high issue frequency | §10 | P1 | DEC-008, DEC-003 |
| `REQ-HOT-003` | Identify increasing problem counts over time | §10 | P1 | DEC-008, DEC-003 |
| `REQ-HOT-004` | Provide actionable recurring-issue insight | §10 | P1 | DEC-008, DEC-003 |
| `REQ-TECH-015` | MVP map representation uses custom SVG campus map | §§18–19 | BASE | DEC-008 |

14 source-linked rows displayed of 14 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
