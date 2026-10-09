---
document_id: DOC-004
title: EcoCampus Decision Register
version: 0.1.0
status: DRAFT
source: EcoCampus PRD v1.0 (13 pages, sections 1-27); DOC-000 documentation-index.md v1.0.1
last_updated: 2026-10-09
owner: Product Lead and Technical Lead (people not yet assigned)
reviewers:
  - Product Lead (TBD)
  - Technical Lead (TBD)
related_documents:
  - docs/00-control/documentation-index.md
  - docs/00-control/requirements-traceability.md
  - docs/01-product/product-requirements.md
  - docs/01-product/user-journeys-and-business-rules.md
  - docs/03-architecture/system-architecture.md
  - docs/06-quality/test-strategy-and-test-cases.md
---

# EcoCampus — Decision Register

**Document:** DOC-004  
**Version:** 0.1.0 — Initial review draft  
**Effective decisions:** **None**. The recommendations in this document are *not* approved implementation requirements.  
**Source baseline:** `EcoCampus_PRD.docx`, Product Requirements Document v1.0, 27 sections; and `docs/00-control/documentation-index.md` (DOC-000, v1.0.1).  
**Purpose:** Make important missing product and engineering decisions explicit *before* autonomous/agentic implementation starts. Prevent AI coding agents from filling specification gaps with assumptions.

> **Non-negotiable:** A `PROPOSED` recommendation is a request for human judgment, not authority to implement. Only a record bearing an explicit `APPROVED` status, named approver, approval date, and decision text becomes binding. If an approved decision materially changes the source PRD's scope, formally approve the PRD change and update requirement/test traceability first.

---

## 1. How to use this register

1. Review the 13 decisions in **§4–§16**, with Product and Technical Leads together.
2. For each decision, select an option or write a replacement, document exact parameters, identify affected requirement IDs, and capture the rationale.
3. Fill the **decision closure and approval record** in **§18**. Do **not** change the status to `APPROVED` without a named human approver and dated evidence (for example, a pull-request review or signed meeting note).
4. Update the *owning* technical/functional spec in DOC-000's inventory. Then connect the approved rule to requirement IDs, test IDs and implementation references in `docs/00-control/requirements-traceability.md` (DOC-005).
5. Block only the affected feature/contract while a decision is unresolved. Other documented, approved work can proceed when allowed by the project's documentation-first readiness gate.
6. Reopen a decision if new evidence invalidates its assumptions; do not silently overwrite an earlier approval.

### 1.1 Decision status vocabulary

| Status | Meaning | Agent permitted to implement? |
|---|---|---|
| `OPEN` | No candidate is ready for review | No |
| `PROPOSED` | One or more options/recommendations are drafted | **No** |
| `IN_REVIEW` | Human stakeholders are actively evaluating options | No |
| `APPROVED` | A specific decision has named, dated human approval | Yes, within its approved scope and dependencies |
| `DEFERRED` | Explicitly postponed; fallback and restrictions must be documented | Only the *separately approved* fallback, if any |
| `SUPERSEDED` | Replaced by another identified decision/revision | No |

**At creation:** DEC-001 through DEC-013 are all `PROPOSED`; every approval field is blank. No decision, acceptance test, schema, score formula, hosting selection or implementation described here has been approved or built.

### 1.2 What counts as authoritative

- **PRD-backed requirement:** a statement supported by the supplied PRD section listed for that decision.
- **Proposed interpretation/design:** a candidate rule to review, *not* a fact from the PRD.
- **Approved decision:** a recorded selection with exact parameters and a human sign-off.
- **Illustrative test fixture:** synthetic example data; never evidence that environmental savings or AI quality has been measured.

The source-of-truth precedence and conflict rules are specified in DOC-000 §3. If this draft conflicts with the PRD, **the PRD wins until an authorized, traceable change is accepted**.

### 1.3 Decision identifiers

`DEC-001` … `DEC-013` are stable identifiers already registered in DOC-000 §9. Do not renumber, recycle, or quietly delete them. New cross-cutting decisions should use `DEC-014` onward and be added to DOC-000 and DOC-005. The decision ID is different from the `DOC-XXX` document ID and from future `REQ-XXX`/`TEST-XXX` IDs.

---

## 2. Confirmed PRD guardrails — not open for silent alteration

These are *source requirements*, not choices created by this register:

| Source | Confirmed baseline |
|---|---|
| PRD §§3, 23 | Goal: report in under **60 seconds**; success targets: classification in under **10 seconds**, successful submission **>95%**; prioritize and track issues, identify trends, estimate impact and encourage participation. |
| PRD §§5–7 | Student, Campus Administrator and Department Staff roles; students take/upload a photo, confirm location and track reports. |
| PRD §7.3 | AI proposes issue, category, severity, department and description. **AI-generated information must be editable before submission.** |
| PRD §§7.4–7.5 | Categories: Waste, Water, Electricity, Infrastructure, Greenery, Cleanliness, Other. Severities: Low, Medium, High, Critical. Admin can override the AI's severity recommendation. |
| PRD §7.6 | MVP location selection: **Building → Floor → Area**; GPS is optional. |
| PRD §7.7 | Core states: **REPORTED → ASSIGNED → IN PROGRESS → RESOLVED**; `REJECTED` and `DUPLICATE` are optional. |
| PRD §8 | Duplicate signals: category, location, description similarity, optional image similarity and time proximity; priority signals: severity, report count, recurrence, age and location impact. |
| PRD §9 | **2D/SVG map** for MVP; full 3D digital twin is excluded. |
| PRD §12 | Example action-point schedule: valid report +30, issue resolved +20, critical valid report +50, challenge completed +100. |
| PRD §14 | Water, energy and waste impacts are **estimates** unless independently verified with actual sensor/utility data. |
| PRD §§15–16 | AI Advisor should give practical, data-grounded recommendations; What-If is a **scenario model**, not a guaranteed forecast. |
| PRD §§18–20 | Flutter/Riverpod mobile; Next.js admin; Supabase PostgreSQL/Auth/Storage/Realtime/Edge Functions; Gemini via server; RLS for role enforcement; never embed Gemini API keys in Flutter. |
| PRD §21 | Keep **12 P0**, **7 P1** and **5 P2** features at their recorded priorities unless a scope change is approved. |
| PRD §§23–24 | Successful report submission target **>95%**; manual category/description fallback when AI fails; building/floor/area rather than GPS alone; focus on P0 before P1/P2. |

**Illustrative, not prescribed:** the sample building scores in §9, priority values in §8.3, similarity `91%` in §8.2 and impact quantities in §14 do **not** supply actual formulas, tuned thresholds, measured environmental outcomes or guaranteed model accuracy.

---

## 3. Decision queue and blocking map

**Impact:** `P0-blocking` means an approval is necessary before the related must-have behavior can be treated as implementation-ready. `P1-blocking` and `P2-blocking` apply to the relevant later-priority functionality. One decision may affect multiple tiers. A proposed fallback is **not** automatically approved.

| ID | Short question | Work affected | Priority / gate | Proposed decision owner | Status |
|---|---|---|---|---|---|
| **DEC-001** | Campus/building Eco Score formula and display | Home (P0); Building score (P1) | **P0 display / P1 calculation** | Product + Data/Backend Leads | `PROPOSED` |
| **DEC-002** | Priority formula, ranking, admin overrides | Admin issue queue (P0); Smart priority (P1) | **P0 ordering / P1 engine** | Product + Backend Leads | `PROPOSED` |
| **DEC-003** | Duplicates, joining and counting reports | Duplicate detection (P1); reporting/points | **P1**, P0 data-model dependency | Product + Backend Leads | `PROPOSED` |
| **DEC-004** | Status transitions, rejection, reopening, assignment | Report tracking, assignment, status (P0) | **P0-blocking** | Product + Admin Workflow Lead | `PROPOSED` |
| **DEC-005** | EcoPoints eligibility, additive rules, reversal | EcoPoints (P0); leaderboard (P1); challenges (P2) | **P0-blocking** | Product + Backend Leads | `PROPOSED` |
| **DEC-006** | Reporter/photo/location visibility and permissions | Auth, RLS, uploads, nearby issues (P0) | **P0 security-blocking** | Security + Product Leads | `PROPOSED` |
| **DEC-007** | Gemini contract, AI confidence and fallback | Image classification/report flow (P0) | **P0-blocking** | AI + Backend Leads | `PROPOSED` |
| **DEC-008** | Campus hierarchy and source locations | Location (P0); 2D map (P1) | **P0-blocking** | Product + Campus Data Lead | `PROPOSED` |
| **DEC-009** | Water, energy, waste estimation methodology | Impact calculations (P1); optional advisor | **P1-blocking** | Product + Sustainability Lead | `PROPOSED` |
| **DEC-010** | Staff interface and separation from admin | Staff workflow/assignments (P0) | **P0-blocking** | Product + Security/Frontend Leads | `PROPOSED` |
| **DEC-011** | Deployment, secret handling, push fallback | P0 app/backend and web; notifications | **P0 release-blocking** | Technical + Release Leads | `PROPOSED` |
| **DEC-012** | P2 implementation vs demo/roadmap | Optional P2 and judge demo | **P2**, release claim integrity | Product + Team Leads | `PROPOSED` |
| **DEC-013** | Advisor evidence and What-If disclosure | Advisor/What-If (P2) | **P2-blocking** | AI + Product Leads | `PROPOSED` |

**High-impact review order:** DEC-004 → DEC-006 → DEC-010 → DEC-007 → DEC-008 → DEC-005 → DEC-011 → DEC-001 → DEC-002 → DEC-003 → DEC-009 → DEC-012 → DEC-013. Dependencies do not replace the DOC-000 authoring order.

---

## 4. DEC-001 — Campus and building Eco Score

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** P0 student-home score display; P1 building score/map and more detailed sustainability analytics.
- **PRD provenance:** §§7.2, 9–9.1, 11, 14, 16, 21, 25; examples show campus/building scores and category scores, but no calculation method.
- **Decision owner / required review:** Product Lead; Data/Backend Lead; Sustainability reviewer (people TBD).

### The missing decision

What inputs, baselines, weights, update triggers and no-data states define a score from 0–100? Does a building-level score roll up to a campus score, and how are waste, water, energy, greenery and maintenance sub-scores computed without sensors?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Issue-led deterministic scoring using verified reports and fixed public weights | Reproducible, but proxy for sustainability rather than direct consumption |
| B | Manually maintained starting score plus issue adjustments | Simple, but depends on human calibration and can appear arbitrary |
| C | Display `Insufficient data` until a verified score method and minimum evidence exist | Most careful scientifically, but may reduce early dashboard visual value |

### Initial recommendation — **proposal only**

Use **A with C for insufficient evidence**. For each building, produce a reproducible *issue-based Eco Score*, clearly described as a platform indicator, not a sensor-based measurement. Proposed scoring inputs are active reports weighted by severity and an optional recurrence penalty. Record the exact mathematical function, normalization, lookback window, weights and rounding policy in DOC-028 *before* exposing calculated scores. The campus score should aggregate eligible building scores using an explicitly approved weighting rule (equal weighting is a candidate if occupancy data is not available). No score should be silently fabricated when baseline data is missing.

**Possible calculation shape, not approved or calibrated:** `building_score = clamp(100 - active_issue_penalty - recurring_issue_penalty, 0, 100)`. Formula components and coefficients remain unresolved until review; the PRD's `91`, `82`, `61`, etc. are display illustrations only.

### Approval questions

1. What defines an eligible active issue: `REPORTED`, `ASSIGNED`, `IN_PROGRESS`, or only admin-validated items?
2. What is the campus roll-up weight: equal building weight, area/occupancy (if data exists), or issue exposure?
3. Can sub-scores be shown with enough data to justify five dimensions? What is the no-data UI text?
4. Does score recomputation happen on submission, validation, status transition, or scheduled batch?

### Required verification before closure

- Deterministic same-input/same-score test; score bounded 0–100; no divide-by-zero or missing-building crashes.
- Explicit handling of zero historical data, duplicates, rejected reports and status changes.
- Documented contribution of a resolved issue and clear label that the indicator is report-based.
- Campus aggregation verified against hand-calculated multi-building fixtures.

**Owning specs:** DOC-028, DOC-031, DOC-033; **screens:** DOC-013, DOC-014; **tests:** DOC-035.  
**Implementation restriction while pending:** do **not** hardcode PRD example scores into live data pathways or label them as observed truth. A separately approved no-data/fixture strategy is required for P0 home.

---

## 5. DEC-002 — Smart priority engine and provisional P0 sorting

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** P0 usable queue ordering; P1 quantitative priority engine.
- **PRD provenance:** §§3 (G3), 7.5, 8.3, 11, 21, 25. Priority factors: severity, number of reports, recurrence, age, location impact. Admin can override AI severity; dashboard can change priority.
- **Decision owner / required review:** Product Lead; Backend Lead; Campus Operations reviewer (people TBD).

### The missing decision

What numeric formula, factor caps, score bands, re-evaluation triggers and override rules turn the five inputs into a priority from 0 to 100?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Weighted, normalized rule engine | Deterministic/explainable; requires agreed factor scales |
| B | Severity-first categorical queue with oldest-first tie-break | Low complexity P0 fallback; lacks multi-factor intelligence |
| C | AI-assigned numeric priority | Flexible; harder to audit or reproduce; provider-dependent |

### Initial recommendation — **proposal only**

For **P0**, use **B** as a limited fallback *only if approved*: sort `CRITICAL > HIGH > MEDIUM > LOW`, with oldest reports first within a level; make the dashboard label this as **severity order**, not as the P1 Smart Priority Engine. For **P1**, use **A** with source-verifiable inputs, deterministic score calculation, explicit factor weights and normalized ranges. A candidate weight allocation for review is **severity 50%, validated supporter count 20%, recurring history 15%, age 10%, location impact 5%**. These values are *design suggestions* and are not in the PRD. Admin manual priority override must be audited; decide whether overrides expire or survive automatic re-scoring.

### Approval questions

1. How are each input and the candidate weights normalized to 0–100?
2. Which statuses are eligible, and how does an issue age stop increasing priority indefinitely?
3. Does joining a duplicate increase a supporter count, and can one user count only once?
4. What numeric thresholds map to Low, Medium, High, Critical and how do user/admin labels interact?
5. When does automatic recomputation occur? Who may manually override the final score?

### Required verification before closure

- Determinism; range 0–100; monotonicity for rising severity and reports (unless capped).
- Missing recurrence/low-report behavior and repeated-event idempotency.
- Override is permission-checked, attributed and not silently replaced.
- Explainable breakdown stored or reproducible for UI and troubleshooting.

**Owning specs:** DOC-026 and DOC-030; **related:** DOC-025, DOC-019, DOC-033, DOC-035.  
**Implementation restriction while pending:** no invented priority score or presentation of illustrative `24/81/94` values as calculated evidence.

---

## 6. DEC-003 — Duplicate detection, join semantics and counts

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** P1 duplicate engine; P0 schema and report flow may need forward-compatible design.
- **PRD provenance:** §§2, 6, 8.2, 21, 24–25. Signals include category, location, description, time proximity, image similarity where available. Student is offered **Join Existing Issue** or **Report Anyway**.
- **Decision owner / required review:** Product Lead; Backend/AI Lead; Privacy reviewer (people TBD).

### The missing decision

How are duplicate candidates searched/scored, what threshold triggers a warning, what does *join* create, and how does a join affect issue count, priority, points and reporter privacy?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Deterministic candidate filter + text similarity; confirmation is manual | Explainable MVP/P1, avoids forced false merges |
| B | Admin-only duplicate review; no student-level join | Safer but misses user benefit shown in PRD demo |
| C | Auto-merge on a model similarity threshold | Fewer duplicates but risks hiding distinct incidents |

### Initial recommendation — **proposal only**

Use **A** for P1: compare only eligible, non-terminal incidents using canonical category and campus location, a configurable recent-time window, and a reproducible text-similarity method. Treat **image similarity as P2**, consistent with PRD §21. As *candidate tuning parameters*, consider a **14-day** recency window and **0.75** text similarity threshold; these are **not** derived from the PRD and must be validated against representative samples before approval. Show redacted issue details rather than another reporter's private data. **Join Existing Issue** creates a unique user-to-issue endorsement/support link instead of silently replacing/deleting history. **Report Anyway** creates a separate report and records that the warning was seen. Do not auto-merge based only on AI confidence.

### Approval questions

1. Exact matching rules, time window, location granularity and thresholds?
2. Can resolved/rejected reports be candidates? Can a user join their own report?
3. Is the join reversible? Does joining count toward priority and EcoPoints?
4. Can an admin mark two existing reports as duplicates after submission, and how are linked records preserved?
5. What can the joining student view about the original report and its owner?

### Required verification before closure

- False-positive and false-negative fixture set spanning same/different locations, categories and dates.
- Unique endorsement per user and issue; retry-safe join/report operations.
- No leakage of reporter identity, private images or restricted admin notes.
- Clear history and reward implications for joined and rejected reports.

**Owning specs:** DOC-025, DOC-030; **dependencies:** DOC-005, DOC-019, DOC-021, DOC-032; **tests:** DOC-035.  
**Implementation restriction while pending:** no silent merge, no hardcoded `91%` match result, and no unsupported claim of advanced image matching.

---

## 7. DEC-004 — Issue lifecycle, reassignment, rejection and reopening

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** **P0-blocking**: tracking, assignments and status updates require one shared contract.
- **PRD provenance:** §§5.2–5.3, 6, 7.7, 11.1, 17, 21. Four defined core states; `REJECTED` and `DUPLICATE` are optional. Admin can assign departments, change statuses and reject invalid reports; Staff can update assigned issues and add notes.
- **Decision owner / required review:** Product Lead; Admin Operations Lead; Backend/Security Leads (people TBD).

### The missing decision

Which actors can trigger each state transition, can issues be reopened, can staff reassign work, what qualifies as valid/duplicate/rejected, and when do user notifications/rewards fire?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Controlled state machine with role-specific transitions and append-only history | Auditable; more setup |
| B | Admin-editable status field with permissive updates | Faster UI; risks impossible states and reward duplication |

### Initial recommendation — **proposal only**

Use **A**. Candidate core path: `REPORTED → ASSIGNED → IN_PROGRESS → RESOLVED`. Allow an authorized **Admin** to assign/reassign and optionally reject with a required reason; allow **Staff** to progress and resolve only assigned department issues, with required resolution note. Treat `REJECTED` and `DUPLICATE` as explicitly approved optional terminal paths, not implied mandatory ones. A reopened state/transition is *not prescribed* in the PRD; either define `RESOLVED → IN_PROGRESS` under Admin-only control with a reason, or explicitly defer reopening. Persist append-only transitions (`previous_status`, `new_status`, `actor`, `timestamp`, `reason`, `assignment_id` as applicable). Status updates, points and notification event creation should be atomic or retry-idempotent.

**Candidate transition matrix (must be approved):**

| From | To | Candidate actor | Minimum condition |
|---|---|---|---|
| `REPORTED` | `ASSIGNED` | Admin | Valid department assignment |
| `ASSIGNED` | `IN_PROGRESS` | Assigned Staff; Admin | Permission/assignment verified |
| `IN_PROGRESS` | `RESOLVED` | Assigned Staff; Admin | Resolution note recorded |
| `REPORTED` / `ASSIGNED` | `REJECTED` | Admin | Rejection reason; if optional state enabled |
| `REPORTED` / `ASSIGNED` | `DUPLICATE` | Admin | Canonical issue linked; if optional state enabled |
| `RESOLVED` | `IN_PROGRESS` | Admin (optional) | Reopen reason + reward adjustment policy |

### Approval questions

1. Can a report be assigned to a department without a specific staff member?
2. Is rejected/duplicate report status included in P0, despite being optional in PRD §7.7?
3. Will reopening ship? Can `ASSIGNED → RESOLVED` be allowed for quick fixes?
4. Who can edit severity, category, department, resolution evidence and notes?
5. Are SLA deadlines tracked in P0 or deferred with advanced notifications?

### Required verification before closure

- Valid/invalid transition table, including concurrency and repeated API requests.
- RLS/API authorization tested for student, unrelated Staff, assigned Staff and Admin.
- Status audit history and notes remain intact across reassignments.
- Notifications and points emit at most once per qualifying transition; reversal behavior defined if reopened/rejected.

**Owning specs:** DOC-030, DOC-011, DOC-021; **dependencies:** DOC-019, DOC-020, DOC-023, DOC-032, DOC-035.  
**Implementation restriction while pending:** do not implement a permissive `status` update endpoint or authorize Staff across departments.

---

## 8. DEC-005 — EcoPoints earning, stacking, reversal and anti-abuse

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** **P0-blocking** for EcoPoints; P1 leaderboard; P2 challenges.
- **PRD provenance:** §§6, 12–13, 21, 25. The table lists **valid issue +30**, **issue resolved +20**, **critical valid report +50**, **challenge complete +100**. The PRD does not explain whether the +50 replaces/adds to +30 or whether a duplicate gains points.
- **Decision owner / required review:** Product Lead; Backend Lead; Trust/Abuse reviewer (people TBD).

### The missing decision

When is a report considered valid, how do critical points stack, can one reporter repeatedly earn on the same issue, and what happens after a rejection/duplicate marking or reopening?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Event-based points ledger and de-duplicated eligibility checks | Auditable; needs transactions and compensating entries |
| B | Mutable total balance adjusted on every status change | Simpler initially; easy to double-credit or lose history |

### Initial recommendation — **proposal only**

Use **A**. Proposed interpretation: **+30** once for a *validated non-critical original report*, **+50 instead of +30** once for a *validated critical original report* (not +80), **+20** once when that same eligible issue is resolved, **+100** for a completed challenge *only if P2 challenges ship*. Record award type, report/challenge ID, beneficiary, event ID, policy version and timestamp in an immutable ledger; use unique idempotency keys for each award. A submission may show **pending points** until an Admin validates the report, since the PRD says *valid* rather than every submission. Linked duplicate endorsements should not award another full report bonus without explicit approval. Negative adjustment/reversal events should compensate for incorrectly credited reports without deleting ledger history.

### Approval questions

1. Is the critical award **replacement** (+50) or **additive** (+30 +50)?
2. Does validation occur automatically on submission, after moderation, or on assignment?
3. Does issue resolution grant points to the original reporter, all supporters, or the resolving staff member?
4. Do invalid, duplicate or re-opened issues trigger reversals? Can balances become negative?
5. Is there a reporting/day cap, per-location cap, review queue or other spam limiter?
6. Is leaderboard ranking based on all-time points, month-to-date points, or both (PRD names campus/monthly/challenge rankings)?

### Required verification before closure

- Same event delivered twice results in **one** award.
- Invalid or duplicate report cannot farm points; authorized adjustments are auditable.
- Severity changed after validation follows a defined upgrade/downgrade adjustment policy.
- Leaderboard totals reconcile to the authoritative ledger; points are awarded only by trusted server logic.

**Owning specs:** DOC-032, DOC-011; **dependencies:** DOC-019, DOC-020, DOC-021, DOC-023, DOC-035.  
**Implementation restriction while pending:** no unconditional `+30` for every upload, no client-authoritative balance updates, and no assumption that +30/+50 stack.

---

## 9. DEC-006 — Report privacy, photo access and authorization matrix

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** **P0 security-blocking** for auth, student reports, storage and admin/Staff access.
- **PRD provenance:** §§5, 7.2, 7.7, 8.2, 9, 20–21. Every user authenticates; roles Student/Staff/Admin; RLS required; students read/create their own reports but cannot modify others' records/admin fields; nearby issues and duplicate previews introduce cross-user disclosure questions.
- **Decision owner / required review:** Security Lead; Product Lead; Backend Lead (people TBD).

### The missing decision

What can each role read about another student, an issue, an image, precise location, resolution notes and staff identity? What is the retention/deletion policy? How can nearby issues and duplicate previews be offered without contradicting the PRD's own-report access rule?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Private authoritative report rows + separately authorized, redacted public summaries | Supports nearby/duplicate UI with explicit privacy boundary |
| B | Every student can read every raw issue row | Easier queries, conflicts with least-privilege intent and reporter privacy |
| C | No cross-user discovery in initial release | Safest initial access boundary, limits nearby/duplicate experience |

### Initial recommendation — **proposal only**

Use **A** if the team approves cross-user issue previews; otherwise explicitly choose **C** for P0. Proposed student access: self-owned full report; for another student's issue, only an approved **redacted summary** (for example public issue category, broad location, current status, submission age, no owner identity, no private image or internal notes). Treat full report images as **private Supabase Storage objects**; issue expiring signed URLs only after server-side authorization. Admins can manage campus issues with audit logging; Staff can view only issues they are permitted to work on (see DEC-010). Never expose service-role keys or Gemini credentials in Flutter/Next.js client code. Retention periods, account deletion and appeal/access requests remain to be agreed; do not silently invent regulatory policies.

### Approval questions

1. Is an issue's exact Building/Floor/Area public to other students, or only building-level?
2. Are issue photos ever visible outside its reporter, assigned Staff and Admin?
3. Are `nearby issues` and `Join Existing Issue` backed by sanitized views/Edge Functions, or deferred?
4. How are Staff permissions scoped to department, specific assignment and historical reports?
5. What is the approved retention/deletion lifecycle for user accounts, media and audit logs?
6. Is campus email restriction enabled? PRD §7.1 marks this **optional**.

### Required verification before closure

- Cross-user read/update/delete denial and unauthenticated access denial; Admin allow cases.
- Attempted arbitrary Storage object access and leaked/expired signed URL behavior.
- No reporter names, private notes or private photo URLs in nearby/duplicate summaries.
- Authorization enforced in SQL RLS *and* privileged server functions; negative tests in DOC-035.

**Owning specs:** DOC-021, DOC-034; **dependencies:** DOC-010, DOC-019, DOC-020, DOC-022, DOC-025, DOC-030, DOC-035.  
**Implementation restriction while pending:** do not turn off RLS, create public report-photo buckets, or leak raw reports to all authenticated students.

---

## 10. DEC-007 — Gemini response contract and manual fallback

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** **P0-blocking** for the AI-assisted submission flow.
- **PRD provenance:** §§3 (G1/G2), 6, 7.3–7.5, 8.1, 18–21, 23–24. Example AI object has `issue`, `category`, `severity`, `department`, `description`; generated information is editable; AI must not block manual reporting when it fails.
- **Decision owner / required review:** AI Lead; Backend Lead; Product Lead (people TBD).

### The missing decision

What exact server-side request/response schema, category/department vocabulary, confidence policy, timeouts and validation rules are needed to use Gemini safely and meet the target classification latency?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Strict structured AI output validated against server-side enums/schema | Predictable mobile/backend interface; rejects unrecognized output |
| B | Free-text AI result parsed heuristically in Flutter | Quick prototype, fragile and violates the separation of trust |

### Initial recommendation — **proposal only**

Use **A**, with Gemini invoked exclusively from a **Supabase Edge Function**. Candidate normalized response contract:

```json
{
  "issue": "overflowing_waste_bin",
  "category": "waste",
  "severity": "medium",
  "department": "housekeeping",
  "description": "Overflowing waste bin near the cafeteria entrance."
}
```

The structure is based on the PRD's **illustrative object**, but the stable enum values, department taxonomy, field lengths, response envelope, provider model/version, optional confidence and error details remain **subject to approval**. Server validates and sanitizes the model output; client shows all AI suggestions as editable. If Gemini returns invalid JSON, unsupported content, failure or timeout, show a non-blocking message and manual category/description entry, allowing ordinary submission. The PRD's **<10-second classification target** should be verified on representative devices/networks, with an approved timeout budget and no hidden unbounded retries.

### Approval questions

1. Which issue/department identifiers are allowable and how are AI labels mapped to configurable departments?
2. Should confidence appear in the API at all? What happens if the model returns an unsupported label?
3. What file sizes/types and image privacy safeguards apply before inference (DEC-006/DOC-022)?
4. Exact function path, auth identity propagation, timeouts, model configuration and rate limiting?
5. Can a manually entered report omit an image after photo analysis fails, or does P0 always require a photo?

### Required verification before closure

- Valid structured response, partial fields, unknown category, low-quality image and provider outage fixtures.
- Manual report reaches persistence even when AI is unavailable.
- Auth, input size, content-type, rate-limit and secret-exposure negative tests.
- Target AI latency measured on a representative synthetic fixture set; no invented accuracy or reliability claim.

**Owning specs:** DOC-024, DOC-020; **dependencies:** DOC-008, DOC-022, DOC-021, DOC-035, DOC-036.  
**Implementation restriction while pending:** no Gemini API key in client code; no unvalidated raw model text written to trusted enum columns; no forced acceptance of model suggestions.

---

## 11. DEC-008 — Campus location master data and map geography

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** **P0-blocking** for building/floor/area reporting; P1 for campus SVG map and building profiles.
- **PRD provenance:** §§7.6, 9–10, 21, 24. MVP selects **Building → Floor → Area**; GPS optional. `Block A`, `Block B`, `Library`, `Canteen` and `Cafeteria Entrance` are examples, not a verified campus inventory.
- **Decision owner / required review:** Product Lead; Campus Operations/Data representative; Backend Lead (people TBD).

### The missing decision

Which actual campus is represented, who verifies its buildings/floors/areas, what identifiers are stable, and how are issue locations joined to 2D SVG elements? How should an unlisted area be handled?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Curated canonical campus hierarchy seeded into Supabase | Good reporting consistency; requires validated input dataset |
| B | Free-text locations | Fast to enter but damages hotspot and duplicate quality |
| C | GPS-only geolocation | Conflicts with PRD's MVP selector and poor indoor accuracy |

### Initial recommendation — **proposal only**

Use **A**. Model a stable `campus_id` (if relevant), `building_id`, `floor_id`, `area_id`, display name, active flag and optional verified map-element ID/geometry. Keep canonical IDs independent of human labels. Provide an explicitly designed **Other / area not listed** workflow if approved, with optional free-text *supplement* without replacing the Building → Floor → Area hierarchy. Reserve coordinates for optional GPS; do not invent actual building polygons, latitudes/longitudes or facilities. Require a named campus data owner to sign off on seed data and any SVG alignment. Synthetic demo locations must be labeled as fixtures and separated from real-campus production data.

### Approval questions

1. Which institution/campus and specific building/floor/area dataset will be supplied?
2. How are unnamed areas handled while preserving mandatory location confirmation?
3. Do buildings with different floor nomenclature need custom floor ordering?
4. Is the SVG map provided, drawn from approved campus reference material, or postponed until P1?
5. Can Admin manage location records after launch, and what happens to historic report links?

### Required verification before closure

- Every reported area belongs to the selected floor/building; inactive areas handled gracefully.
- Renaming or retiring a location does not break report history.
- No invented coordinates; optional GPS failure leaves manual location working.
- Each approved map element resolves to a canonical building ID; unseen buildings degrade to a list view.

**Owning specs:** DOC-031, DOC-019; **dependencies:** DOC-013, DOC-014, DOC-025, DOC-027, DOC-035, DOC-041.  
**Implementation restriction while pending:** sample campus labels must never be described as a surveyed or verified real campus.

---

## 12. DEC-009 — Defensible estimated environmental impact

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** P1 Impact Calculations; additional implications for P2 Advisor and What-If.
- **PRD provenance:** §§3 (G5), 9, 14, 16, 21, 23. Example displays estimated liters/week saved, kWh/month saved and kilograms of waste handled. **All impact values must be clearly marked as estimates unless supported by real sensor/utility data.**
- **Decision owner / required review:** Product Lead; Sustainability/Facilities reviewer; Backend Lead (people TBD).

### The missing decision

Which incident categories are quantifiable, where do conversion factors come from, when is an estimate generated, how are units and time periods standardized, and how is double-counting prevented?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Conservative, category-specific assumptions documented per issue subtype | Explainable, but still uncertain proxies |
| B | Treat every resolved report as a fixed universal environmental saving | Easy, but scientifically misleading |
| C | Show resolved issue counts and `Not estimable` when data is missing | Accurate limitations, fewer headline savings metrics |

### Initial recommendation — **proposal only**

Use **A where defensible; C otherwise**. Store a versioned **impact assumption catalogue** (issue subtype, input data needed, coefficient, unit, calculation window, source/justification, confidence/limitations). Only produce numeric impact for a resolved, eligible original issue where the required inputs and approved method exist. Suggested examples for review—not verified scientific values:

- **Water:** leakage volume = justified estimated flow rate × hours of prevented leakage (if both can be supported).
- **Electricity:** kWh avoided = device power (kW) × operating hours avoided (if supplied/verified).
- **Waste:** mass handled = recorded mass or a defensible documented quantity-to-mass method, not simply one constant per photo.

Do not add `liters/week` to `liters/day`, or compare kWh and kg directly. Prevent duplicate/support links from generating new savings. Store calculation provenance, version and whether an output is `ESTIMATED`, `VERIFIED`, or `NOT_ESTIMABLE` (candidate classification, pending approval). In the absence of trustworthy input, show **`Impact estimate unavailable`** and retain the verified *issue resolved* count.

### Approval questions

1. Which issue subtypes qualify, and which facility/source documents justify coefficients?
2. Where do rate, time, power and waste quantity inputs come from?
3. What time periods should dashboards use (`week`, `month`, cumulative)?
4. Is user/admin input permitted to influence estimates, and who verifies it?
5. How will uncertainties, changes in assumptions and reversals appear in exports/analytics?

### Required verification before closure

- Each implemented formula has explicit units, example inputs, hand-calculated outputs and missing-input handling.
- No metric generated for unrelated categories or duplicate endorsements.
- Dashboard clearly says **Estimated** with method/assumptions available; cannot present sample PRD outputs as real outcomes.
- Numeric consistency and temporal aggregation tests, with provenance retained after coefficient version change.

**Owning specs:** DOC-028, DOC-033; **dependencies:** DOC-019, DOC-027, DOC-029, DOC-035.  
**Implementation restriction while pending:** do not claim measured savings from uploaded images or substitute PRD example liters/kWh/kg as production calculations.

---

## 13. DEC-010 — Staff web interface and role separation

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** **P0-blocking** for Staff visibility, assignments, status edits and access policies.
- **PRD provenance:** §§5.2–5.3, 11, 18–21. Staff see assigned issues, update status and notes, and mark resolved; Admins oversee campus-wide queues/assignments/analytics. PRD specifies a Next.js **Admin Dashboard** but not a separate staff application.
- **Decision owner / required review:** Product Lead; Frontend Lead; Security Lead (people TBD).

### The missing decision

Do Admin and Staff use the same web application with different roles, or are separate staff screens/projects required? Which fields/actions are staff-facing?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Shared Next.js application; distinct role-guarded routes and components | Less duplication; authorization and UI guards must be exact |
| B | Separate staff web application | Clear separation; more deployment and maintenance overhead |
| C | Staff actions only through Admin accounts | Simplest surface but breaks least privilege and Staff role expectations |

### Initial recommendation — **proposal only**

Use **A**. Admin sees all authorized campus issues, assign/reassign, override priority, reject, view analytics. Staff sees only their permitted department/assigned work queue; can add resolution notes and perform approved transitions. Staff must not browse other students' private reporter data or obtain admin analytics/configuration privileges merely by discovering a URL. Enforce role/assignment checks in **Supabase RLS and server APIs**, not only conditional rendering. Decide whether Staff can directly mark an issue `RESOLVED` without prior `IN_PROGRESS` and whether a department assignment implies visibility to all department members.

### Approval questions

1. Is Staff visibility per department, individually assigned user, or both?
2. Are Admin and Staff managed by campus administrators only, and how are roles granted/revoked?
3. Which admin routes/widgets should be hidden from Staff?
4. Are staff access controls tenant/campus-scoped, including future multi-campus records?
5. Does Staff need mobile access for the hackathon, or only responsive web?

### Required verification before closure

- Authorized vs unauthorized route access and direct API/RLS access for all three roles.
- Fresh permission changes reflected without requiring account re-creation.
- User cannot self-promote by changing a profile role column or crafting a request.
- Staff actions attributed to staff identity and assignment in the issue audit trail.

**Owning specs:** DOC-010, DOC-014, DOC-018, DOC-021, DOC-030; **tests:** DOC-034, DOC-035.  
**Implementation restriction while pending:** no shared privileged admin account for Staff and no role authorization only in the browser.

---

## 14. DEC-011 — Hosting, environments, secrets and notification fallback

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** **P0 release-blocking** for usable backend, mobile builds and dashboard; advanced notifications P2.
- **PRD provenance:** §§17–21, 22–24. Supabase and Firebase Cloud Messaging are named; GitHub is specified. The PRD does **not** choose a Next.js hosting provider, Supabase project/environment topology, CI service, credentials ownership or build distribution method.
- **Decision owner / required review:** Technical Lead; Release Lead; Security reviewer (people TBD).

### The missing decision

Where will the Next.js application run, what environments and secrets ownership apply, how will Android/iOS artifacts be tested, how are schema/Edge Function changes deployed, and what is the in-app fallback if push delivery is not available?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Managed Next.js host + managed Supabase with documented dev/demo separation | Appropriate for small team; vendor/account configuration required |
| B | Self-host full web/backend environment | More control, but higher operational burden |

### Initial recommendation — **proposal only**

Prefer **A** while preserving the PRD's Supabase/Next.js stack. Select the actual web host and organization accounts explicitly during review; **no host is chosen in this document**. Proposed release rules:

- Separate production/demo data from local development; migrations applied from version control with dry-run and rollback plan where feasible.
- Server secrets (Gemini, privileged Supabase keys and FCM credentials) stored in protected environment configuration only; only publishable/public keys go to clients as intended.
- Document local → staging/demo → release promotion; Android and iOS verification requirements, device availability and account prerequisites must be agreed rather than assumed.
- Realtime/in-app state remains the source of truth for report status. If push is not configured, the user can still see the latest status when the application is opened/refreshed. This is a **candidate fallback** and does not erase PRD §17's notification aspirations.
- Choose CI checks, backup/restore responsibilities, alerting and demo incident handling before release.

### Approval questions

1. Which exact hosting provider, domains, Supabase project(s) and organization owners?
2. Is an iOS build/test/signing route available to the two-person team, or does the demo prioritize Android with iOS scoped to planned support?
3. What constitutes minimum viable P0 status notification versus P2 advanced notifications?
4. Who manages environment access, key rotation and emergency revocation?
5. What is the deployment approval workflow and recovery strategy if an Edge Function or migration fails?

### Required verification before closure

- Repeatable deploy from a clean checkout; zero secrets committed to Git.
- Device and web smoke tests using the approved demo environment.
- Database RLS still enforced when called through deployed apps/Edge Functions.
- Network/push outage does not corrupt report status; release-backout steps documented.

**Owning specs:** DOC-040, DOC-023, DOC-036, DOC-043; **dependencies:** DOC-016, DOC-019, DOC-020, DOC-021, DOC-035.  
**Implementation restriction while pending:** do not invent production domains, provider accounts, credentials or successful deployment assertions.

---

## 15. DEC-012 — Stretch scope and honest demo representation

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** P2 implementation and judge presentation; affects scope freeze rather than core P0 architecture.
- **PRD provenance:** §§4, 15–16, 21–22, 24–25. P2: AI Advisor, What-If Simulator, Eco Challenges, Advanced Notifications, Advanced Image Similarity. PRD recommends freezing major development around days 19–20 and prioritizing P0 first.
- **Decision owner / required review:** Product Lead; both Developer Leads; Demo Lead (people TBD).

### The missing decision

Which P2 items, if any, will actually ship; which remain roadmap-only; can pre-seeded sample data be shown without implying production completeness; and what constitutes a truthful demo of a partial feature?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Finish P0/P1, ship only verified P2, present the rest as roadmap | Reduces demo risk, protects truthful claims |
| B | Prototype all P2 as loosely connected UI | Visually broad; quality/credibility risk |
| C | Commit to every P2 regardless of quality gates | Scope and reliability risk in three weeks |

### Initial recommendation — **proposal only**

Use **A**. Require a scope checkpoint after P0 workflow validation and before starting P2. For each optional feature maintain one of `SHIPPED_VERIFIED`, `DEMO_PROTOTYPE`, `ROADMAP_ONLY`, `DEFERRED` (candidate release-label vocabulary). Seeded reports and demo accounts are acceptable if explicitly labeled **synthetic/demo data** in developer docs and demo notes. Do not present mocked Gemini responses as real inference, scenario estimates as sensor measurements, or an inactive P2 screen as a working release feature.

### Approval questions

1. What minimum verified P0/P1 feature set is mandatory for judges?
2. Which optional feature provides highest demonstration value within remaining capacity?
3. Which screens will be hidden, shown as labeled concepts, or built with real endpoints?
4. What decision date/quality gate stops adding new features?
5. Who signs off on presentation claims and demo fixture descriptions?

### Required verification before closure

- Features in the judge script match tested behavior on the demo build.
- Every synthetic dataset and stub path is identifiable and excluded from production metrics.
- P0 completion and critical security tests are not traded away to produce P2 visuals.
- Explicit deferred list and known limitations in release handover.

**Owning specs:** DOC-038, DOC-041, DOC-042, DOC-043; **dependencies:** DOC-007, DOC-035, DOC-029.  
**Implementation restriction while pending:** no claim that P2 systems are complete based solely on mocked screens or seeded outputs.

---

## 16. DEC-013 — AI Advisor grounding and What-If claim boundaries

- **Status:** `PROPOSED` (not approved)
- **Priority/gate:** P2-blocking, and credibility/security gate if those features are demoed.
- **PRD provenance:** §§15–16, 20–21. Advisor should use *application data* to answer practical sustainability questions. What-If models projected Eco Score and estimated impacts; results are **not guaranteed predictions**.
- **Decision owner / required review:** AI Lead; Product Lead; Data/Sustainability reviewer (people TBD).

### The missing decision

What data can Advisor read, what sources and citations support recommendations, how does it avoid inventing campus facts, and how should scenario projections disclose inputs and limitations?

### Options

| Option | Description | Trade-off |
|---|---|---|
| A | Deterministic, access-controlled aggregates + LLM narrative constrained to evidence | Explainable, verifiable, secure, but narrower capabilities |
| B | Free-form chatbot with unrestricted database context | Quick demo, high privacy/hallucination and unverifiable-claim risk |
| C | Template-based insights without an LLM | Safest and cheapest; less natural-language flexibility |

### Initial recommendation — **proposal only**

Use **A** if the P2 feature is pursued; **C** is a possible approved fallback. A server-side query layer returns only campus-authorized aggregate data (issue counts, verified statuses, trends, scored buildings, estimate metadata). Gemini then creates a response constrained to those facts; response should include referenced metric/time-window identifiers, actionable recommendations and an `insufficient_data`/uncertainty path. Never give the LLM unrestricted service-role access or the ability to modify incidents through a free-form prompt. What-If should run an explicitly versioned **scenario calculation** on selected interventions and return `current`, `projected`, `difference`, `assumptions`, `estimate_disclaimer`, rather than asserting expected future physical savings as certainty.

### Approval questions

1. What approved aggregate endpoints and minimum sample sizes can Advisor access?
2. How are claims tied to source filters, time periods and current permissions?
3. May the Advisor include recommendations beyond the dataset, and how will those be labeled?
4. Which proposed interventions are supported by the What-If simulator's calculation model?
5. How will scenarios respond to nonexistent data, duplicates, missing impact factors or a stale Eco Score?

### Required verification before closure

- Advisor never returns another campus's restricted/private user data.
- Quantitative claims trace to query outputs; unknown data yields a transparent limitation, not invented figures.
- Identical inputs produce the same numerical simulation; text output is permitted to vary only in prose.
- UI clearly labels projections as scenarios/estimates and includes the underlying assumptions.

**Owning specs:** DOC-029, DOC-028, DOC-033; **dependencies:** DOC-021, DOC-027, DOC-035, DOC-036.  
**Implementation restriction while pending:** no unrestricted admin-data chatbot, no claims of predictive accuracy without validation, and no guaranteed-impact messaging.

---

## 17. Cross-decision dependencies and consistency checks

Use this list to prevent one apparently minor approval from breaking another approved specification.

| If this decision is approved/changed… | Re-review these other decisions | Reason |
|---|---|---|
| DEC-001 Eco Score | DEC-004, DEC-008, DEC-009, DEC-013 | States, location mapping, estimate inputs and scenario projections can change score meaning |
| DEC-002 Priority | DEC-003, DEC-004, DEC-008 | Supporter counts, transitions and location impact affect ranking |
| DEC-003 Duplicates | DEC-002, DEC-005, DEC-006, DEC-009 | Joining affects prioritization, points, public summaries and impact counting |
| DEC-004 Lifecycle | DEC-002, DEC-005, DEC-009, DEC-010, DEC-011 | Status events drive queue ranking, rewards, resolution estimates, staff workflow and delivery |
| DEC-005 EcoPoints | DEC-003, DEC-004, DEC-010 | Eligibility, resolution status and privilege boundaries must agree |
| DEC-006 Privacy | DEC-003, DEC-007, DEC-010, DEC-013 | Photo and issue data disclosure differs across matching, inference and analytics |
| DEC-007 Gemini | DEC-006, DEC-008, DEC-011 | Consent/access, department taxonomy, API secrets and deployment must align |
| DEC-008 Locations | DEC-001, DEC-002, DEC-003, DEC-009 | Building analytics, hotspot/duplicate grouping and location impact depend on canonical IDs |
| DEC-009 Estimates | DEC-001, DEC-004, DEC-013 | Reporting and scenario outputs cannot exceed evidence boundaries |
| DEC-010 Staff | DEC-004, DEC-006, DEC-011 | Lifecycle permissions, data access and deployed routing depend on role design |
| DEC-011 Deployment | DEC-006, DEC-007, DEC-010 | Auth, secrets, inference and protected administration cross runtime boundaries |
| DEC-012 P2 scope | DEC-013, DEC-011 | Actual demo scope determines whether optional AI and notification infrastructure is needed |
| DEC-013 Advisor/What-If | DEC-001, DEC-006, DEC-009 | Aggregate permission boundaries, scoring and estimated impact define grounded output |

### 17.1 Human review scenarios

Use these examples to verify that reviewers understand the end-to-end implications:

1. **Student reports a critical water leak:** AI suggests severity and department; student edits the suggestion; authoritative location is recorded; Admin or Staff resolves it; points and any estimate must follow the same approved validation and status rules. (DEC-004/005/007/008/009/010)
2. **Two students report the same broken light:** if P1 duplicate matching runs, the second sees a privacy-safe candidate and may join or report separately; counts, priority and awards must be internally consistent. (DEC-002/003/005/006)
3. **Wrongly marked as resolved:** if reopening is enabled, undo/adjust rewards, issue age and impact calculations using auditable events; otherwise explain the approved correction workflow. (DEC-001/004/005/009)
4. **Gemini is unavailable:** users can manually enter categories/descriptions and submit; no leaked API key; classification latency should fail fast without blocking the entire report. (DEC-006/007/011)
5. **No historical campus records:** no invented campus score, recurring hotspot, impact claim or What-If future prediction; demo fixtures clearly labeled if used. (DEC-001/008/009/012/013)
6. **Staff member tries to inspect another department's report:** access denied on both web route and actual database/storage APIs, even with a crafted request. (DEC-004/006/010)

---

## 18. Approval, decision closure and change-control template

### 18.1 Review checklist for **each** DEC

- [ ] Source PRD sections and non-negotiable statements confirmed.
- [ ] Selected option and exact behavior/fallback recorded.
- [ ] P0/P1/P2 scope impact examined; any PRD-change request explicitly opened.
- [ ] Role permissions, data security and privacy reviewed.
- [ ] Inputs, outputs, numeric thresholds and error behavior made testable.
- [ ] Related DEC conflicts/dependencies reviewed using §17.
- [ ] Target documents and requirement/test IDs enumerated (or a traceability issue created).
- [ ] Named approver, approval date/time and evidence link captured.
- [ ] Authoritative technical spec updated and reviewed after decision approval.
- [ ] Status explicitly changed and any old decision marked `SUPERSEDED` rather than erased.

### 18.2 Copyable decision sign-off record

> **Important:** The unfilled example below is a **template**, not a signed decision. Fill one instance in the selected decision section or link to a verified decision artifact.

```yaml
# DEC-XXX approval record — TEMPLATE ONLY
id: DEC-XXX
status: PROPOSED                # OPEN | PROPOSED | IN_REVIEW | APPROVED | DEFERRED | SUPERSEDED
selected_option: null          # A/B/C/custom; record precise final decision
binding_decision_text: null    # Implementation-ready behavior, thresholds and exceptions
proposed_by: null              # Named person
reviewed_by: []                # Named people and review roles
approved_by: null              # Named human; required if APPROVED
approved_at: null              # ISO-8601 timestamp; required if APPROVED
approval_evidence: null        # PR URL, meeting record or signed decision note
prd_change_required: null      # true/false
prd_change_reference: null     # Revision/approval reference if true
scope: null                    # P0/P1/P2 and included/excluded behavior
owner_of_followup: null        # Person responsible for updating specs
specs_to_update: []            # DOC IDs or exact paths
requirement_ids: []            # Assigned in DOC-007/DOC-005
acceptance_test_ids: []        # Assigned in DOC-035/DOC-005
fallback_if_deferred: null     # Separately approved fallback, if any
supersedes: null               # Earlier DEC revision or ID, if relevant
next_review_date: null         # Optional
```

### 18.3 Approval roles and evidence

The PRD names only a **two-developer team**, not the people's authority or campus approval chain. Therefore named approvers have **not been assigned**. The proposed minimum approval protocol is:

- **Product Lead:** validates product intent, P0/P1/P2 scope, UX/user-impact and campus credibility.
- **Technical Lead:** validates build feasibility, API/data model consistency, performance and operational implications.
- **Security/Privacy reviewer:** must review role access, photo privacy, keys and any cross-user discovery before DEC-006/DEC-010 approval; one of the two developers can hold this role if explicitly assigned and qualified.
- **Campus/Facilities/Sustainability stakeholder (if available):** confirms real campus hierarchies, environmental coefficients and score interpretation. If unavailable, unsupported real-world metrics must remain estimates/unavailable rather than invented facts.

A human can hold more than one role; record this openly. Approval means explicit agreement to the *actual text/parameters*, not merely approval of a file's spelling or formatting. Links to a GitHub pull request, review comment or dated team meeting note are acceptable evidence when they clearly identify the decision.

### 18.4 Proposed meeting agenda (45–60 minutes; not a scheduled event)

| Segment | Suggested duration | Decisions |
|---|---:|---|
| Core workflow and roles | 15 min | DEC-004, DEC-006, DEC-010 |
| AI, locations, gamification | 15 min | DEC-007, DEC-008, DEC-005 |
| Scores, priority, duplicates, impact | 15 min | DEC-001, DEC-002, DEC-003, DEC-009 |
| Release and stretch plan | 10 min | DEC-011, DEC-012, DEC-013 |
| Confirm owners, approval evidence and follow-up | 5 min | All |

The durations are a planning suggestion, not a PRD commitment. If decisions cannot be made responsibly during the review, leave them `IN_REVIEW` and record the blocker.

### 18.5 Change log

| Date | Register version | Change | Author / approval |
|---|---|---|---|
| 2026-10-09 | 0.1.0 | Initial draft: expanded all DEC-001–DEC-013 from DOC-000 with source anchors, options, explicit unapproved recommendations, dependencies, verification and approval workflow. | Prepared for team review; **no approvals** |

---

## 19. Coverage, handoff and agent readiness

### 19.1 Requirement-to-decision crosswalk

| PRD area | Relevant decisions | Intended specs from DOC-000 |
|---|---|---|
| Student home / map / Eco Score (§§7,9) | DEC-001, DEC-008 | DOC-013, DOC-028, DOC-031 |
| AI classification and fallback (§§7–8,24) | DEC-007, DEC-006 | DOC-024, DOC-020, DOC-022 |
| Duplicate and priority engines (§8) | DEC-002, DEC-003 | DOC-025, DOC-026 |
| Status, assignment, Staff (§§5–7,11) | DEC-004, DEC-010 | DOC-010, DOC-011, DOC-030 |
| Gamification (§§12–13) | DEC-005, DEC-003 | DOC-032 |
| Estimated environmental impact (§14) | DEC-009, DEC-001 | DOC-028, DOC-033 |
| AI Advisor and simulator (§§15–16) | DEC-012, DEC-013 | DOC-029 |
| Security and storage (§20) | DEC-006, DEC-010, DEC-011 | DOC-021, DOC-022, DOC-034 |
| MVP/release/deployment (§§17–24) | DEC-011, DEC-012 | DOC-038, DOC-040, DOC-043 |

DOC-005 must eventually add actual requirement IDs, test IDs, implementation references and closure evidence; these do not yet exist and must not be fabricated here.

### 19.2 What a coding agent should do on encountering an unresolved decision

```text
1. Locate the relevant DEC ID in this register.
2. Check status and approval evidence.
3. If PROPOSED / OPEN / IN_REVIEW:
   - Do not assume the recommended option is approved.
   - Identify which exact task is blocked.
   - Continue only independent, approved work (if permitted by DOC-000 readiness gate).
   - Surface the required decision to the human owner.
4. If DEFERRED:
   - Implement only the separately APPROVED fallback, if any.
5. If APPROVED:
   - Read the binding decision text and updated authoritative spec.
   - Implement with the specified permissions, edge cases and tests.
6. If an approved contract conflicts with the PRD or another approved spec:
   - Halt the affected implementation and request reconciliation.
```

### 19.3 Ready-for-review checklist for DOC-004

- [x] Includes all 13 IDs defined in DOC-000 §9; no IDs reused.
- [x] Distinguishes PRD facts, proposed options, illustrative examples and absent evidence.
- [x] Includes decision owners **by role** without inventing named humans.
- [x] Identifies which choices block P0, P1 or P2.
- [x] Records options, recommendation, required questions, acceptance/verification and dependent docs.
- [x] Specifies approval, change-control and cross-decision review.
- [ ] Product Lead has reviewed and supplied selected options/parameters.
- [ ] Technical Lead has reviewed inter-module contracts.
- [ ] Security/privacy reviewer has confirmed access and storage boundaries.
- [ ] Required campus/impact information has been supplied or formally deferred.
- [ ] All P0-blocking decisions have approved binding text or approved fallbacks.
- [ ] DOC-005 requirement/test traceability reflects the approved outcomes.

**Current readiness:** `DRAFT / READY FOR HUMAN REVIEW`, **not approved for agent implementation**.

---

## 20. Provenance and limitations

**Source material actually consulted:**

1. `EcoCampus_PRD.docx` — EcoCampus Product Requirements Document, version 1.0, 13 pages, sections 1–27.
2. `docs/00-control/documentation-index.md` — DOC-000, version 1.0.1, especially §§2–5, 9–14, containing the 44-file catalog, stable DEC IDs and document-governance rules.

**Not supplied by either source:** real campus inventory/geometry, environmental conversion coefficients, measured Eco Score data, numeric ranking weights, calibrated duplicate thresholds, production provider credentials, API endpoints, a completed SQL schema, permission approval, notification delivery guarantee, owner identities or any deployed/working software evidence.

All values suggested beyond those sources are explicitly **proposed**. This document does not modify the original PRD, approve a decision, certify a test, or create an implementation contract on its own.

---

**End of DOC-004 — EcoCampus Decision Register v0.1.0 (DRAFT).**
