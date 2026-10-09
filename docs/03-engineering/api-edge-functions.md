---
title: 'API and Supabase Edge Function Contracts'
package_doc_id: ECO-11
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§6–8, 11–14, 18–20'
prior_document_mapping: 'DOC-020'
priority_scope: 'CROSS'
date: '2026-10-10'
---

# API and Supabase Edge Function Contracts

> **Path:** `docs/03-engineering/api-edge-functions.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§6–8, 11–14, 18–20; legacy registry: DOC-020.  
> **Decision gates:** `DEC-003`, `DEC-004`, `DEC-005`, `DEC-006`, `DEC-007`, `DEC-011`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Contract conventions — proposed
Routes below are **candidate endpoints** consistent with the PRD architecture, not existing APIs. Prefer `/functions/v1/<name>`, authenticated JWT, JSON success/error envelopes, request IDs, schema validation and no Gemini credentials in clients.

| Logical operation | Candidate route | Auth / role | Tier |
|---|---|---|---|
| Analyze photo | `POST /functions/v1/analyze-report` | Student/authorized reporter | P0 |
| Submit report | `POST /functions/v1/create-report` (or RLS-guarded DB insert) | Student | P0 |
| Assign department | `POST /functions/v1/assign-report` | Admin | P0 |
| Change report status | `POST /functions/v1/transition-report` | Admin or assigned Staff | P0 |
| Check duplicates | `POST /functions/v1/find-duplicates` | Student, redacted output | P1 |
| Recompute score | `POST /functions/v1/compute-building-score` | Trusted service/Admin | P1 |
| Query advisor | `POST /functions/v1/ask-advisor` | Admin | P2 |
| Simulate changes | `POST /functions/v1/simulate-impact` | Admin | P2 |

## Example analyze-report request/response
```json
{
  "imagePath": "report-uploads/USER_UUID/OBJECT_UUID.jpg",
  "locale": "en",
  "requestId": "client-generated-uuid"
}
```
```json
{
  "ok": true,
  "data": {
    "issue": "overflowing_waste_bin",
    "category": "waste",
    "severity": "medium",
    "department": "housekeeping",
    "description": "Overflowing waste bin near the cafeteria entrance."
  },
  "requestId": "client-generated-uuid"
}
```
`issue/category/severity/department/description` come from PRD §7.3; `imagePath`, `locale`, `ok`, `requestId` and envelope are **proposals**. The function must validate ownership of private file, parse schema, reject unsupported enums, and return controlled manual-entry fallback on provider failure.

## Example create-report submission — proposed
```json
{
  "idempotencyKey": "uuid-stable-across-retry",
  "mediaId": "authorized-upload-id",
  "issue": "overflowing_waste_bin",
  "category": "waste",
  "severity": "medium",
  "description": "Bin overflowing near cafeteria",
  "buildingId": "uuid",
  "floorId": "uuid",
  "areaId": "uuid",
  "suggestedDepartmentId": "uuid-or-null"
}
```
**Never accept** `reporterId`, arbitrary points totals, admin-assigned status or trusted AI score from a Student payload. Server derives user identity from token and checks location hierarchy.

## Transition request and response — proposed
```json
{
  "reportId": "uuid",
  "expectedStatus": "ASSIGNED",
  "nextStatus": "IN_PROGRESS",
  "resolutionNote": null,
  "requestId": "uuid"
}
```
The authoritative status is evaluated under lock/optimistic concurrency; invalid/unauthorized transitions must fail. When approved, save immutable status history and create eligibility events transactionally.

## Error envelope and HTTP behavior — proposal
| Status | Error code | Client action |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Fix field, retain draft |
| 401 | `UNAUTHENTICATED` | Sign in again |
| 403 | `FORBIDDEN` | Do not reveal protected resource |
| 404 | `NOT_FOUND` | Explain unavailable item |
| 409 | `CONFLICT` | Refresh and review current state |
| 413 | `IMAGE_TOO_LARGE` | Recompress/reselect |
| 429 | `RATE_LIMITED` | Respect retry-after |
| 502/503 | `AI_UNAVAILABLE` | Manual reporting path |
| 500 | `INTERNAL_ERROR` | Retry with correlation ID; redact internals |

## Security and abuse controls
- Verify JWT and role server-side for every request; never trust role headers/body.
- Restrict CORS to approved origins for browser and avoid assuming CORS is authorization.
- Use request-body bounds, file content checks, rate limits, safe provider timeouts and output schema validation.
- Protect server secret vars in Edge runtime; client public keys can only be anonymous/ publishable Supabase keys governed by RLS.
- Logs redact access tokens, base64 photo bytes, private photos, personal narratives and Gemini API key.

## Retry/idempotency and cross-boundary handling
- GET/read may safely retry; writes require stable idempotency token or precondition check.
- `analyze-report` retry must not produce duplicate reports (separate analysis from submission).
- `transition-report` and point issuance must be duplicate-safe; no direct client points write.
- Promise of sub-10-second analysis is a PRD target, not always guaranteed when provider is down; timeout leads to manual path.

## API contract review gate
For every route specify final URL, method, exact request/response type, auth principal, rate limit, failure mapping, data ownership, tests, monitoring, example cURL and deployment environment. No route is implementation-authoritative until reviewed alongside DB/RLS and DEC approvals.


## Agent acceptance checklist (proposed)

- [ ] AI endpoint rejects an unauthorized image reference; key never reaches client.
- [ ] Unknown category/severity and invalid location linkage fail closed.
- [ ] Duplicate transition and retry do not trigger duplicate points/history.
- [ ] Student role is denied admin and staff mutation routes.
- [ ] Error responses do not leak tokens, internal traces or other users’ data.

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
| `REQ-REPORT-003` | Submit selected photo for AI analysis | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-015` | Create a trackable report after student confirmation | §§7.3, 24 | P0 | DEC-004 |
| `REQ-AI-001` | Classify photo into issue type, category, severity, department and description | §8.1 | P0 | DEC-007 |
| `REQ-AI-002` | Route AI requests through a server-side Supabase Edge Function | §§18–20 | P0 | DEC-007 |
| `REQ-TECH-012` | Server-side logic uses Supabase Edge Functions | §§18–19 | BASE | — |

5 source-linked rows displayed of 5 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
