---
title: 'Duplicate Detection and Smart Priority Engine'
package_doc_id: ECO-16
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§6, 8.2–8.3, 11, 21'
prior_document_mapping: 'DOC-025; DOC-026'
priority_scope: 'P1'
date: '2026-10-10'
---

# Duplicate Detection and Smart Priority Engine

> **Path:** `docs/04-intelligence/duplicate-priority-engine.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§6, 8.2–8.3, 11, 21; legacy registry: DOC-025; DOC-026.  
> **Decision gates:** `DEC-002`, `DEC-003`, `DEC-004`, `DEC-005`, `DEC-006`, `DEC-008`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Priority classes
Both **duplicate detection** and **smart priority scoring** are P1 in PRD §21. For P0, ordinary admin issue filtering and sorting must remain useful even if neither engine is deployed. P0 fallback sorting rule must be approved (`DEC-002`), not mislabeled as intelligent scoring.

## Duplicates: signals the PRD requires considering
1. Same or compatible **category**.
2. Hierarchical **campus location** (building/floor/area, not solely GPS).
3. **Description similarity**.
4. **Time proximity**.
5. **Image similarity where available** (advanced similarity itself P2).

### Proposed matching stages
```text
New report → filter permitted candidates by location/category/time →
normalize description (tokenization) → compute interpretable signal scores →
weight/aggregate → rank top candidates → display redacted candidate →
student chooses Join Existing Issue or Report Anyway
```

### Proposed candidate data model
```json
{
  "candidateIssueId": "opaque-id",
  "category": "electricity",
  "locationLabel": "Block A, Room 204",
  "summary": "Broken light",
  "similarityScore": null,
  "canJoin": true
}
```
`91% similarity` in PRD §8.2 is an example **not a calibrated acceptance threshold**. Decide lower/upper thresholds, handling of uncertain candidates and minimum disclosure in `DEC-003`.

### Duplicate policies requiring sign-off
- Canonical `issue` vs multiple independent `reports`; how does a join affect status tracking and owner identity?
- Can same reporter join multiple times? How are abusive repeated joins prevented?
- Whether one 'supporter' increases priority and whether supporters receive points.
- When two partially related complaints must remain distinct despite same location/category.
- How resolved/rejected reports participate in search; allowed time window and privacy.

## Smart priority: PRD §8.3 inputs
`severity`, `number_of_reports`, `recurrence`, `age`, `location_impact` → a score/ranking. Examples `24/100 broken chair`, `81/100 cafeteria waste`, `94/100 major water leak` are illustrative.

### Candidate formula for human review (NOT approved)
```text
score = clamp(0,100,
   0.50 * severity_subscore
 + 0.20 * validated_unique_supporter_subscore
 + 0.15 * recurrence_subscore
 + 0.10 * age_subscore
 + 0.05 * location_impact_subscore )
```
Weights come from proposed DEC-002 guidance, **not PRD**. Each subscore scale, cap, missing-data convention, threshold band and override policy require review.

### Priority invariants to test
- Deterministic given the same authoritative data and versioned formula.
- Score finite and within `[0,100]`; never NaN or >100.
- With other factors constant, a higher severity never lowers ranking unless explicitly designed.
- Repeated supporter joins or duplicated event delivery must not artificially increase count.
- Age bounded to prevent oldest issue dominating critical incidents forever.
- Admin manual override permission/audit and precedence must be specified.

## Edge cases
| Case | Expected proposed handling |
|---|---|
| Incomplete location | Exclude unreliable geographic signal; no false certainty |
| Category `other` | Lower category confidence; don't suppress valid reports |
| Similar description but different buildings | Keep separate unless cross-building policy approved |
| Same photo used twice | Do not assume same actionable issue without other evidence |
| Existing report already resolved | May show as historical candidate, not active join, pending policy |
| Unauthorized candidate | Use redacted summary only; never reveal reporter/photo |
| Staff overrides severity | Recompute or preserve manual priority according to DEC-002 |

## Evaluation fixtures and scenarios
- Same broken light, same room, same week: high-likelihood duplicate expected **qualitatively**, numeric threshold TBD.
- Same category in different buildings: usually not duplicate.
- Two legitimate water leaks on different floors: distinct candidates even with similar text.
- Critical water leak vs broken chair: critical expected ahead when manual fallback sorting approved.
- Two concurrent duplicate joins: supporter recorded once and eligible points not double-awarded.

## Persistence and auditing
Store signal breakdown, engine version, candidate timestamp, approved join choice and report/issue relationship if modeled. Priority score recomputation should be driven by data changes (status, supporter count, recurrence), not arbitrary client values. Model outputs are suggestions, not permission to mutate an existing issue without verified consent and business rules.


## Agent acceptance checklist (proposed)

- [ ] No duplicate threshold or scoring weights are described as PRD facts.
- [ ] P0 report flow works without P1 engines.
- [ ] Candidates are narrowed securely and return privacy-safe previews only.
- [ ] Priority invariants are unit tested with deterministic fixtures.
- [ ] Duplicate joining does not create double rewards or duplicate environmental totals.

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
| `REQ-FLOW-002` | Run duplicate detection and smart priority in issue processing when their features are enabled | §6, §21 | P1 | DEC-002, DEC-003 |
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
| `REQ-PRIO-003` | Smart priority considers recurrence | §8.3, §11.1 | P1 | DEC-002 |
| `REQ-PRIO-004` | Smart priority considers issue age | §8.3, §11.1 | P1 | DEC-002 |
| `REQ-PRIO-005` | Smart priority considers location impact | §8.3, §11.1 | P1 | DEC-002 |
| `REQ-PRIO-006` | Issue priority can be changed in admin dashboard | §8.3, §11.1 | CROSS | DEC-002 |

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
