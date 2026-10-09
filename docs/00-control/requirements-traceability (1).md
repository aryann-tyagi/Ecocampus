---
document_id: DOC-000
title: EcoCampus Documentation Index
version: 1.0.5
status: DRAFT
source: EcoCampus PRD v1.0 (user-provided, 13 pages, sections 1-27)
last_updated: 2026-10-09
owner: Product / Technical Leads (assignment pending)
---

# EcoCampus — Documentation Index

> **Purpose:** The entry point and navigation contract for all product, design, engineering, AI, testing, and delivery documents for EcoCampus. This index defines what each document owns, how the documents relate, and how human contributors and coding agents must use them.
>
> **Important:** This index is a proposed documentation and collaboration structure derived from **EcoCampus PRD v1.0**. It does **not** mean that the uncreated documents, architectures, algorithms, or design decisions have already been implemented or approved.

## 1. Project baseline — grounded in the PRD

| Field | Baseline |
|---|---|
| Product | **EcoCampus** — AI-Powered Campus Sustainability & Issue Intelligence Platform |
| Tagline | **Report. Resolve. Improve.** |
| Product North Star | **OBSERVE → REPORT → UNDERSTAND → PRIORITIZE → RESOLVE → MEASURE → PREVENT** |
| Delivery window | **3 weeks / 21 days** |
| Team | **2 developers** |
| Users | **Students; Campus Administrators; Department Staff** |
| Platforms | **Android/iOS student app + web administration dashboard** |
| Mobile | **Flutter, Dart, Riverpod** |
| Admin web | **Next.js, TypeScript, Tailwind CSS, Recharts** |
| Backend | **Supabase: PostgreSQL, Auth, Storage, Realtime, Edge Functions** |
| AI | **Gemini API**, accessed via server-side Edge Functions |
| Notifications | **Firebase Cloud Messaging** |
| MVP map | **Custom SVG / 2D campus map** |
| Version control | **Git + GitHub** |
| Original requirements | **EcoCampus_PRD.docx**, version **1.0**, sections **1–27** |

**Source boundaries:** These baselines are from the supplied PRD. The PRD does **not** provide a finalized SQL schema, exact scoring formulas, deployment provider, repository tree, AI prompt, test suite, or page-by-page UI wireframes. Such details will be **proposed and reviewed** in their respective specifications, not presented as existing facts.

## 2. Project scope and delivery priorities

Use the source PRD's **P0 / P1 / P2** classifications as the definitive initial scope. Do not silently promote a lower-priority feature or remove a must-have.

### P0 — Must Have (12)

1. Authentication
2. Student home
3. Report issue
4. Photo upload
5. AI classification
6. Location
7. Report tracking
8. Admin dashboard
9. Department assignment
10. Status management
11. EcoPoints
12. Basic analytics

### P1 — High Value (7)

1. Duplicate detection
2. Smart priority
3. Campus sustainability map
4. Building Eco Score
5. Leaderboard
6. Recurring issue detection
7. Impact calculations

### P2 — Stretch (5)

1. AI Sustainability Advisor
2. What-If Simulator
3. Eco Challenges
4. Advanced notifications
5. Advanced image similarity

**Explicit non-goals for the three-week build:** full 3D digital twin; IoT sensors; real-time water/electricity monitoring; automatic physical repairs; drone/satellite monitoring; complex AR navigation; full university ERP integration; a payment/reward marketplace; and advanced computer vision model training. These appear as non-goals in PRD §4, with some ideas discussed as future work.

## 3. Source-of-truth and precedence rules

A coding agent or contributor must resolve conflicts in this order:

1. **Approved product decisions** in [`decision-register.md`](decision-register.md), *only when explicitly marked APPROVED* and when they do not silently contradict the original PRD. Material scope changes need human sign-off and a documented PRD change.
2. **Approved requirements** in `docs/01-product/product-requirements.md` and `functional-requirements.md`, traceable to PRD v1.0 or an approved change.
3. **Approved module specifications** (architecture, APIs, schemas, algorithms, screens, business rules) for implementation detail within those requirements.
4. **Approved test and acceptance contracts** in `docs/06-quality/` for verification; tests do not authorize expanding the feature set.
5. **Agent instructions** in `/AGENTS.md` and `/CLAUDE.md` for working practices; they do not override product requirements or security controls.
6. **Unapproved ideas, drafts, comments, and example data** are informative, not authority to implement a behavior.

**Conflict rule:** If two approved documents disagree, **STOP the affected implementation, log the conflict in the decision register, and obtain an explicit decision**. Do not quietly choose whichever document is easier. If a proposal changes PRD requirements, record the change and update all dependent documentation before coding.

**No invention rule:** The PRD's sample scores, sample impact numbers, or illustrative AI JSON are **examples**, not calibrated formulas, measured outcomes, fixed training data, or an approved contract beyond the fields explicitly shown.

## 4. Status vocabulary and document metadata

Every authored documentation file must declare:

```yaml
---
document_id: DOC-XXX
title: <Descriptive title>
version: 0.1.0
status: DRAFT
source: EcoCampus PRD v1.0, section(s) <numbers>
last_updated: YYYY-MM-DD
owner: <role or TBD>
reviewers: []
related_documents: []
---
```

| Status | Definition | Can an agent implement from it? |
|---|---|---|
| `PLANNED` | File is cataloged but not authored | **No** |
| `DRAFT` | Authored but not reviewed/approved | **No**, except exploratory work explicitly authorized by a human |
| `IN_REVIEW` | Under product/technical review | **No**, unless specifically authorized |
| `APPROVED` | Human-approved contract for the scoped work | **Yes**, provided dependencies are also approved |
| `SUPERSEDED` | Replaced by a newer document or decision | **No** |

**State of this catalog on 2026-10-10:** 6 documents authored (`DOC-000`, `DOC-004`, `DOC-005`, `DOC-006`, `DOC-007`, and `DOC-008`, all DRAFT); 38 documents cataloged as PLANNED. No approval is implied.

## 5. Master file inventory — 44 documents

File paths are repository-root relative. The document ID is stable: do not reuse an ID after a rename. Each file's detailed acceptance criteria will be specified within that file.

### Root — Repository and agent instructions (3)

| ID | Path | Ownership / contents | Initial status |
|---|---|---|---|
| `DOC-001` | `README.md` | Product introduction, architecture overview, getting started, commands, documentation pointers | PLANNED |
| `DOC-002` | `AGENTS.md` | Universal coding-agent rules, task workflow, security boundaries, checks, PR expectations | PLANNED |
| `DOC-003` | `CLAUDE.md` | Claude Code-specific navigation and working conventions, without duplicating product specs | PLANNED |

### 00 — Documentation control (3)

| ID | Path | Ownership / contents | Initial status |
|---|---|---|---|
| `DOC-000` | `docs/00-control/documentation-index.md` | This master index, source-of-truth order, navigation and readiness rules | DRAFT |
| `DOC-004` | `docs/00-control/decision-register.md` | Open questions, alternatives, assumptions, dated human approvals, PRD changes | DRAFT |
| `DOC-005` | `docs/00-control/requirements-traceability.md` | PRD section → requirement ID → spec → test → implementation/PR mapping | DRAFT |

### 01 — Product (6)

| ID | Path | Ownership / contents | Initial status |
|---|---|---|---|
| `DOC-006` | `docs/01-product/product-overview.md` | Vision, user value, problem, personas, product goals, non-goals, north star | DRAFT |
| `DOC-007` | `docs/01-product/product-requirements.md` | Versioned, prioritized feature inventory with IDs and acceptance criteria | DRAFT |
| `DOC-008` | `docs/01-product/functional-requirements.md` | Feature behavior, inputs/outputs, validations, state changes and exceptions | DRAFT |
| `DOC-009` | `docs/01-product/non-functional-requirements.md` | Speed, availability, accessibility, privacy, observability, constraints and measurable targets | PLANNED |
| `DOC-010` | `docs/01-product/users-roles-and-permissions.md` | Student/Admin/Staff capabilities and role permission matrix | PLANNED |
| `DOC-011` | `docs/01-product/user-journeys-and-business-rules.md` | End-to-end journeys, statuses, points and assignment business rules | PLANNED |

### 02 — UI/UX design (4)

| ID | Path | Ownership / contents | Initial status |
|---|---|---|---|
| `DOC-012` | `docs/02-design/design-system.md` | Visual tokens, typography, components, accessibility and responsive rules | PLANNED |
| `DOC-013` | `docs/02-design/student-mobile-screens.md` | Flutter screen-by-screen specifications, fields, UI states and interactions | PLANNED |
| `DOC-014` | `docs/02-design/admin-staff-dashboard-screens.md` | Next.js pages, widgets, filters, staff views and admin actions | PLANNED |
| `DOC-015` | `docs/02-design/navigation-states-and-error-ux.md` | Route maps, loading/empty/error states, retry and confirmation patterns | PLANNED |

### 03 — System architecture (8)

| ID | Path | Ownership / contents | Initial status |
|---|---|---|---|
| `DOC-016` | `docs/03-architecture/system-architecture.md` | End-to-end components, data flows, trust boundaries and diagrams | PLANNED |
| `DOC-017` | `docs/03-architecture/flutter-app-architecture.md` | Dart/Flutter organization, Riverpod state and app integration boundaries | PLANNED |
| `DOC-018` | `docs/03-architecture/nextjs-dashboard-architecture.md` | Next.js organization, data fetching, permissions and admin/staff separation | PLANNED |
| `DOC-019` | `docs/03-architecture/supabase-schema-and-migrations.md` | Tables, keys, enums, SQL constraints, indexes, migrations and ownership | PLANNED |
| `DOC-020` | `docs/03-architecture/api-and-edge-functions.md` | Function contracts, auth, request/response, idempotency, timeouts and errors | PLANNED |
| `DOC-021` | `docs/03-architecture/auth-rls-and-storage-policies.md` | Supabase Auth, authorization, RLS, storage policies and abuse prevention | PLANNED |
| `DOC-022` | `docs/03-architecture/uploads-storage-and-media.md` | Camera/gallery flow, safe uploads, object access, size limits and retention | PLANNED |
| `DOC-023` | `docs/03-architecture/realtime-notifications-and-events.md` | Event lifecycle, notifications, subscriptions, delivery and de-duplication | PLANNED |

### 04 — AI and algorithms (6)

| ID | Path | Ownership / contents | Initial status |
|---|---|---|---|
| `DOC-024` | `docs/04-ai-and-algorithms/gemini-image-classification.md` | Input/output JSON, prompts, validation, latency, fallback, safeguards | PLANNED |
| `DOC-025` | `docs/04-ai-and-algorithms/duplicate-detection.md` | Candidate search, similarity signals, thresholds and join/report choices | PLANNED |
| `DOC-026` | `docs/04-ai-and-algorithms/smart-priority-engine.md` | Severity, reports, recurrence, age/location scoring and overrides | PLANNED |
| `DOC-027` | `docs/04-ai-and-algorithms/hotspot-and-recurring-issues.md` | Trend definitions, windows, hotspot aggregation and actionable evidence | PLANNED |
| `DOC-028` | `docs/04-ai-and-algorithms/eco-score-and-impact-formulas.md` | Building/campus scores, weight decisions, estimation and transparent units | PLANNED |
| `DOC-029` | `docs/04-ai-and-algorithms/ai-advisor-and-what-if.md` | Evidence-grounded advisor and optional what-if scenario model (P2) | PLANNED |

### 05 — Feature specifications (4)

| ID | Path | Ownership / contents | Initial status |
|---|---|---|---|
| `DOC-030` | `docs/05-feature-specifications/report-lifecycle-and-department-routing.md` | Status transitions, assignment, rejection, duplicate, resolution and audit | PLANNED |
| `DOC-031` | `docs/05-feature-specifications/campus-map-and-location.md` | Building/floor/area hierarchy, map SVG references and optional GPS | PLANNED |
| `DOC-032` | `docs/05-feature-specifications/ecopoints-achievements-and-challenges.md` | Points rules, earning, badges, rankings, level thresholds and P2 challenges | PLANNED |
| `DOC-033` | `docs/05-feature-specifications/analytics-and-admin-insights.md` | KPIs, cohorts, date filters, trend cards and computed dashboard data | PLANNED |

### 06 — Quality and security (4)

| ID | Path | Ownership / contents | Initial status |
|---|---|---|---|
| `DOC-034` | `docs/06-quality/security-threat-model-and-privacy.md` | Threats, privacy, access control, secure keys, abuse cases and mitigations | PLANNED |
| `DOC-035` | `docs/06-quality/test-strategy-and-test-cases.md` | Unit, integration, end-to-end, authorization, AI and acceptance tests | PLANNED |
| `DOC-036` | `docs/06-quality/reliability-performance-and-observability.md` | Targets, measurement, logs/alerts, retries, latency and degradation | PLANNED |
| `DOC-037` | `docs/06-quality/edge-cases-and-recovery.md` | Invalid inputs, outages, offline/timeout, duplicate actions and recovery | PLANNED |

### 07 — Delivery and demonstration (6)

| ID | Path | Ownership / contents | Initial status |
|---|---|---|---|
| `DOC-038` | `docs/07-delivery/team-plan-21-days.md` | Day-by-day milestones, two developer lanes, dependencies and scope freeze | PLANNED |
| `DOC-039` | `docs/07-delivery/agentic-workflow-pr-review.md` | Agent task protocol, feature branches, per-phase PR, review and merge gates | PLANNED |
| `DOC-040` | `docs/07-delivery/environments-deployment-cicd.md` | Local/staging/prod, environment variables, builds, deployment and rollback | PLANNED |
| `DOC-041` | `docs/07-delivery/seed-data-and-demo-fixtures.md` | Sample campuses, students, locations, issues, history and demo reproducibility | PLANNED |
| `DOC-042` | `docs/07-delivery/demo-script-and-pitch.md` | Judge narrative, live walkthrough, expected questions and backup demo | PLANNED |
| `DOC-043` | `docs/07-delivery/final-qa-release-handover.md` | Final checklists, handover, known issues, evidence and release decision | PLANNED |

**Inventory check:** 3 root documents + 41 documents within `docs/` = **44 total**. Directory names and filenames are fixed by this index unless an approved decision changes them.

## 6. Reference entry points by role

Read this index first, then the documents below (once authored and approved). Stop if a required document remains unapproved.

| Role / task | Required reading sequence |
|---|---|
| Any coding agent | `AGENTS.md` → `CLAUDE.md` (if Claude) → `product-requirements.md` → feature-specific specs → `test-strategy-and-test-cases.md` |
| Mobile UI | `users-roles-and-permissions.md` → `student-mobile-screens.md` → `navigation-states-and-error-ux.md` → `flutter-app-architecture.md` → relevant APIs |
| Admin / staff UI | `users-roles-and-permissions.md` → `admin-staff-dashboard-screens.md` → `nextjs-dashboard-architecture.md` → `analytics-and-admin-insights.md` |
| Supabase backend | `user-journeys-and-business-rules.md` → `system-architecture.md` → `supabase-schema-and-migrations.md` → `auth-rls-and-storage-policies.md` → `api-and-edge-functions.md` |
| Gemini / intelligence | `gemini-image-classification.md` → `api-and-edge-functions.md` → `duplicate-detection.md` → `smart-priority-engine.md` → algorithm-specific tests |
| Sustainability scoring | `eco-score-and-impact-formulas.md` → `analytics-and-admin-insights.md` → `hotspot-and-recurring-issues.md` → test evidence |
| QA / security | `requirements-traceability.md` → `security-threat-model-and-privacy.md` → `test-strategy-and-test-cases.md` → `edge-cases-and-recovery.md` |
| Deployment / demo | `environments-deployment-cicd.md` → `final-qa-release-handover.md` → `seed-data-and-demo-fixtures.md` → `demo-script-and-pitch.md` |

## 7. PRD section coverage map

This table maps **every** section of EcoCampus PRD v1.0 to its primary future document(s). Secondary documents must cross-reference the primary document instead of creating an inconsistent rule.

| PRD § | PRD topic | Primary documentation owner(s) |
|---|---|---|
| 1–4 | Overview, problem, goals, non-goals | `product-overview.md`, `product-requirements.md` |
| 5 | Target users | `users-roles-and-permissions.md`, `user-journeys-and-business-rules.md` |
| 6 | Core product flow | `user-journeys-and-business-rules.md`, `system-architecture.md` |
| 7 | Student mobile app | `student-mobile-screens.md`, `functional-requirements.md` |
| 8 | AI intelligence engine | `gemini-image-classification.md`, `duplicate-detection.md`, `smart-priority-engine.md` |
| 9 | Sustainability map | `campus-map-and-location.md`, `eco-score-and-impact-formulas.md` |
| 10 | Recurring issues, hotspots | `hotspot-and-recurring-issues.md`, `analytics-and-admin-insights.md` |
| 11 | Admin dashboard | `admin-staff-dashboard-screens.md`, `analytics-and-admin-insights.md` |
| 12–13 | Gamification and challenges | `ecopoints-achievements-and-challenges.md` |
| 14 | Environmental impact | `eco-score-and-impact-formulas.md` |
| 15–16 | AI Advisor and What-If Simulator | `ai-advisor-and-what-if.md` |
| 17 | Notifications | `realtime-notifications-and-events.md` |
| 18–19 | Architecture and technology | `system-architecture.md`, mobile/web architecture, backend integration docs |
| 20 | Security requirements | `auth-rls-and-storage-policies.md`, `security-threat-model-and-privacy.md` |
| 21 | P0/P1/P2 and future roadmap | `product-requirements.md`, `requirements-traceability.md` |
| 22 | Three-week development plan | `team-plan-21-days.md` |
| 23 | Success metrics | `non-functional-requirements.md`, `test-strategy-and-test-cases.md` |
| 24 | Risks / mitigations | `reliability-performance-and-observability.md`, `edge-cases-and-recovery.md` |
| 25 | Hackathon demo story | `demo-script-and-pitch.md`, `seed-data-and-demo-fixtures.md` |
| 26–27 | USP and north star | `product-overview.md`, `product-requirements.md` |

## 8. Feature → specification routing

Each feature must have a functional specification **and** an implementation/test destination. An agent must not treat a screen spec as the full backend behavior contract.

| Feature family | Primary spec | Supporting contracts |
|---|---|---|
| Login and profiles | `users-roles-and-permissions.md` | `auth-rls-and-storage-policies.md`, mobile/admin screens |
| Student report submission | `report-lifecycle-and-department-routing.md` | `student-mobile-screens.md`, `uploads-storage-and-media.md`, `api-and-edge-functions.md` |
| AI photo classification | `gemini-image-classification.md` | `api-and-edge-functions.md`, `edge-cases-and-recovery.md` |
| Location and campus map | `campus-map-and-location.md` | `supabase-schema-and-migrations.md`, `student-mobile-screens.md` |
| Duplicate detection | `duplicate-detection.md` | `report-lifecycle-and-department-routing.md`, `supabase-schema-and-migrations.md` |
| Issue priority and routing | `smart-priority-engine.md` | `report-lifecycle-and-department-routing.md`, dashboard screens |
| Admin/Staff issue resolution | `report-lifecycle-and-department-routing.md` | role matrix, dashboard screens, RLS policies |
| Campus score / environmental impact | `eco-score-and-impact-formulas.md` | admin analytics, schema, calculation tests |
| EcoPoints, badges, leaderboards | `ecopoints-achievements-and-challenges.md` | schema, role rules, quality tests |
| AI Advisor / simulator (P2) | `ai-advisor-and-what-if.md` | aggregate data APIs, quality/security tests |
| Notification delivery | `realtime-notifications-and-events.md` | auth/RLS and Edge Function contracts |

## 9. Decisions the PRD does not fully specify

These are **unresolved** until reviewed in `decision-register.md`. A document author may propose options, but the agent must not present a proposal as a PRD fact.

| Decision ID | Open question | Primary owner |
|---|---|---|
| `DEC-001` | What are the exact campus/building Eco Score formulas, baselines, and update triggers? | `eco-score-and-impact-formulas.md` |
| `DEC-002` | What are priority weights, normalization, score bands, and override policies? | `smart-priority-engine.md` |
| `DEC-003` | What constitutes a possible duplicate; how are joins and repeated submissions counted? | `duplicate-detection.md` |
| `DEC-004` | Which transitions, reopening/rejection states, SLA rules and assignment permissions are allowed? | `report-lifecycle-and-department-routing.md` |
| `DEC-005` | Are sample EcoPoints mutually exclusive/additive, and when are points reversed or capped? | `ecopoints-achievements-and-challenges.md` |
| `DEC-006` | Which roles can view photos, private reporter data, location and report comments? | `auth-rls-and-storage-policies.md` |
| `DEC-007` | What structured Gemini response, confidence/validation policy and failure fallback are approved? | `gemini-image-classification.md` |
| `DEC-008` | Which campus buildings, floors, areas, polygons and location seeds exist? | `campus-map-and-location.md` |
| `DEC-009` | What justified coefficients and evidence support estimated water/energy/waste impact? | `eco-score-and-impact-formulas.md` |
| `DEC-010` | Do Staff share the web dashboard with Admin, and which routes/actions are staff-visible? | `admin-staff-dashboard-screens.md` |
| `DEC-011` | What deployment environment, secrets management and notification fallback will be used? | `environments-deployment-cicd.md` |
| `DEC-012` | Which P2 features receive demo-ready fixtures versus actual shipped implementation? | `team-plan-21-days.md` |
| `DEC-013` | Which claims are allowed for the Advisor/What-If model without live sensor data? | `ai-advisor-and-what-if.md` |

**PRD guardrails for these decisions:** AI-suggested report information must remain editable; manual reporting must remain possible if AI fails; MVP location uses Building → Floor → Area (GPS optional); impact values are estimates unless independently verified; What-If is scenario modeling, not a guarantee.

## 10. Agentic implementation contract

### Before beginning a code task

1. Read `/AGENTS.md` and, for Claude Code, `/CLAUDE.md` (when created).
2. Identify the feature's **requirement IDs**, priority, relevant PRD sections, owning specification(s), and required tests.
3. Confirm the specs are `APPROVED`, the associated decisions are resolved, and the dependency list is satisfied.
4. Confirm data ownership, auth/RLS and API contracts **before** implementing new data paths.
5. Produce a bounded task plan with target files, migrations, tests and acceptance criteria. Assign the task to the appropriate developer lane.

### During implementation

- Prefer small, reviewable changes and preserve approved contracts.
- Do not insert Gemini secrets into Flutter or web client bundles; keep AI access server-side.
- Do not expose other students' private reporter data or allow student edits to admin-only fields; any cross-user report visibility (for nearby issues/duplicates) requires explicitly approved authorization and privacy rules.
- Do not represent estimated sustainability impact as measured fact.
- Never create a mock/demo result that looks like genuine production evidence.
- If a requirement is missing or inconsistent, record it in the decision register and block **only the affected work** until resolved.

### After implementation

1. Run the tests mapped to the requirement IDs, including failed-network and unauthorized-access tests where relevant.
2. Check any schema changes, data migrations, RLS policies, Edge Functions and affected UI flows.
3. Update requirement traceability and implementation status; record any approved deviations.
4. Open a **narrowly scoped pull request** for the completed unit of work/phase, with evidence and rollback notes where appropriate.
5. Obtain human review and verification before merging. A completed build alone does not prove functional correctness.

> These are **proposed development governance rules** for the project. Branch naming, hosting, CI provider and developer-specific task ownership are deliberately left to the corresponding approved delivery specs.

## 11. Required specification quality bar

Every substantive specification must contain, as applicable:

- **Purpose and PRD provenance:** source sections, requirement IDs, P0/P1/P2 status.
- **Clear behavior:** triggers, actors, inputs, outputs, validation, UI/API/data flow.
- **Explicit boundaries:** roles, permissions, secrets, authorization and privacy.
- **Deterministic contracts:** names, JSON schemas, enums, allowed transitions, formulas, units and defaults (once approved).
- **Edge cases:** timeouts, failed AI, duplicate action, missing location, stale state, invalid or abusive input.
- **Acceptance criteria:** objective pass/fail checks plus representative positive/negative test cases.
- **Dependencies:** required spec IDs, migrations, integrations and blocked decisions.
- **Decision provenance:** what is explicitly in PRD versus proposed versus approved.
- **Accessibility and operational readiness:** where relevant, device responsiveness, logs, performance and release verification.

Do not write `TBD` for a material behavior and simultaneously mark the document `APPROVED`. Resolve the decision, narrow the approved scope, or flag the section as blocked.

## 12. Documentation-first readiness gate

**The team intends to prepare the entire documentation baseline before feature coding.** Docs may be created in any practical authoring order, but implementation starts only when these readiness conditions are met:

- [ ] All **44** files exist with substantive, internally consistent content (not empty templates).
- [ ] `product-requirements.md` preserves every P0/P1/P2 feature from PRD §21.
- [ ] All P0 requirements have unique IDs and testable acceptance criteria.
- [ ] All role permissions and database access boundaries are defined.
- [ ] The image-analysis API schema, manual fallback and safety/error flow are specified.
- [ ] Report statuses, assignment, duplicate handling and points events are consistent across documents.
- [ ] Algorithms have documented formulas **or** explicit human-approved scoped fallback behavior.
- [ ] UI screens, API functions and database entities can be traced to requirements.
- [ ] A reproducible seed/demo dataset and its synthetic nature are documented.
- [ ] Each requirement maps to at least one test or explicit deferred verification reason.
- [ ] Ownership, phase plan, CI/CD and PR/review process have been approved by the two developers.
- [ ] Open decisions are resolved, explicitly deferred, or accompanied by approved fallback rules.
- [ ] The human project owners sign off on the documentation baseline.

**Readiness statuses:**

- `DOCS_IN_PROGRESS`: one or more planned documents are not complete.
- `DOCS_IN_REVIEW`: all drafts exist; cross-document review and decision closure underway.
- `DOCS_APPROVED_FOR_BUILD`: human sign-off obtained; implementation can begin within approved scope.

**Current state:** `DOCS_IN_PROGRESS` — as of 2026-10-10, `DOC-000`, `DOC-004`, `DOC-005`, `DOC-006`, `DOC-007`, and `DOC-008` are authored as unapproved drafts; 38 documents remain planned.

## 13. Documentation authoring sequence

The authoring order is designed to prevent circular assumptions:

1. **Control:** `documentation-index.md` → `decision-register.md` → `requirements-traceability.md`.
2. **Product:** product overview → product requirements → functional requirements → non-functional requirements → roles → journeys/rules.
3. **Architecture:** system view → Supabase schema → Auth/RLS → API/Edge Functions → Flutter/Next.js structures → uploads → Realtime/notifications.
4. **AI:** classification → duplicates → priority → hotspot analysis → score/impact → Advisor/simulator.
5. **Features:** report lifecycle → campus map → gamification → analytics.
6. **UX:** design system → mobile screens → admin/staff screens → navigation/error states.
7. **Quality:** threat model → test strategy → reliability/observability → recovery.
8. **Delivery:** team plan → agent workflow → environments/CI/CD → seed data → demo pitch → release/handover.
9. **Agent entrypoints:** finalize `README.md`, `AGENTS.md` and `CLAUDE.md` to reference the approved file set.

**Next document to author:** `docs/01-product/non-functional-requirements.md` (`DOC-009`). The three control documents (`DOC-000`, `DOC-004`, `DOC-005`) and three product documents (`DOC-006`, `DOC-007`, `DOC-008`) are drafted but unapproved; DEC-001 through DEC-013 remain proposals.

## 14. Change management

When a decision or requirement changes:

1. Create/update a dated entry in `decision-register.md` with requester, rationale, affected PRD sections, alternatives and approval.
2. Update the authoritative product requirement and affected specification(s).
3. Update `requirements-traceability.md` and corresponding acceptance tests.
4. Increment affected document versions; record significant behavior changes in the review PR.
5. Recheck downstream dependencies before implementation or merge.

Do not silently rewrite the PRD's meaning. If EcoCampus PRD v1.0 is revised, explicitly record the newer source version and the migration of requirements.

## 15. Provenance and limitations

- **Grounded source:** the uploaded `EcoCampus_PRD.docx`, version 1.0, sections 1–27.
- **Derived material:** the 44-file organization, document identifiers, status model, reading sequence, dependency routing, decision IDs and review gates are **proposed authoring/workflow choices**, not claims that the PRD specified these exact filenames or rules.
- **Not yet decided:** scoring coefficients, notification infrastructure details, physical campus geometry, precise schemas, endpoints, prompts, deployment provider, owner assignments, and actual test/build results.
- **No production claims:** this index does not certify that any app, backend, integration, model, metric or deployment exists.

---

**DOC-000 maintenance note (2026-10-10, v1.0.5):** Added DOC-008 `docs/01-product/functional-requirements.md` as a DRAFT; updated authored count to 6/44 and planned to 38. DOC-008 details all 24 P0/P1/P2 feature groups and cross-references all 217 existing atomic requirements and proposed verification IDs without changing their identifiers. No implementation, acceptance-test passes, decision approvals or PRD changes are implied. Next: DOC-009 non-functional requirements.

**DOC-000 maintenance note (2026-10-09, v1.0.4):** Added DOC-007 `docs/01-product/product-requirements.md` as a DRAFT; updated progress to 5/44 authored and 39 planned. DOC-007 contracts all 24 PRD feature groups (12 P0 / 7 P1 / 5 P2) and references the 217 source-backed `REQ-*` rows with proposed `TEST-*` oracles from DOC-005. All 13 decision records remain PROPOSED and all test/implementation approvals remain absent. Next: DOC-008 functional requirements.

**DOC-000 maintenance note (2026-10-09, v1.0.3):** Added DOC-006 `docs/01-product/product-overview.md` as a DRAFT; updated progress to 4/44 authored and 40 planned, and advanced the next-document pointer to DOC-007. DOC-006 defines product vision, personas, full P0/P1/P2 scope, north-star flow, source-backed goals and risks, explicit non-goals, and cross-links to the thirteen unapproved decisions. All previously authored control documents remain DRAFT; decision and test approvals are still absent.

**Previous maintenance (2026-10-09, v1.0.2):** Added DOC-005 as a DRAFT and updated progress to 3/44 authored, 41 planned. DOC-005 maps PRD §1–27 to requirement IDs, proposed `TEST-*` IDs, all 24 features and pending decisions. DOC-004 remains DRAFT; none of DEC-001–DEC-013 are approved. No PRD baseline or decision authority changed.

**Previous maintenance (2026-10-09, v1.0.1):** Added DOC-004 as an unapproved draft.

**End of `DOC-000`.** All further EcoCampus documents should cite relevant requirement IDs and follow the rules above.
