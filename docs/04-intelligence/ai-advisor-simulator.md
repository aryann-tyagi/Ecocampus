---
title: 'AI Sustainability Advisor and What-If Simulation'
package_doc_id: ECO-20
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§10, 14–16, 21, 25'
prior_document_mapping: 'DOC-029'
priority_scope: 'P2'
date: '2026-10-10'
---

# AI Sustainability Advisor and What-If Simulation

> **Path:** `docs/04-intelligence/ai-advisor-simulator.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§10, 14–16, 21, 25; legacy registry: DOC-029.  
> **Decision gates:** `DEC-001`, `DEC-006`, `DEC-009`, `DEC-012`, `DEC-013`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Delivery boundary
Both the **AI Sustainability Advisor** and **What-If Simulator** are **P2 stretch** features (PRD §21). A full running solution is not required to claim P0 complete. They rely on approved P1 analytics, scores, hotspots, and estimates.

## Advisor questions from PRD §15
- What is the biggest sustainability problem this month?
- Which building needs attention?
- Why has our Eco Score decreased?
- What should we prioritize this week?

Responses must contain **evidence from application data** and **practical recommendations**. The PRD does not authorize querying unrelated institution data or external campus sensors.

## Proposed advisor architecture
```text
Authenticated Admin question → server-side validation → scoped DB aggregate queries
 → sanitized context bundle (period, category, building, counts, source IDs)
 → Gemini with instruction to ground answers ONLY in bundle
 → server output validation → UI answer + evidence/source/time + caveats
```
Avoid passing personally identifying reporter data or user-uploaded images unless separately required and authorized. A role-authorized SQL/query layer—not a model-written unrestricted SQL string—should retrieve data.

## Structured response contract (proposed)
```json
{
  "answer": "Water incidents rose across Block B during the selected period.",
  "period": {"from":"YYYY-MM-DD","to":"YYYY-MM-DD"},
  "evidence": [
    {"metric":"water_report_count","buildingId":"uuid","value":12,"unit":"reports","source":"issue_aggregate"}
  ],
  "recommendations": ["Inspect plumbing and review recurring leak locations."],
  "limitations": ["Report counts are not measured liters saved."]
}
```
`12` mimics PRD illustrative trend; never present as fetched result without actual authorized underlying data.

## Advisor requirements
- If evidence missing, answer `Insufficient data` rather than hallucinating cause.
- Every numeric claim must map to authorized query output and explicit period.
- Recommendations framed operationally (`consider inspecting`), not guaranteed outcomes.
- Responses must not leak personal notes/emails/photos, even when prompted maliciously.
- Store question/logs according to pending retention policy; sanitize source context.

## What-If Simulator — PRD §16
Inputs: selected interventions (resolve top water/waste/energy issues, etc.). Output: current Eco Score, **projected** Eco Score and estimated water/energy/waste impact. PRD example `82→88`, `+2400 L water/week`, `+84 kWh energy/week`, `+42 kg waste/week` is illustrative **not a validated prediction**.

## Proposed simulation algorithm
1. Fetch current approved baseline score version and eligible issue set.
2. Generate a scenario copy of issue states; **do not mutate live reports**.
3. Mark selected interventions as hypothetical resolved; apply same approved Eco Score/impact functions as real analytics.
4. Calculate `projected - baseline` for approved units and periods.
5. Return assumptions, modeled interventions, evidence quality, formula versions and disclaimer.
6. Warn for insufficient history or undefined formula; do not output invented projection.

## Simulator acceptance fields
| Field | Role | Condition |
|---|---|---|
| Current score | Grounded metric | Requires DEC-001 approval |
| Selected intervention IDs | Candidate inputs | Must be authorized and unresolved |
| Projected score | Scenario output | Must be labeled projected/estimate |
| Water/energy/waste metrics | Modeled deltas | Requires DEC-009 coefficients and consistent units |
| Assumptions and period | Disclosure | Mandatory in UI and export |
| Source evidence | Auditable links | Redacted and privacy-compliant |

## Safety/quality tests
- Prompt injection in issue descriptions cannot override model/system instructions or cause arbitrary database query.
- Unauthorized Student cannot call admin-only Advisor endpoint.
- Numeric response unsupported by query evidence must be rejected/annotated.
- Null/zero-data baseline produces no false projections.
- Scenario calculation changes **no live report** or reward ledger.
- A different scorer version is either recomputed consistently or clearly flagged.

## Honest demo fallback
If P2 is not deployed, show a storyboard with `Concept / planned` label rather than a fabricated live Advisor answer. If deployed with seeded history, label all evidence `demo fixture data`.


## Agent acceptance checklist (proposed)

- [ ] Advisor responses only use authorized aggregate application evidence.
- [ ] No unsupported numeric conclusion or sensor claim is emitted.
- [ ] Simulator is side-effect-free and always labels projection/assumptions.
- [ ] P2 is independently gated and no false 'live' demo claim is made.
- [ ] Injection and unauthorized access tests pass before enabled for Admin.

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
| `REQ-ADVISOR-001` | Allow administrator to ask natural-language sustainability questions using application data | §15 | P2 | DEC-013, DEC-012 |
| `REQ-ADVISOR-002` | Support identifying major sustainability issue of a period | §15 | P2 | DEC-013, DEC-012 |
| `REQ-ADVISOR-003` | Support identifying buildings needing attention | §15 | P2 | DEC-013, DEC-012 |
| `REQ-ADVISOR-004` | Support explaining Eco Score changes | §15 | P2 | DEC-013, DEC-012 |
| `REQ-ADVISOR-005` | Support recommending weekly priorities | §15 | P2 | DEC-013, DEC-012 |
| `REQ-ADVISOR-006` | Ground advisor answers in application evidence and practical recommendations | §15 | P2 | DEC-013, DEC-012 |
| `REQ-SIM-001` | Let administrator select interventions such as resolving top water/waste/energy issues | §16 | P2 | DEC-001, DEC-009, DEC-013 |
| `REQ-SIM-002` | Calculate estimated projected Eco Score after intervention | §16 | P2 | DEC-001, DEC-009, DEC-013 |
| `REQ-SIM-003` | Display estimated projected environmental impact with units | §16 | P2 | DEC-001, DEC-009, DEC-013 |
| `REQ-SIM-004` | Disclose that simulated outcomes are not guaranteed predictions | §16 | P2 | DEC-001, DEC-009, DEC-013 |

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
