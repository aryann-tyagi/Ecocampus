---
title: 'Hackathon Demo Script, Pitch and Judge Q&A'
package_doc_id: ECO-25
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§1–4, 23–27'
prior_document_mapping: 'DOC-042'
priority_scope: 'PLAN'
date: '2026-10-10'
---

# Hackathon Demo Script, Pitch and Judge Q&A

> **Path:** `docs/05-delivery/demo-pitch.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§1–4, 23–27; legacy registry: DOC-042.  
> **Decision gates:** `DEC-001`, `DEC-002`, `DEC-003`, `DEC-005`, `DEC-009`, `DEC-012`, `DEC-013`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Pitch positioning (PRD §§1–3, 26–27)
**One-liner:** “EcoCampus turns overlooked student reports into actionable, prioritized campus operations and transparent sustainability insights.”

**Problem:** Water leaks, overflowing bins, wasted electricity, damaged infrastructure and poor cleanliness go unnoticed or become fragmented across staff communication. Students lack an easy reporting/tracking channel and administrators lack structured campus intelligence.

**Solution:** Report → AI-assisted understanding → department resolution workflow → data-driven hotspot and impact visibility. Tagline **Report. Resolve. Improve.**

## Recommended five-minute live demo (timings are proposal, not PRD)
| Elapsed | Talk track | Live action | Tier / evidence |
|---|---|---|---|
| 0:00–0:30 | Campus problems are reported inconsistently | Show problem slide | Vision |
| 0:30–1:05 | Anyone can submit in under a minute (target) | Student Home → Report | P0 |
| 1:05–1:40 | AI reduces effort but never traps the student | Upload photo → Gemini results, edit | P0; manual fallback if needed |
| 1:40–2:05 | Accurate location without GPS | Building/Floor/Area → submit ID | P0 |
| 2:05–2:50 | Administrators can act, not just view | Admin queue → assign | P0 |
| 2:50–3:20 | Staff closes loop | Staff progress → resolve | P0 |
| 3:20–3:45 | Reporter sees a real outcome | Student report timeline + EcoPoints | P0 |
| 3:45–4:30 | Patterns help prevention | Only verified P1 map/hotspot/estimates | P1 (optional live) |
| 4:30–5:00 | Roadmap and defensibility | P2 advisor / simulator concept honestly labeled | P2 if deployed |

## PRD §25 full ten-beat demo story
1. Student observes overflowing waste bin and takes a photo.
2. AI suggests issue/category/severity/department.
3. Possible duplicate detected (P1).
4. Admin queue shows issue with priority (P1 scoring or P0 simple order clearly distinguished).
5. Recurring cafeteria waste hotspot (P1).
6. AI Advisor recommends change (P2).
7. Issue passes Reported → Assigned → In Progress → Resolved (P0).
8. Estimated impact updates (P1).
9. Student receives EcoPoints (P0), leaderboard changes (P1).
10. Campus Eco Score updates (P1).

**Pitch integrity:** Omit or label any step not implemented; do not present P1/P2 as already built merely because included in PRD.

## Differentiation and technical explanation
- Standard reporting forms collect complaints; EcoCampus connects reporting to AI suggestions, department workflow, repeat-pattern analysis and qualified environmental measurement.
- Flutter / Riverpod for student mobile; Next.js for Admin; Supabase Auth, PostgreSQL, Storage, RLS, Edge Functions; Gemini server-side.
- Report lifecycle and actor privileges enforced by server policies; AI is advisory/editable.
- P0 is an achievable operational loop; P1 adds intelligence; P2 is a grounded expansion, not a fake chatbot.

## Metrics slide (what can be truthfully claimed)
- `Submission <60 sec`, `AI <10 sec`, `Submission success >95%` are **PRD targets** until a test run confirms results. Label target vs measured with device/network/sample.
- Estimated liters/kWh/kg and Eco Scores cannot be described as actual savings without real meter/sensor evidence.
- PRD historical example water trend for Block B is illustrative seed data, not an established trend at the target institution.

## Judge Q&A prompts and defensible answers
**How accurate is the AI?** We test representative labeled category/severity fixtures; the output is editable and has a manual fallback. We do not claim an unmeasured accuracy rate.

**How is the issue prioritized?** P1 uses severity, reporting volume, recurrence, age, and location impact per PRD; exact weights are human-approved before deployment. P0 may use severity ordering if approved.

**Why does a reported leak equal water saved?** It doesn't. We only show estimated potential/associated benefit from approved models, with units and evidence limitations.

**How are duplicates prevented?** P1 compares category, location, description, time and optional image similarity; threshold and merge semantics are documented/validated.

**How are photos secure?** Authenticated access, private storage, Supabase RLS and server-guarded downloads; review cross-user privacy before public views.

**How can a two-person team finish?** P0-first implementation, separate developer lanes, traceable acceptance tests, per-phase reviewed PRs, and P2 deferral if P0 unstable.

**What is future scope?** IoT sensor integrations, AR, 3D digital twin, utility measurements, maintenance forecasting are roadmap only, not included in current MVP.

## Demo day checklist
- Verify Student/Admin/Staff accounts and assigned roles.
- Confirm camera/gallery fallbacks and private image access on demo device.
- Seed known example building areas; verify correct display labels.
- Rehearse live report ID handoff from mobile to Admin to Staff.
- Keep safe manual AI fallback and original photo asset ready.
- Show a visibly labeled fixture dataset when demonstrating hotspots/savings.
- Have recorded backup video that clearly states prerecorded status.
- Preserve final slide with roadmap and implementation status, no claims unsupported by test evidence.


## Agent acceptance checklist (proposed)

- [ ] Pitch accurately separates product vision, PRD targets and verified implementation.
- [ ] P0 demo flow works even when P1/P2 are disabled.
- [ ] Every synthetic campus figure and estimate is clearly marked.
- [ ] Backup assets and accounts tested on demo environment.
- [ ] Judge Q&A covers security, inference fallback, scoring and impact limitations.

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
