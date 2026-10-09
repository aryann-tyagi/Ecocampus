---
title: 'Gemini Image Classification and Fallback Specification'
package_doc_id: ECO-15
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§3, 6–8, 18–20, 23–24'
prior_document_mapping: 'DOC-024'
priority_scope: 'P0'
date: '2026-10-10'
---

# Gemini Image Classification and Fallback Specification

> **Path:** `docs/04-intelligence/ai-image-analysis.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§3, 6–8, 18–20, 23–24; legacy registry: DOC-024.  
> **Decision gates:** `DEC-006`, `DEC-007`, `DEC-011`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## P0 behavior — PRD §§7.3, 8.1
A student supplies a photo; Gemini proposes an **issue**, **category**, **severity**, **department** and **description**. All AI-generated information is **editable before submission**. AI outages must **never block manual reporting**. PRD target for classification is **under 10 seconds**; that's a target, not a guaranteed response time.

## Canonical taxonomy
- Categories: `waste`, `water`, `electricity`, `infrastructure`, `greenery`, `cleanliness`, `other`.
- Severities: `low` (minor/limited impact), `medium` (small area/group), `high` (significant impact), `critical` (potential danger/high damage).
- Department suggestions are constrained to a seeded table, **not freeform trusted AI routing**; list of actual departments pending DEC-008.

## Proposed Gemini output JSON schema
```json
{
  "issue": "overflowing_waste_bin",
  "category": "waste",
  "severity": "medium",
  "department": "housekeeping",
  "description": "Overflowing waste bin near the cafeteria entrance."
}
```
The example shape and values originate in PRD §7.3. Optional proposal: `modelVersion`, `analysisId`, `warnings`, `confidence` only after DEC-007 approval; confidence must not be invented if model does not produce reliable calibration.

## Prompt contract — candidate
```text
System instruction:
You classify visible campus sustainability or infrastructure incidents.
You must not infer people’s identities or protected traits.
Return a single JSON object with ONLY issue, category, severity,
department, description. Category must be one of the approved enum
values. Severity must be low/medium/high/critical. If evidence is
insufficient, use category 'other', a conservative description and
surface uncertainty through controlled warnings (if schema supports).
Do not invent a precise room number, meter reading or location from
an image. User-confirmed location is authoritative.
```
Do not rely on prompt compliance alone; parse/validate server-side and reject malformed or non-taxonomy fields.

## Inference workflow
1. Flutter creates authorized private media object; obtain opaque reference.
2. Edge Function verifies identity, ownership, MIME/size and authorization.
3. Function uses server secret Gemini key, sends permitted image with constrained instructions.
4. Validate model JSON, normalize categories/severity and map department to known record.
5. Return suggestions to UI; display as **suggested** until student confirms/edits.
6. On outage/invalid output, return controlled `AI_UNAVAILABLE` and show manual form.
7. Persist submitted field values, and optionally suggestion provenance if privacy review permits; do not treat inference as final administrative decision.

## Threats and failure paths
| Scenario | Server behavior | Student UX |
|---|---|---|
| Unsupported photo | Reject with supported type message | Choose another photo |
| Oversized file | Reject per approved limits | Recompress/reselect |
| Image contains no recognizable issue | Safe `other` or unable-to-classify response | Manual edit |
| Gemini timeout/429/503 | Bound retries; no infinite waiting | Manual entry immediately available |
| Malformed JSON or invalid enum | Validation failure; never save raw classification as trusted | Manual entry |
| Suggested critical hazard | Explain urgent risk without claiming dispatch/emergency service | User confirmation + Admin workflow |
| Location hallucinated from image | Discard; never trust location from vision | Select Building/Floor/Area |
| Wrong department | Student corrects suggestion / admin overrides | Editable choice |

## Model data / evaluation plan
Construct labeled and rights-cleared image fixtures across all seven categories, all four severities where feasible, plus ambiguous photos, irrelevant images, lighting challenges and privacy-sensitive photos. Evaluate schema validity, category accuracy, useful severity suggestions, latency, fallback completion rate and hallucinated specificity. PRD sets no accuracy threshold; select proposed pass criteria for human approval rather than inventing source targets.

## Operational observability
Collect request ID, model/config version, duration, valid/invalid output, fallback reason and category distribution, avoiding raw photos and sensitive narratives in logs. Separate provider processing time from client upload and UI delay when measuring <10 sec objective.

## Guardrails
- Never directly call Gemini using a mobile-embedded secret.
- Never let model response authorize department, status, reward, identity or priority override.
- Never block manual report if model is unavailable.
- Never assume provider is deterministic across model changes; version prompts and fixtures.


## Agent acceptance checklist (proposed)

- [ ] Tests cover each category and severity enum and malformed provider output.
- [ ] User can correct every AI field before submission.
- [ ] AI outage still creates a valid report using manual entry.
- [ ] Gemini credential is absent from app/web bundles and logs.
- [ ] Latency target is measured with stated start/end conditions.

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
| `REQ-GOAL-002` | AI supports issue type, category, severity, department and description identification | §3 (G2) | BASE | DEC-007 |
| `REQ-REPORT-003` | Submit selected photo for AI analysis | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-004` | Show AI-suggested issue type | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-005` | Show AI-suggested issue category | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-006` | Show AI-suggested severity | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-007` | Show AI-suggested department | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-008` | Show AI-generated description | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-009` | Allow user to edit AI-generated fields before submission | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-010` | Support waste, water, electricity, infrastructure, greenery, cleanliness and other categories | §7.4 | P0 | DEC-007 |
| `REQ-REPORT-011` | Support Low, Medium, High and Critical severities with PRD definitions | §7.5 | P0 | DEC-007 |
| `REQ-REPORT-016` | AI unavailability must not prevent manual category/description reporting | §§7.3, 24 | P0 | DEC-007 |
| `REQ-AI-001` | Classify photo into issue type, category, severity, department and description | §8.1 | P0 | DEC-007 |
| `REQ-AI-002` | Route AI requests through a server-side Supabase Edge Function | §§18–20 | P0 | DEC-007 |
| `REQ-AI-003` | Remain operable when AI API fails or analysis output is unsuitable | §24 | P0 | DEC-007 |
| `REQ-AI-004` | Use user-confirmable and editable AI output rather than irreversible AI classification | §7.3, §24 | P0 | DEC-007 |
| `REQ-TECH-013` | AI provider is Gemini API | §§18–19 | BASE | — |

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
