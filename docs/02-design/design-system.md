---
title: 'EcoCampus Design System and Accessibility Contract'
package_doc_id: ECO-08
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§7, 9, 11–13, 19, 23'
prior_document_mapping: 'DOC-012; DOC-015'
priority_scope: 'CROSS'
date: '2026-10-10'
---

# EcoCampus Design System and Accessibility Contract

> **Path:** `docs/02-design/design-system.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§7, 9, 11–13, 19, 23; legacy registry: DOC-012; DOC-015.  
> **Decision gates:** `DEC-001`, `DEC-008`, `DEC-012`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Visual direction — proposed, not supplied by PRD
Use a clean, approachable sustainability visual language without sacrificing seriousness of incident severity. Color is a *secondary cue* for status; text/icon is mandatory. The PRD includes illustrative green/yellow/red Eco Scores but specifies no brand hex codes or fonts.

## Proposed design tokens (review before code)
```css
:root {
  --brand-primary: #176B4A;       /* proposal: forest green */
  --brand-primary-hover: #11563B;
  --surface-base: #FFFFFF;
  --surface-subtle: #F3F7F4;
  --ink-primary: #182820;
  --ink-muted: #526259;
  --border-subtle: #DCE5DF;
  --severity-low: #4F8668;
  --severity-medium: #B2771D;
  --severity-high: #B44824;
  --severity-critical: #B42318;
  --radius-card: 16px;
  --radius-control: 10px;
  --space-unit: 4px;
}
```
**Do not treat tokens above as approved identity.** Define shared platform-neutral Figma tokens then map Flutter ThemeData / Tailwind theme once accepted.

## Typography and density
- Proposed type scale: hero 30/36; page 24/32; section 20/28; body 16/24; caption 13/18; small labels 12/16. Keep mobile body scalable by OS text scale.
- Contrast target: use WCAG AA as a **proposed engineering quality target** (the PRD does not mandate WCAG level). Avoid putting necessary information only in graphics.
- Mobile touch target: propose ≥44×44 logical pixels for common primary targets; web target size and keyboard support verified per platform.
- Spacing: 4px unit; panels 16–24px; clear separation between actions and data.

## Component inventory
| Component | Mobile requirement | Admin requirement |
|---|---|---|
| App header | Profile / current campus | Role / sign out / global nav |
| Primary CTA | Report Issue, full width as appropriate | Resolve / Assign context buttons |
| Severity badge | Label + icon + non-color indicator | Label + sortable severity |
| Status timeline | Ordered transitions, names and times | Actor, note and audit details |
| Location picker | Dependent 3-level selection | Readable building-floor-area chips and filters |
| File input | Camera/gallery/preview | Protected preview, zoom and missing-image fallback |
| Empty state | Action to create first report | Explain no matches or no permission |
| Loading | Skeleton/spinner with accessible description | Stable table skeleton and action disabled state |
| Error alert | Retry/manual path | Server error, conflict refresh and actionable context |
| Map legend | List alternative | SVG/list keyboard navigation and score badges |
| Chart | Accessible summary/alternative | Data table and descriptive legend |

## Semantic severity and report status
- Severity levels exactly: Low, Medium, High, Critical (PRD §7.5). Severity is risk classification, **not report status**.
- Core statuses exactly: REPORTED, ASSIGNED, IN PROGRESS, RESOLVED; OPTIONAL REJECTED/DUPLICATE.
- Status badges should include text and a description like `Assigned — awaiting department action` where confirmed.
- Eco Score colors should never imply health or regulatory compliance without an approved score model.

## Interaction state taxonomy
Each component must specify idle, hover/focus (web), pressed, loading, disabled, success, empty, validation error, permission error, network error and stale-data conflict as applicable. Loading cannot conceal a live action's uncertain outcome.

## Layout and responsive rules — proposed
| View | Layout approach | Note |
|---|---|---|
| Mobile <600dp | Single column, bottom navigation or compact tabs | Keep Report CTA persistent/prominent |
| Tablet 600–1024 | Adaptive split where useful | Avoid stretching forms to full width |
| Web desktop ≥1024 | Side navigation + responsive data tables | Fixed data labels and clear filters |
| Narrow admin window | Collapse sidebar, horizontally scroll tables with accessible labels | Do not omit critical actions |

## Accessibility checklist
- Input labels persist after entry; associate error to corresponding field.
- Maintain text alternatives for photos where appropriate and map buildings as accessible semantic targets.
- Meet proposed AA color contrast; verify dark/light states if both supported.
- Announce asynchronous AI completion, submitted report ID, and role/permission errors.
- Charts have a textual summary/table; avoid motion-only conveying score changes.
- Preserve draft edits when navigating among form steps and when AI times out.

## Source assets and design deliverables
PRD does not include a campus SVG, product icon, final theme or branding package. Required inputs: logo, authorized map asset, building aliases, screenshot set, all typography licenses, accessible icon set. No licensing or identity claims until team provides assets.

## UI review rubric
For each screen: PRD field coverage, validated role accessibility, state completeness, typography hierarchy, contrast, keyboard/touch use, responsiveness and testable CTA. Keep screenshots and component inventory in the screen specs, not unversioned chats.


## Agent acceptance checklist (proposed)

- [ ] Color is not sole indicator of severity/status/score.
- [ ] Every P0 screen has loading, empty, success and actionable error states.
- [ ] Both Flutter and Next.js share approved semantic tokens and accessible labels.
- [ ] Map and charts have non-visual textual alternatives.

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
