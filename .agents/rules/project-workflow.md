---
trigger: always_on
description: "Universal EcoCampus project workflow, specification precedence, decision gate governance, scope boundaries, and development verification."
---

# EcoCampus Project Workflow & Governance Rules

## 1. Source of Truth & Precedence Hierarchy
Always resolve product, functional, and architectural questions using the following strict hierarchy:
1. **Product Source of Truth:** `reference/EcoCampus_PRD.docx` (v1.0, sections 1–27) is the definitive baseline. Any conflict between downstream documentation and the PRD is won by the PRD unless a formal, human-approved scope change is logged.
2. **Control & Governance Index:** `docs/00-control/` guides document navigation, requirement mapping, and decision records.
   - *Note on Existing Docs:* Be aware that `docs/00-control/documentation-index.md` currently contains the Decision Register (DOC-004), while `docs/00-control/requirements-traceability (1).md` contains the master documentation index (DOC-000 v1.0.5).
3. **Module Specifications:** Specifications in `docs/01-product/`, `docs/02-design/`, `docs/03-engineering/`, `docs/04-intelligence/`, and `docs/05-delivery/` provide detailed design guidance.
4. **Draft & Decision Gate Integrity:**
   - All markdown specifications carry `status: DRAFT`.
   - All recorded decisions (`DEC-001` through `DEC-013`) are in `PROPOSED` status.
   - **NEVER** treat draft designs, proposed heuristics, or synthetic mockups as approved requirements without explicit human sign-off.
   - When specifications are ambiguous or unapproved, adopt conservative, non-blocking fallbacks aligned with the PRD baseline.

## 2. Scope Boundaries & Delivery Discipline
- **Must-Have Focus (P0):** Prioritize the 12 P0 features: Authentication, Student Home, Report Issue, Photo Upload, AI Classification, Location, Report Tracking, Admin Dashboard, Department Assignment, Status Management, EcoPoints, Basic Analytics.
- **High-Value (P1) & Stretch (P2):** P1 (Duplicate Detection, Smart Priority, 2D SVG Map, Building Eco Score, Leaderboard, Recurring Issues, Impact Calculations) and P2 (AI Advisor, What-If Simulator, Eco Challenges) must not block or complicate P0 delivery.
- **Explicit Non-Goals:** Do not design or implement 3D digital twins, IoT hardware sensors, real-time utility sub-metering, automated physical robotics, drone surveillance, complex AR navigation, university ERP integrations, or external payment/reward redemption systems (PRD §4).

## 3. Pre-Coding Workflow
1. **Inspect Documentation First:** Before writing or modifying any code, read the relevant documents in `docs/` and check for open questions or constraints.
2. **Honor Approved Taxonomies:**
   - Categories: `waste`, `water`, `electricity`, `infrastructure`, `greenery`, `cleanliness`, `other`.
   - Severities: `low`, `medium`, `high`, `critical`.
   - Lifecycle States: `REPORTED` → `ASSIGNED` → `IN_PROGRESS` → `RESOLVED` (with optional `REJECTED`, `DUPLICATE`).
3. **Avoid Unrelated Changes:** Keep diffs minimal, focused, and clean. Do not reformat unrelated files or introduce unrequested refactorings.
4. **Preserve Comments & Docstrings:** Do not remove existing docstrings or explanatory comments unless explicitly tasked to do so.

## 4. Verification & Testing Before Completion
- Execute relevant unit, widget, or integration tests before declaring any task complete.
- Verify that changes compile cleanly and do not produce type errors or lint warnings.
- Validate that mock data and test fixtures are clearly separated from production logic.
