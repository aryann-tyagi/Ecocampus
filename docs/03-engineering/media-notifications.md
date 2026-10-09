---
title: 'Photo Media, Realtime Events and Notification Delivery'
package_doc_id: ECO-13
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§7.3, 17–20, 21'
prior_document_mapping: 'DOC-022; DOC-023'
priority_scope: 'CROSS'
date: '2026-10-10'
---

# Photo Media, Realtime Events and Notification Delivery

> **Path:** `docs/03-engineering/media-notifications.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§7.3, 17–20, 21; legacy registry: DOC-022; DOC-023.  
> **Decision gates:** `DEC-006`, `DEC-007`, `DEC-011`, `DEC-012`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Separate P0 and P2 concerns
**P0:** photo capture/upload, secure storage and readable report status tracking. **PRD §17:** enumerates student/admin event types. **P2:** advanced notifications (PRD §21). Do not require complete push-delivery infrastructure for core report creation unless DEC-011 approves it.

## Media pipeline — proposed
```text
Flutter camera/gallery → local preview → validate format/size → authorized upload
 → private Supabase Storage object → linked report media row
 → Edge Function verifies reporter/media access → Gemini inference
 → report saved → authorized signed retrieval for Student/Admin/assigned Staff
```

## Uploaded file controls
- PRD does not specify maximum bytes, megapixels, MIME types or retention. Decide via DEC-006/007 before production.
- Accept only supported image formats after content sniffing; do not trust filename extension, EXIF values, or client-provided MIME alone.
- Consider client resize/compression with original artifact protected when needed; strip/limit EXIF metadata, especially GPS, as privacy policy dictates.
- Prevent path traversal and arbitrary object names by generating opaque server-authorized paths.
- Remove orphan uploads after approved grace period; do not delete images on ambiguous report submit until reconcile.
- Never store Gemini API key, service role credential or base64 image logs in client or analytics.

## Access matrix — proposal
| Media user | Upload | Read |
|---|---|---|
| Owning Student | Authorized owned object | Own linked report photo |
| Unrelated Student | No | No; redacted duplicate previews only if approved |
| Assigned Staff | Only if approved | Assigned scope when operational need |
| Admin | Approved privileged operations | Campus management scope, audited |
| Gemini Edge function | Read only authorized object | Server trust boundary |

## Event catalog from PRD §17
| Audience | Event | P0 minimum visible state | Push delivery scope |
|---|---|---|---|
| Student | Report received | Submission receipt/timeline | Decision pending |
| Student | Issue assigned | Status detail | Decision pending |
| Student | In progress | Status detail | Decision pending |
| Student | Resolved | Detail + resolution note | Decision pending |
| Student | Points awarded | Updated balance/history | Decision pending |
| Student | Challenge started | P2 only | P2 |
| Student | Achievement unlocked | If implemented | Decision pending |
| Admin | Critical issue | Dashboard filter/flag | Decision pending |
| Admin | Issue spike | P1 insight | P2 advanced delivery |
| Admin | SLA approaching | Only if SLA defined | P2 advanced delivery |
| Admin | Recurring issue | P1 insight | P2 advanced delivery |

## Proposed event/outbox schema
```json
{
  "eventId": "uuid",
  "eventType": "report.resolved",
  "aggregateId": "report_uuid",
  "recipientId": "user_uuid",
  "createdAt": "UTC ISO timestamp",
  "deliveryChannels": ["in_app"],
  "status": "pending"
}
```
Outbox/in-app event is a **proposal**. Use unique `(eventId, recipientId, channel)` for dedupe; failures must be retryable with backoff without duplicating user-visible awards.

## Realtime and offline behavior
- Subscribe only to authorized rows/aggregate updates; never broadcast unredacted campus-wide reports by default.
- On foreground/resubscribe, refetch canonical state; realtime messages are hints, not sole source of truth.
- FCM tokens require permission, platform setup and safe association to authenticated account; remove stale tokens/logout mappings.
- Disable speculative push if permissions denied or platform unavailable; reporting and tracking must continue.

## Operational metrics — proposed
Track upload error rate; orphan object count; inference image read permission denials; event enqueue vs delivery successes; token invalidations; realtime reconnects. Exclude raw image bytes and private narratives from dashboards.

## Acceptance scenarios
1. User can upload and view their own linked photo; another Student cannot.
2. Gemini unavailable leaves manual reporting usable and media retrievable for submit.
3. Status update is visible after refetch even with realtime disconnected.
4. Duplicate delivery attempt does not duplicate an in-app event or points transaction.
5. Push permissions denied do not block submission or core tracking.


## Agent acceptance checklist (proposed)

- [ ] Photo pipeline rejects invalid/unauthorized objects without exposing secret URLs.
- [ ] Realtime state can be recovered by read/refetch after disconnect.
- [ ] P2 push delivery remains independent from P0 status visibility.
- [ ] Privacy and notification retention policies are explicitly gated.

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
| `REQ-FLOW-003` | Resolve issue through administrator/staff workflow and make updated state visible to the reporting student | §6, §7.7 | CROSS | DEC-004, DEC-011 |
| `REQ-REPORT-001` | Offer camera capture for an issue photograph | §7.3 | P0 | — |
| `REQ-REPORT-002` | Offer photo selection/upload from device | §7.3 | P0 | — |
| `REQ-NOTIF-001` | Student notification event: Report received | §17.1 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-002` | Student notification event: Issue assigned | §17.1 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-003` | Student notification event: Issue in progress | §17.1 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-004` | Student notification event: Issue resolved | §17.1 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-005` | Student notification event: Points awarded | §17.1 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-006` | Student notification event: Challenge started | §17.1 | P2-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-007` | Student notification event: Achievement unlocked | §17.1 | P2-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-008` | Administrator notification event: Critical issue | §17.2 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-009` | Administrator notification event: Issue spike | §17.2 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-010` | Administrator notification event: SLA approaching | §17.2 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-NOTIF-011` | Administrator notification event: Recurring issue detected | §17.2 | CROSS-NOTIFY | DEC-011, DEC-012 |
| `REQ-TECH-010` | Photo/media persistence uses Supabase Storage | §§18–19 | BASE | — |
| `REQ-TECH-011` | Realtime capability uses Supabase Realtime | §§18–19 | BASE | — |
| `REQ-TECH-014` | Notifications stack includes Firebase Cloud Messaging | §§18–19 | BASE | DEC-011 |

17 source-linked rows displayed of 17 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
