---
title: 'Product Open Questions and Approval Worksheet'
package_doc_id: ECO-05
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§7–24'
prior_document_mapping: 'DOC-004'
priority_scope: 'CONTROL'
date: '2026-10-10'
---

# Product Open Questions and Approval Worksheet

> **Path:** `docs/01-product/open-questions.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§7–24; legacy registry: DOC-004.  
> **Decision gates:** `DEC-001`, `DEC-002`, `DEC-003`, `DEC-004`, `DEC-005`, `DEC-006`, `DEC-007`, `DEC-008`, `DEC-009`, `DEC-010`, `DEC-011`, `DEC-012`, `DEC-013`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## How to use
This is a **review queue**, not a set of approved answers. The existing decision register remains the authority for full option analysis and sign-off; edit outcomes there, then update this sheet and affected specifications. Product owner, technical owner and reviewer names are pending.

## Blocking review queue
| Priority | ID | Question requiring approval | Consequence if unanswered | Proposed choice (not approved) |
|---|---|---|---|---|
| P0 | DEC-004 | Who may perform each status transition, can reports reopen? | Unsafe status API | Role-bound state machine with event history |
| P0 | DEC-006 | What can a student see of *other* users' nearby/duplicate issues? | Private data disclosure | Redacted public summary only |
| P0 | DEC-010 | Are Admin and Staff separate routes and what actions may Staff perform? | Unauthorized assignment/resolution | Shared web shell with server-enforced roles |
| P0 | DEC-007 | Schema, timeout, confidence and manual fallback for Gemini? | Broken report flow | Structured validated JSON; editable/manual fallback |
| P0 | DEC-008 | What is the authoritative buildings/floors/areas dataset? | Invalid locations | Campus master data seeded in DB |
| P0 | DEC-005 | Does critical +50 replace or add to +30, and how is 'valid' defined? | Incorrect rewards/spam | Transactional, idempotent ledger |
| Release | DEC-011 | Which runtime hosts APIs and what notification channel is required for MVP? | Secrets/leaks/deployment uncertainty | Edge Functions + in-app progress; push gated |
| P0/P1 | DEC-001 | Eco Score formula and score behavior before P1 calculation? | Misleading home score | Mark pending/seed score; computed score gated |
| P0/P1 | DEC-002 | P0 queue sorting; P1 formula, weights, admin override? | Conflicting priority claims | Severity-first P0 queue; deterministic P1 model |
| P1 | DEC-003 | Duplicate threshold, join effect on records/points? | Duplicate spam/inconsistent counts | Explicit canonical issue and supporter identity |
| P1 | DEC-009 | Source/coefficients for impact estimates? | False sustainability numbers | Evidence-qualified scenario coefficients |
| P2 | DEC-012 | Exactly which stretch features will ship? | Overstated demo | P0 stable before P2 implementation |
| P2 | DEC-013 | Advisor retrieval scope, citations, simulation disclaimers? | Hallucinated decision support | Database-derived figures and labeled scenarios |

## Additional dataset and UX questions without assigned decision IDs
- Is campus email-domain validation required? (PRD §7.1 says optional; route through DEC-006.)
- Must a user include a photograph on every manual fallback? Define in report acceptance.
- What are maximum photo dimensions, bytes, and MIME types? Decide before storage/API implementation.
- Which building/floor/area names and map SVG polygons belong to the target campus?
- Is admin allowed to edit a student's description/category after submission, and how is edit provenance preserved?
- Are rejected/duplicate optional states in MVP or excluded until later?
- Should the reporting student see the name/contact of the assigned staff member?
- Is staff resolution evidence required beyond a note? PRD explicitly requires notes, not after photos.
- Which notifications require FCM vs realtime vs an in-app timeline in P0?
- Does Basic Analytics need date filtering in P0, or only summary figures?
- How are disabled/dropped notifications repaired and who owns monitoring?

## Decision record template
```yaml
id: DEC-XXX
status: PROPOSED     # APPROVED only after named human sign-off
scope: P0|P1|P2|release
question: "..."
options: ["A", "B"]
recommendation: "..."
selected_option: null
approver: null
approved_at: null
affected_requirements: []
affected_documents: []
test_evidence: []
```

## Weekly/phase review protocol
1. Before development, sort open decisions by `P0` gate and resolve in existing decision register.
2. For each accepted decision, update all downstream docs, acceptance tests and database/API contracts.
3. If deferred, create explicit fallback or remove dependent scope with documented approval.
4. At phase review, confirm implementation matches approved decision version and link corresponding PR/test evidence.
5. Preserve historical decisions; supersede rather than silently overwriting.


## Agent acceptance checklist (proposed)

- [ ] All 13 decision IDs appear and remain PROPOSED unless explicitly approved in register.
- [ ] No suggested fallback silently changes a P0/P1/P2 classification.
- [ ] All P0 and release-blocking questions have a named review gate.
- [ ] Additional ambiguous data/UX questions are recorded rather than assumed.

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
| — | This specific specification references the master registry; no direct owner rows found under legacy tags. | — | — | — |


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
