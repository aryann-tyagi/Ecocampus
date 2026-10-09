---
title: 'Authentication, RBAC and Supabase RLS Specification'
package_doc_id: ECO-12
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§5, 7.1, 11, 20'
prior_document_mapping: 'DOC-010; DOC-021; DOC-034'
priority_scope: 'P0'
date: '2026-10-10'
---

# Authentication, RBAC and Supabase RLS Specification

> **Path:** `docs/03-engineering/auth-roles-rls.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§5, 7.1, 11, 20; legacy registry: DOC-010; DOC-021; DOC-034.  
> **Decision gates:** `DEC-004`, `DEC-006`, `DEC-010`, `DEC-011`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Mandatory PRD constraints
Every user authenticates; roles Student, Staff, Admin; RLS required; Student can create/read **their own** reports and may not change another user's reports or admin fields; Admin manages reports and analytics; Gemini requests are server-side.

## Proposed role matrix (requires DEC-006/010 approval)
| Resource/action | Student | Assigned Staff | Admin |
|---|---|---|---|
| Own profile read/edit | Yes, safe fields | Yes, safe fields | Policy-approved admin edits |
| Create own report/upload photo | Yes | TBD as reporter | TBD as reporter |
| Read own full report/photo | Yes | If reporter | Yes under operational need |
| Read someone else's full report/photo | No by default | Only assigned scope | Authenticated operational access |
| Read redacted nearby issue | If approved | If approved | Yes |
| Assign/reassign department | No | No (candidate) | Yes |
| Change workflow status | No | Only assigned issues | Yes |
| Reject/mark duplicate | No | No | Optional if approved |
| Modify score/priority/reward rules | No | No | Authorized server-side process |
| View analytics | Personal/approved public only | Scoped if approved | Campus aggregate |
| Access Gemini key/service-role key | Never | Never | Never in browser; server only |

## Identity and privilege design — proposed
- Supabase Auth is identity authority; `auth.uid()` is user identity in policies.
- Keep roles in a protected role/profile system controlled by a server/admin process, not a self-editable signup field.
- Verify role and assignment for every sensitive database read/update and every Edge Function request.
- New signup defaults to least privilege; university-domain allowlist only if approved.
- Admin role bootstrap and staff assignment must be defined in a secure administrative procedure, not through public signup.

## RLS conceptual SQL (illustrative, not executable final policy)
```sql
alter table public.reports enable row level security;
create policy "student_reads_owned_reports"
  on public.reports for select to authenticated
  using (reporter_id = auth.uid());
create policy "student_creates_owned_reports"
  on public.reports for insert to authenticated
  with check (reporter_id = auth.uid());
```
**Crucial:** These two sample policies do **not** enforce privileged column write boundaries or implement Admin/Staff permissions. A Student with `UPDATE` grant could still cause problems if policies/grants permit it. Implement explicit grants, guarded RPC/Edge mutations and test column-level ownership comprehensively.

## Media access design
Private bucket recommended. Store object path containing authenticated user and opaque asset ID; never trust a user-supplied path solely because its prefix resembles their UID. Issuing signed URLs requires report/media ownership check or authorized assignment/admin scope. No general public bucket for user photographs without explicit privacy review.

## Threat-based authorization tests
| Attack | Expected result |
|---|---|
| Student reads another report UUID directly | Denied or sanitized result |
| Student updates `status` or `department_id` | Denied |
| Student sets `role=admin` in profile update | Denied |
| Staff changes issue outside assigned department | Denied |
| Staff assigns a new department | Denied unless explicitly approved |
| Anyone downloads another report photo path | Denied |
| Unauthenticated client invokes image inference | 401 |
| Admin access removed mid-session | Server enforces updated authority; old UI cache isn't trusted |
| Analytics query exposing reporter emails | Only approved redacted aggregation |

## Session and identity lifecycle
- App resumes authenticated state via Supabase session handling; refresh token never logged.
- Sign-out clears app-local private data/cache and invalidates sensitive view state.
- User switching must invalidate old profile/report/media queries to prevent cross-account stale display.
- Password reset follows Supabase Auth secured redirect flow; never implement custom password plaintext emailing.

## Security review / decision gates
DEC-006 determines cross-student visibility, staff photo access and retention; DEC-010 determines department scoping; DEC-004 controls allowed transitions; DEC-011 controls hosting secrets and callbacks. Every policy gets authorized/unauthorized integration tests **before** deployment. AuthZ is enforced in database/server, not merely Next.js middleware or Flutter route guards.


## Agent acceptance checklist (proposed)

- [ ] Student-to-admin privilege escalation fails in database and function tests.
- [ ] Known reporter A token cannot retrieve reporter B private report or storage object.
- [ ] Assigned staff cannot mutate unassigned issue.
- [ ] Anonymous/insecure sessions cannot invoke protected functions.
- [ ] Logout/account switch clears stale protected mobile and web state.

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
| `REQ-ROLE-001` | Provide Student role with fast reporting, photo, location and tracking | §5.1 | BASE | DEC-006 |
| `REQ-ROLE-002` | Campus Administrators monitor, assign, track and analyze issues | §5.2 | BASE | DEC-010 |
| `REQ-ROLE-003` | Department Staff can view assigned issues, update statuses, add resolution notes and mark resolved | §5.3 | BASE | DEC-004, DEC-010 |
| `REQ-AUTH-001` | Student app supports student registration | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-002` | Student app supports login | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-003` | Student app supports logout | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-004` | Student app supports password reset | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-005` | Student app supports profile maintenance | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-006` | University email restriction is an optional registration policy, not automatically enforced | §7.1 | OPTION | DEC-006 |
| `REQ-TECH-009` | Auth is implemented using Supabase Auth | §§18–19 | BASE | — |
| `REQ-SEC-001` | Authenticate every user | §20 | BASE | DEC-006 |
| `REQ-SEC-002` | Provide Student, Staff and Admin roles | §20 | BASE | DEC-006, DEC-010 |
| `REQ-SEC-003` | Enforce data access with Supabase RLS | §20 | BASE | DEC-006 |
| `REQ-SEC-004` | Students can create their own reports | §20 | BASE | DEC-006 |
| `REQ-SEC-005` | Students can read their own reports | §20 | BASE | DEC-006 |
| `REQ-SEC-006` | Students cannot modify other users' reports | §20 | BASE | DEC-006 |
| `REQ-SEC-007` | Students cannot update admin-only fields | §20 | BASE | DEC-006 |
| `REQ-SEC-008` | Admins can manage reports and analytics | §20 | BASE | DEC-006, DEC-010 |
| `REQ-SEC-009` | Keep Gemini API keys out of Flutter client | §20 | BASE | DEC-007 |
| `REQ-SEC-010` | Send AI requests through server-side Edge Functions | §20 | BASE | DEC-007 |

20 source-linked rows displayed of 20 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
