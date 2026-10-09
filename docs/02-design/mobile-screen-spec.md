---
title: 'Flutter Student Mobile Screen Specification'
package_doc_id: ECO-06
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§5.1, 6–7, 9, 12–13, 17, 21'
prior_document_mapping: 'DOC-013'
priority_scope: 'P0/P1/P2'
date: '2026-10-10'
---

# Flutter Student Mobile Screen Specification

> **Path:** `docs/02-design/mobile-screen-spec.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§5.1, 6–7, 9, 12–13, 17, 21; legacy registry: DOC-013.  
> **Decision gates:** `DEC-001`, `DEC-004`, `DEC-005`, `DEC-006`, `DEC-007`, `DEC-008`, `DEC-012`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Platform, shell and navigation
**PRD baseline:** Flutter + Dart + Riverpod; Android/iOS; Student authentication and home/report/tracking capabilities. The explicit route names below are **design proposals**; they are not defined in PRD.

```text
AuthGate
 ├─ /auth/login
 ├─ /auth/register
 ├─ /auth/reset-password
 └─ /app
     ├─ /home
     ├─ /reports/new/photo → /reports/new/analyze → /reports/new/review → /reports/new/location → /reports/new/confirm
     ├─ /reports → /reports/:id
     ├─ /campus-map (P1)
     ├─ /rewards → /leaderboard (P1) → /challenges (P2)
     └─ /profile
```

## Screen contract MS-01 — Login / register / reset (P0)
- **Content:** email/password, clear registration/login actions, reset link, loading/errors, sign-out path.
- **Validation:** nonempty valid email shape, Supabase rules for password; optional university domain restriction only after decision.
- **State:** `idle → submitting → success|validation_error|auth_error|network_error`.
- **Security:** never expose password in logs; authenticated route protection; sessions refreshed only through Supabase client lifecycle.
- **Acceptance:** invalid credentials show a safe error; returning user restores the correct signed-in state; session expiry redirects without leaking prior private data.

## MS-02 — Student Home (P0)
- **Header:** greeting/profile action, campus identity if known.
- **Primary:** highly visible `Report Issue` CTA with camera icon.
- **Widgets (PRD §7.2):** Campus Eco Score, personal impact, active challenge, nearby issues.
- **Gating:** P1 calculated score and P2 challenge state can be placeholders clearly labeled unavailable; never fabricate computed results.
- **States:** empty account, no location permission, analytics unavailable, slow network; home must remain navigable.

## MS-03 — Photo capture / upload (P0)
- Buttons `Take Photo`, `Choose from Gallery`; local preview; replace/remove; progress indicator.
- Permission denial presents gallery fallback; unsupported/corrupt photo is rejected with clear recovery action.
- Accessibility: labels on icon buttons, meaningful error text, no camera-only path.
- Upload request initiated only after user confirmation; media owner and path must be checked server-side.

## MS-04 — AI analysis and correction (P0)
- Show in-progress analysis with honest status, retry option and `Enter Manually` route.
- Render editable issue type, category, severity, suggested department and description (PRD §7.3).
- Categories: waste, water, electricity, infrastructure, greenery, cleanliness, other.
- Severity names: Low, Medium, High, Critical with PRD definitions in helper text.
- Do not imply confidence score guaranteed; confidence UI is gated behind `DEC-007`.
- AI failure shows manual entry preserving existing user-provided photo/location.

## MS-05 — Location picker (P0)
- Three dependent controls `Building → Floor → Area`, using canonical IDs; reset floor/area when parent changes.
- Optional GPS action separated from mandatory hierarchical picker.
- Empty building list: submission cannot proceed with invented geography; provide actionable retry/admin setup message.
- Confirmation summary shows readable full location, not raw IDs.

## MS-06 — Confirmation / submit receipt (P0)
- Summary includes photograph preview, final category/severity, department *suggestion*, user-edited description, selected location.
- `Submit Report` disabled while request in flight; show explicit retry with same submission token (proposed idempotency).
- Success: human-readable report ID, initial status, `Track Report` and `Back Home` actions.
- Failure: differentiate validation, expired auth, storage problem and ambiguous network outcome; avoid silent duplicate submission.

## MS-07 — My Reports and Report Detail (P0)
- Tabs/filters: Active, Resolved; each card includes issue, category, submitted date, location and status.
- Detail: own report photo, description, current status, timeline, safe resolution notes, department when approved.
- States: no reports yet, deleted/denied report, network, loading skeleton, pull-to-refresh.
- Do not allow a Student to modify status/priority/assignment via UI or data layer.

## MS-08 — Campus Map / Building Profile (P1)
- SVG map with buildings and Eco Scores; select building to see Waste/Water/Energy/Greenery/Maintenance metrics, counts, recurrence where supported.
- Screenreader has textual building list and score summary as alternative to map gestures.
- Building geometry/labels are seeded reference data, not GPS truth; calculations gated DEC-001/008.

## MS-09 — EcoPoints, leaderboard and challenges
- **P0:** Student points balance and how rewards were earned; show pending vs confirmed if approved.
- **P1:** All-campus and monthly leaderboard; ranking must be based on backend ledger and privacy-approved identity labels.
- **P2:** Challenge details with dates, progress, participants, points and completion rules.

## MS-10 — Profile/settings
- Account details edit/logout/reset; permission preferences where supported; explain photo access and notification permission.
- Do not promise account deletion/retention behavior until policy approved.

## Form validation and UI response matrix
| Input | Condition | User response | Backend behavior |
|---|---|---|---|
| Image | Missing/invalid type | Explain and reselect | Refuse upload/inference |
| Category | Outside taxonomy | Prompt valid option | Reject enum |
| Severity | Unknown | Prompt valid option | Reject enum |
| Location | Floor not under Building | Refresh selection | Reject hierarchical mismatch |
| Description | Blank/over length | Inline error; preserve text | Enforce max after approval |
| Auth | Expired | Reauthenticate with draft preserved where safe | 401 |
| Submit | Timeout/unknown outcome | Check status then retry | Idempotency strategy gate |

## Proposed Riverpod state boundaries
`authProvider`, `campusLocationsProvider`, `reportDraftProvider` (ephemeral), `myReportsProvider`, `reportDetailProvider(id)`, `pointsProvider`, optional `campusMapProvider`. Invalidate only affected data after transitions and prevent cross-account stale state. Implementation details remain to be agreed in architecture spec.


## Agent acceptance checklist (proposed)

- [ ] Every P0 screen path can be demonstrated with a working auth session.
- [ ] AI suggestions can be edited and manual fallback is offered without resetting drafts.
- [ ] Building/Floor/Area controls prevent invalid parent-child combinations.
- [ ] Student never sees unsafe unrelated report photo or internal notes.
- [ ] P1/P2 pages have honest unavailable/placeholder presentation if not built.

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
| `REQ-GOAL-001` | Student reporting journey targets completion in under 60 seconds | §§3 (G1), 23 | TARGET | — |
| `REQ-ROLE-001` | Provide Student role with fast reporting, photo, location and tracking | §5.1 | BASE | DEC-006 |
| `REQ-FLOW-001` | Support observe → photograph → AI suggestion → confirm location → submit report sequence | §6 | CROSS | DEC-007, DEC-008 |
| `REQ-AUTH-001` | Student app supports student registration | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-002` | Student app supports login | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-003` | Student app supports logout | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-004` | Student app supports password reset | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-005` | Student app supports profile maintenance | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-HOME-001` | Display Campus Eco Score on student home | §7.2, §21 | P0-SHELL | DEC-001 |
| `REQ-HOME-002` | Display personal impact on student home | §7.2, §21 | P0-SHELL | — |
| `REQ-HOME-003` | Display active challenge on student home | §7.2, §21 | P0-SHELL | DEC-012 |
| `REQ-HOME-004` | Display nearby issues on student home | §7.2, §21 | P0-SHELL | DEC-006, DEC-008 |
| `REQ-HOME-005` | Provide prominent Report Issue action | §7.2, §21 | P0-SHELL | — |
| `REQ-REPORT-001` | Offer camera capture for an issue photograph | §7.3 | P0 | — |
| `REQ-REPORT-002` | Offer photo selection/upload from device | §7.3 | P0 | — |
| `REQ-REPORT-004` | Show AI-suggested issue type | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-005` | Show AI-suggested issue category | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-006` | Show AI-suggested severity | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-007` | Show AI-suggested department | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-008` | Show AI-generated description | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-009` | Allow user to edit AI-generated fields before submission | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-013` | Let student select Building → Floor → Area for MVP location | §7.6 | P0 | DEC-008 |
| `REQ-TRACK-001` | List student active reports | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-002` | List student resolved reports | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-003` | Show report details | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-004` | Show current report status | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-005` | Show resolution notes | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-006` | Show original submission date | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-007` | Support normal states REPORTED → ASSIGNED → IN PROGRESS → RESOLVED | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-008` | Consider REJECTED and DUPLICATE as optional—not required for P0 | §7.7 | OPTION | DEC-004, DEC-006 |

30 source-linked rows displayed of 43 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
