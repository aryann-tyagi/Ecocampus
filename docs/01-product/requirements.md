---
title: 'Master Feature Requirements and Acceptance Contracts'
package_doc_id: ECO-02
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§3–24'
prior_document_mapping: 'DOC-007; DOC-008'
priority_scope: 'BASE'
date: '2026-10-10'
---

# Master Feature Requirements and Acceptance Contracts

> **Path:** `docs/01-product/requirements.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§3–24; legacy registry: DOC-007; DOC-008.  
> **Decision gates:** `DEC-001`, `DEC-002`, `DEC-003`, `DEC-004`, `DEC-005`, `DEC-006`, `DEC-007`, `DEC-008`, `DEC-009`, `DEC-010`, `DEC-011`, `DEC-012`, `DEC-013`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Canonical feature inventory — PRD §21
**No feature may change tier without a recorded product-scope decision.** This summary groups behavior; the existing `requirements-traceability.md` is the authoritative registry of 217 stable atomic `REQ-*` rows.

| Feature ID | Priority | Feature | Functional acceptance boundary |
|---|---|---|---|
| F-P0-01 | P0 | Authentication | Register, login, logout, reset password, profile management; restricted content needs auth |
| F-P0-02 | P0 | Student home | Eco Score/personal impact/challenge/nearby issue regions and report CTA; unavailable advanced data can be disclosed placeholder |
| F-P0-03 | P0 | Report issue | Photo-driven form, editable suggestions, validated location and confirmation |
| F-P0-04 | P0 | Photo upload | Camera/gallery capture and authorized storage association |
| F-P0-05 | P0 | AI classification | Issue/category/severity/department/description suggested; manual fallback |
| F-P0-06 | P0 | Location | Building → floor → area, optional GPS |
| F-P0-07 | P0 | Report tracking | Own active/resolved reports, detail, status, notes and submission date |
| F-P0-08 | P0 | Admin dashboard | Active/critical/resolved totals, impact shell, queue and filters |
| F-P0-09 | P0 | Department assignment | Authorized assignment visible to staff/issue history |
| F-P0-10 | P0 | Status management | REPORTED → ASSIGNED → IN_PROGRESS → RESOLVED |
| F-P0-11 | P0 | EcoPoints | Eligible events credited per approved interpretation of PRD §12 |
| F-P0-12 | P0 | Basic analytics | Issue distribution, building-level summaries and resolution visibility |
| F-P1-01 | P1 | Duplicate detection | Compare category, location, text, time; join or continue separately |
| F-P1-02 | P1 | Smart priority | Explainable score based on 5 PRD inputs |
| F-P1-03 | P1 | Campus sustainability map | Interactive 2D SVG building view |
| F-P1-04 | P1 | Building Eco Score | Building/category score and historical issue data |
| F-P1-05 | P1 | Leaderboard | Campus/month/challenge ranking |
| F-P1-06 | P1 | Recurring issue detection | Recurrence/hotspot detection and action insight |
| F-P1-07 | P1 | Impact calculations | Defensible estimates after resolution, visibly qualified |
| F-P2-01 | P2 | AI Sustainability Advisor | Evidence-backed natural-language recommendations |
| F-P2-02 | P2 | What-If Simulator | Transparent scenario model with estimated projections |
| F-P2-03 | P2 | Eco Challenges | Participants/progress/completion/awards |
| F-P2-04 | P2 | Advanced notifications | Events for progress, points, spike, deadline and alerts |
| F-P2-05 | P2 | Advanced image similarity | Enhanced duplicate-photo matching only if time permits |

## Non-functional constraints from PRD §§20, 23–24
- Every user authenticates and operates under Student/Staff/Admin authority; enforce Supabase RLS.
- Students create/read their own reports and cannot mutate other reporters' records or administration fields.
- Never embed Gemini secrets in Flutter; route inference via a protected Edge Function.
- Reporting target <60 seconds; AI analysis <10 seconds; successful submissions >95%.
- When AI fails, the report is manually completable; location selection is usable without GPS.

## Input validation contract — proposed details requiring review
| Operation | Required fields | Validations / behavior |
|---|---|---|
| Register | Email, password | Supabase Auth validation; university-domain rule optional (`DEC-006`) |
| Photo | File, owner reference | Reject unsupported content, excessive bytes or no authenticated user; size/type limits TBD |
| AI analyze | Authorized photo reference | Never trust client-supplied storage path ownership; JSON taxonomy validation |
| Create report | Category, text, severity, location IDs, photo per final UX | Server canonical IDs, nonempty narrative, ownership from token not request body |
| Assign | Report ID, department ID | Admin-authorized, department exists, append history |
| Change status | Report ID, intended transition, note if needed | Role-specific transition and concurrency checks (`DEC-004`) |
| Award points | Trusted event ID | Exactly-once effect, never client authority (`DEC-005`) |
| Map/impact | Building and time scope | Support only seeded campus data and labeled modeled estimates |

## Cross-feature dependencies
`Auth & RLS → upload ownership → Gemini/manual classification → canonical location → report creation → admin queue → assignment → status/history → student tracking → eligibility-based EcoPoints`. P1 features attach to this stable path without making core reporting depend on them. P2 advisor and simulator require trustworthy P1 aggregates.

## Source vs candidate behavior
- **PRD facts:** Category taxonomy is waste, water, electricity, infrastructure, greenery, cleanliness, other. Severity taxonomy is low, medium, high, critical. Location hierarchy is Building/Floor/Area.
- **Open decisions:** Numeric scoring weights, point stacking, duplicate cutoff, role cross-visibility, UI route names, upload limits, hosting, notification push requirements and AI confidence cutoff are **not** defined by the PRD.
- **Proposed safe defaults:** Server-controlled mutations, unique event IDs, explicit rejected state only if approved, separate honest sample data. Do not silently hardcode these as final.

## Acceptance and implementation readiness protocol
1. Every implemented feature traces to one `F-*` entry and its `REQ-*` / `TEST-*` set.
2. Agent cites PRD §, current feature specification, relevant approved `DEC-*` before opening a branch.
3. Backend ownership and RLS are reviewed before mobile/admin writes ship.
4. Contract tests cover positive, validation, unauthorized and retry paths.
5. PR includes affected migrations, test evidence and a documented demo path.
6. Feature completeness is checked on a clean environment, not only against local seeded state.

## Requirement-change procedure
Create proposal with affected `REQ-*`, decision ID, rationale, risks, tests and owner; obtain human approval; update master PRD or approved change record; revise contracts and migrations; then implement. Never renumber existing 217 IDs.


## Agent acceptance checklist (proposed)

- [ ] Every one of 24 features appears exactly once and uses the correct P0/P1/P2 tier.
- [ ] P0 submission still works when Gemini fails or P1/P2 services are absent.
- [ ] Admin-only operations cannot be accomplished from a Student token.
- [ ] Unapproved formula, threshold, hosting and points assumptions are not treated as requirements.

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
| `REQ-PRD-001` | Product is a centralized, AI-assisted campus issue reporting and sustainability intelligence platform | §§1–2, 26 | BASE | — |
| `REQ-PRD-002` | Product shall support students reporting campus sustainability and infrastructure issues | §§1–2, 5, 26 | BASE | — |
| `REQ-PRD-003` | University administrators must have actionable campus issue insights | §§1–3, 5.2 | BASE | — |
| `REQ-GOAL-001` | Student reporting journey targets completion in under 60 seconds | §§3 (G1), 23 | TARGET | — |
| `REQ-GOAL-002` | AI supports issue type, category, severity, department and description identification | §3 (G2) | BASE | DEC-007 |
| `REQ-GOAL-003` | Administrators receive a queue supporting prioritization of issues | §3 (G3) | BASE | DEC-002 |
| `REQ-GOAL-004` | Surface recurring issue patterns and campus hotspots | §3 (G4) | P1 | DEC-008 |
| `REQ-GOAL-005` | Estimate environmental impact of resolved supported issues | §3 (G5) | P1 | DEC-009 |
| `REQ-GOAL-006` | Recognize student contribution through EcoPoints; richer achievements, challenges and leaderboards depend on their respective P1/P2 scopes | §3 (G6), §21 | CROSS | DEC-005, DEC-012 |
| `REQ-ROLE-001` | Provide Student role with fast reporting, photo, location and tracking | §5.1 | BASE | DEC-006 |
| `REQ-ROLE-002` | Campus Administrators monitor, assign, track and analyze issues | §5.2 | BASE | DEC-010 |
| `REQ-ROLE-003` | Department Staff can view assigned issues, update statuses, add resolution notes and mark resolved | §5.3 | BASE | DEC-004, DEC-010 |
| `REQ-FLOW-001` | Support observe → photograph → AI suggestion → confirm location → submit report sequence | §6 | CROSS | DEC-007, DEC-008 |
| `REQ-FLOW-002` | Run duplicate detection and smart priority in issue processing when their features are enabled | §6, §21 | P1 | DEC-002, DEC-003 |
| `REQ-FLOW-003` | Resolve issue through administrator/staff workflow and make updated state visible to the reporting student | §6, §7.7 | CROSS | DEC-004, DEC-011 |
| `REQ-FLOW-004` | Award EcoPoints on eligible reporting/resolution actions | §6, §12.1 | CROSS | DEC-005 |
| `REQ-FLOW-005` | Recompute relevant impact and campus intelligence after applicable issue changes | §6, §§9–10, 14 | P1 | DEC-001, DEC-009 |
| `REQ-AUTH-001` | Student app supports student registration | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-002` | Student app supports login | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-003` | Student app supports logout | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-004` | Student app supports password reset | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-005` | Student app supports profile maintenance | §7.1, §21 P0 | P0 | DEC-006 |
| `REQ-AUTH-006` | University email restriction is an optional registration policy, not automatically enforced | §7.1 | OPTION | DEC-006 |
| `REQ-HOME-001` | Display Campus Eco Score on student home | §7.2, §21 | P0-SHELL | DEC-001 |
| `REQ-HOME-002` | Display personal impact on student home | §7.2, §21 | P0-SHELL | — |
| `REQ-HOME-003` | Display active challenge on student home | §7.2, §21 | P0-SHELL | DEC-012 |
| `REQ-HOME-004` | Display nearby issues on student home | §7.2, §21 | P0-SHELL | DEC-006, DEC-008 |
| `REQ-HOME-005` | Provide prominent Report Issue action | §7.2, §21 | P0-SHELL | — |
| `REQ-REPORT-001` | Offer camera capture for an issue photograph | §7.3 | P0 | — |
| `REQ-REPORT-002` | Offer photo selection/upload from device | §7.3 | P0 | — |
| `REQ-REPORT-003` | Submit selected photo for AI analysis | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-004` | Show AI-suggested issue type | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-005` | Show AI-suggested issue category | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-006` | Show AI-suggested severity | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-007` | Show AI-suggested department | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-008` | Show AI-generated description | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-009` | Allow user to edit AI-generated fields before submission | §7.3 | P0 | DEC-007 |
| `REQ-REPORT-010` | Support waste, water, electricity, infrastructure, greenery, cleanliness and other categories | §7.4 | P0 | DEC-007 |
| `REQ-REPORT-011` | Support Low, Medium, High and Critical severities with PRD definitions | §7.5 | P0 | DEC-007 |
| `REQ-REPORT-012` | Allow administrators to override the AI severity recommendation | §7.5 | P0 | DEC-004, DEC-010 |
| `REQ-REPORT-013` | Let student select Building → Floor → Area for MVP location | §7.6 | P0 | DEC-008 |
| `REQ-REPORT-014` | Allow optional GPS coordinates without making GPS compulsory | §7.6 | P0 | DEC-008 |
| `REQ-REPORT-015` | Create a trackable report after student confirmation | §§7.3, 24 | P0 | DEC-004 |
| `REQ-REPORT-016` | AI unavailability must not prevent manual category/description reporting | §§7.3, 24 | P0 | DEC-007 |
| `REQ-TRACK-001` | List student active reports | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-002` | List student resolved reports | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-003` | Show report details | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-004` | Show current report status | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-005` | Show resolution notes | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-006` | Show original submission date | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-007` | Support normal states REPORTED → ASSIGNED → IN PROGRESS → RESOLVED | §7.7 | P0 | DEC-004, DEC-006 |
| `REQ-TRACK-008` | Consider REJECTED and DUPLICATE as optional—not required for P0 | §7.7 | OPTION | DEC-004, DEC-006 |
| `REQ-AI-001` | Classify photo into issue type, category, severity, department and description | §8.1 | P0 | DEC-007 |
| `REQ-AI-002` | Route AI requests through a server-side Supabase Edge Function | §§18–20 | P0 | DEC-007 |
| `REQ-AI-003` | Remain operable when AI API fails or analysis output is unsuitable | §24 | P0 | DEC-007 |
| `REQ-AI-004` | Use user-confirmable and editable AI output rather than irreversible AI classification | §7.3, §24 | P0 | DEC-007 |
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
| `REQ-ADMIN-001` | Show Campus Eco Score on administrator overview | §11 | CROSS | DEC-001, DEC-009 |
| `REQ-ADMIN-002` | Show count of active issues | §11 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-003` | Show count of critical issues | §11 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-004` | Show resolved issues count | §11 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-005` | Show average resolution time | §11 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-006` | Show estimated environmental impact | §11 | CROSS | DEC-001, DEC-009 |
| `REQ-ADMIN-007` | Provide issue list viewing | §11.1 | P0 | DEC-002 |
| `REQ-ADMIN-008` | Provide issue filtering | §11.1 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-009` | Provide issue search | §11.1 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-010` | Allow department assignment | §11.1 | P0 | DEC-004, DEC-010 |
| `REQ-ADMIN-011` | Allow change of issue priority | §11.1 | P0 | DEC-002 |
| `REQ-ADMIN-012` | Allow issue status changes | §11.1 | P0 | DEC-004, DEC-010 |
| `REQ-ADMIN-013` | Allow resolution notes | §11.1 | P0 | DEC-004, DEC-010 |
| `REQ-ADMIN-014` | Allow marking duplicate reports | §11.1 | CROSS | DEC-004, DEC-010 |
| `REQ-ADMIN-015` | Allow rejection of invalid reports | §11.1 | CROSS | DEC-004, DEC-010 |
| `REQ-ADMIN-016` | Show issue distribution analytics | §11.2 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-017` | Show building comparison analytics | §11.2 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-018` | Show resolution performance analytics | §11.2 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-019` | Show report trend analytics | §11.2 | P0 | DEC-006, DEC-010 |
| `REQ-ADMIN-020` | Show recurring problem analytics | §11.2 | CROSS | DEC-006, DEC-010 |
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
| `REQ-CHAL-001` | Water Week challenge supports reporting water wastage | §13 | P2 | DEC-005, DEC-012 |
| `REQ-CHAL-002` | Energy Week challenge supports reporting unnecessary electricity usage | §13 | P2 | DEC-005, DEC-012 |
| `REQ-CHAL-003` | Clean Campus challenge supports identifying waste hotspots | §13 | P2 | DEC-005, DEC-012 |
| `REQ-CHAL-004` | Green Campus challenge supports reporting damaged greenery | §13 | P2 | DEC-005, DEC-012 |
| `REQ-CHAL-005` | Track challenge participants, reports, points and completion percentage | §13 | P2 | DEC-005, DEC-012 |
| `REQ-IMPACT-001` | Estimate environmental impact after issue resolution | §14 | P1 | DEC-009 |
| `REQ-IMPACT-002` | Provide estimated water saving outputs with volume/time units | §14 | P1 | DEC-009 |
| `REQ-IMPACT-003` | Provide estimated electricity outputs in kWh/time | §14 | P1 | DEC-009 |
| `REQ-IMPACT-004` | Provide estimated waste handled outputs in kg | §14 | P1 | DEC-009 |
| `REQ-IMPACT-005` | Label non-verified impact values explicitly as estimates | §14 | P1 | DEC-009 |
| `REQ-IMPACT-006` | Do not claim verified impact without real sensor or utility evidence | §14 | P1 | DEC-009 |
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
| `REQ-TECH-001` | Student application targets Android and iOS | §§18–19 | BASE | DEC-011 |
| `REQ-TECH-002` | Mobile implementation uses Flutter and Dart | §§18–19 | BASE | — |
| `REQ-TECH-003` | Mobile state management uses Riverpod | §§18–19 | BASE | — |
| `REQ-TECH-004` | Admin web app uses Next.js and TypeScript | §§18–19 | BASE | — |
| `REQ-TECH-005` | Admin UI uses Tailwind CSS | §§18–19 | BASE | — |
| `REQ-TECH-006` | Admin charts use Recharts | §§18–19 | BASE | — |
| `REQ-TECH-007` | Backend platform uses Supabase | §§18–19 | BASE | — |
| `REQ-TECH-008` | Relational database uses PostgreSQL | §§18–19 | BASE | — |
| `REQ-TECH-009` | Auth is implemented using Supabase Auth | §§18–19 | BASE | — |
| `REQ-TECH-010` | Photo/media persistence uses Supabase Storage | §§18–19 | BASE | — |
| `REQ-TECH-011` | Realtime capability uses Supabase Realtime | §§18–19 | BASE | — |
| `REQ-TECH-012` | Server-side logic uses Supabase Edge Functions | §§18–19 | BASE | — |
| `REQ-TECH-013` | AI provider is Gemini API | §§18–19 | BASE | — |
| `REQ-TECH-014` | Notifications stack includes Firebase Cloud Messaging | §§18–19 | BASE | DEC-011 |
| `REQ-TECH-015` | MVP map representation uses custom SVG campus map | §§18–19 | BASE | DEC-008 |
| `REQ-TECH-016` | Version control uses Git and GitHub | §§18–19 | BASE | — |
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
| `REQ-KPI-001` | Reporting time target: <60 seconds | §23 | TARGET | — |
| `REQ-KPI-002` | AI classification time target: <10 seconds | §23 | TARGET | DEC-007 |
| `REQ-KPI-003` | Submission success target: >95% | §23 | TARGET | — |
| `REQ-KPI-004` | Supported-category issue routing is automatic when AI is successful | §23 | TARGET | DEC-007 |
| `REQ-KPI-005` | Student can see resolution status | §23 | TARGET | — |
| `REQ-KPI-006` | Resolved supported issues produce estimated impact | §23 | TARGET | DEC-009 |
| `REQ-KPI-007` | Historical reports surface recurring hotspots | §23 | TARGET | DEC-003, DEC-008 |
| `REQ-RISK-001` | Allow manual category/description fallback for Gemini API failure | §24 | CONTROL | DEC-007 |
| `REQ-RISK-002` | Prefer building/floor/area selection to GPS-only location | §24 | CONTROL | DEC-008 |
| `REQ-RISK-003` | Prioritize P0 before P1 and P2 to prevent scope expansion | §24 | CONTROL | DEC-012 |
| `REQ-RISK-004` | Permit editing of weak AI results and avoid AI-blocked reporting | §24 | CONTROL | DEC-007 |
| `REQ-RISK-005` | Freeze major feature work around day 19–20 to allow polishing/tests | §24 | CONTROL | DEC-012 |
| `REQ-PLAN-001` | Project setup, UI system, Supabase, database and authentication | §22 | PLAN | — |
| `REQ-PLAN-002` | Student home/report flow, camera/upload, storage and location | §22 | PLAN | — |
| `REQ-PLAN-003` | AI integration, result confirmation and report creation | §22 | PLAN | — |
| `REQ-PLAN-004` | Admin dashboard, issue management, assignment and status | §22 | PLAN | — |
| `REQ-PLAN-005` | Smart priority and duplicate detection | §22 | PLAN | — |
| `REQ-PLAN-006` | Campus map, building profiles and analytics | §22 | PLAN | — |
| `REQ-PLAN-007` | EcoPoints, leaderboard and achievements | §22 | PLAN | — |
| `REQ-PLAN-008` | Impact calculations and Campus Eco Score | §22 | PLAN | — |
| `REQ-PLAN-009` | Recurring issue detection and hotspots | §22 | PLAN | — |
| `REQ-PLAN-010` | AI Advisor / What-If optional differentiator | §22 | PLAN | DEC-012 |
| `REQ-PLAN-011` | UI polish, testing, errors and performance | §22 | PLAN | DEC-012 |
| `REQ-PLAN-012` | Demo, presentation, backup video and final fixes | §22 | PLAN | DEC-012 |
| `REQ-DEMO-001` | Student photographs overflowing waste bin | §25 | DEMO | DEC-012 |
| `REQ-DEMO-002` | AI classifies issue, category, severity and department | §25 | DEMO | DEC-012 |
| `REQ-DEMO-003` | System identifies potential duplicate | §25 | DEMO | DEC-012 |
| `REQ-DEMO-004` | Administrator receives prioritized report | §25 | DEMO | DEC-012 |
| `REQ-DEMO-005` | Dashboard reveals recurring cafeteria hotspot | §25 | DEMO | DEC-012 |
| `REQ-DEMO-006` | AI Advisor recommends operational change | §25 | DEMO | DEC-012, DEC-013 |
| `REQ-DEMO-007` | Admin moves issue through reported/assigned/in progress/resolved | §25 | DEMO | DEC-012 |
| `REQ-DEMO-008` | Impact metrics update | §25 | DEMO | DEC-012 |
| `REQ-DEMO-009` | Student receives EcoPoints and leaderboard changes | §25 | DEMO | DEC-012 |
| `REQ-DEMO-010` | Campus Eco Score updates | §25 | DEMO | DEC-012 |
| `REQ-NONGOAL-001` | Exclude Full 3D digital twin from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-002` | Exclude IoT sensor integration from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-003` | Exclude Real-time electricity/water monitoring from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-004` | Exclude Automatic physical repair from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-005` | Exclude Drone or satellite monitoring from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-006` | Exclude Complex augmented reality navigation from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-007` | Exclude Full university ERP integration from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-008` | Exclude Payment or reward marketplace from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NONGOAL-009` | Exclude Advanced computer vision model training from the three-week scope | §4 | OUT | DEC-012 |
| `REQ-NS-001` | Product north-star lifecycle is Observe → Report → Understand → Prioritize → Resolve → Measure → Prevent | §27 | BASE | — |
| `REQ-NS-002` | Defer features that do not improve the product north-star loop | §27 | CONTROL | DEC-012 |

217 source-linked rows displayed of 17 applicable rows. 

## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
