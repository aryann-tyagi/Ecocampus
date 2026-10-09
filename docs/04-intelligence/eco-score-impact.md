---
title: 'Eco Score and Environmental Impact Estimation Methodology'
package_doc_id: ECO-18
version: '0.1.0'
status: DRAFT
owner: 'Product / technical lead (TBD)'
prd_source: 'EcoCampus Product Requirements Document v1.0; §§3, 9, 14, 16, 21, 23'
prior_document_mapping: 'DOC-028'
priority_scope: 'P1'
date: '2026-10-10'
---

# Eco Score and Environmental Impact Estimation Methodology

> **Path:** `docs/04-intelligence/eco-score-impact.md`  
> **Status:** DRAFT — comprehensive agent-ready specification for review, **not approved implementation authority**.  
> **PRD:** EcoCampus PRD v1.0 §§3, 9, 14, 16, 21, 23; legacy registry: DOC-028.  
> **Decision gates:** `DEC-001`, `DEC-003`, `DEC-004`, `DEC-009`, `DEC-013`.


## Contract status and authority

- **Source-backed:** Statements explicitly labeled *PRD baseline* reproduce EcoCampus PRD v1.0. Paragraphs labeled *proposed design* are implementation candidates, not approved requirements.
- **Approval gate:** `DEC-001` through `DEC-013` in the existing decision register are `PROPOSED`. No suggestion in this document approves them. For blocked implementation work, obtain written human sign-off; log changed requirements before coding.
- **Scope:** P0 is must-have, P1 high-value, P2 stretch. Optional home widgets do not automatically promote P1 or P2 backend features into P0.
- **Source references:** `EcoCampus_PRD.docx` §numbers; existing `docs/00-control/requirements-traceability.md` for stable `REQ-*` and `TEST-*` IDs; `docs/00-control/decision-register.md` for dependencies.
- **Implementation honesty:** Examples, scores, expected savings and seed data are illustrative until measured or approved. Do not describe unimplemented designs or unexecuted tests as production-ready.

## Baseline vs unknowns
**PRD baseline:** Campus and Building Eco Scores are displayed; building view includes Waste, Water, Energy, Greenery and Maintenance (PRD §9.1). The Environmental Impact Engine estimates water saved, energy saved and waste handled after appropriate issues resolve (PRD §14). Values are **estimated unless verified by real sensors/utility data**.

**Not supplied:** metric weights, scale normalization, initial score/baseline, sample size, per-incident conversion coefficients, verified measurements, score re-compute triggers and uncertainty bounds. These are gated under `DEC-001/009`.

## Proposed, explainable score data contract
```json
{
  "scope": "building",
  "scopeId": "building_uuid",
  "period": "2026-10",
  "overallScore": null,
  "categories": {
    "waste": null, "water": null, "energy": null,
    "greenery": null, "maintenance": null
  },
  "formulaVersion": null,
  "dataQuality": "insufficient_data"
}
```
`null` signifies uncalculated; never substitute PRD illustration values as real scores.

## Candidate modeling approach (proposed, not approved)
1. Define exposure/location denominator (such as known area/building activity) or state limitation if unavailable.
2. Define category factor based on severity-weighted unresolved incidents, validated recurrence and resolution freshness.
3. Normalize each factor to `[0,100]` with explicit upper bound and version.
4. Aggregate category scores with agreed weights to building; aggregate buildings to campus with agreed weighting (equal vs footprint/traffic).
5. Store version, observation window, data completeness and computation timestamp.
6. Review how old incidents decay and whether `RESOLVED` recovers score immediately or gradually.

### Formula sketch for review
```text
category_score = clamp(0, 100, baseline_category - penalty(open_incidents, severity, age, recurrence))
building_score = SUM(category_weight_i * category_score_i)
campus_score = AGGREGATE(building_score_by_building, approved_building_weights)
```
No particular baseline, weighting, penalty or output value is source-authorized.

## Impact estimation pipeline
1. Select **resolved** issues of supported waste/water/electricity types only.
2. Attach approved intervention type and resolution evidence if available.
3. Apply versioned *estimated effect per incident/time period*, derived from a disclosed method.
4. Aggregate distinct eligible issues only once, accounting for duplicate supporters.
5. Display metric + value + unit + period + label `estimated` + method/source.

## Units and example caution
PRD §14 examples: `38 water issues → estimated 12,400 L/week`, `72 electricity issues → estimated 840 kWh/month`, `126 waste issues → estimated 426 kg handled`. These **must not** be reverse-engineered into universal coefficients or claimed measured. Units differ between week/month/handled waste: never add unrelated periods or units.

## Proposed table of evidence provenance
| Metric | Source of issue count | Coefficient provenance needed | Display |
|---|---|---|---|
| Water saved | Resolved unique water incidents | Approved leak-rate × duration or documented proxy | `Estimated L/week` |
| Electricity saved | Resolved unique electricity incidents | Approved device kW × avoided runtime proxy | `Estimated kWh/month` |
| Waste handled | Resolved unique waste incidents | Documented bin/mass proxy or actual weighing | `Estimated kg handled` |

## Safeguards against misleading impact
- Resolution status is evidence that a workflow closed, **not proof of measured savings**.
- No impact for unrelated issues or incomplete evidence unless proxy explicitly defined.
- Duplicates and reopened reports require an approved adjustment policy.
- Always show a date range and avoid over-precise decimal claims.
- Separate cumulative totals from rates like `L/week`.
- AI Advisor/What-If must use these calculation APIs rather than fabricating independent figures.

## Validation scenarios
| Input condition | Expected candidate result |
|---|---|
| No incidents/data | `Not calculated` or `0 eligible cases`, not fabricated 100 Eco Score |
| Single water leak resolved | One estimate with unit/period/method; no exact number until coefficient approved |
| Same incident joined by many reporters | One physical impact result, not one per supporter |
| Issue reopened | Clearly defined recalculation or reversal per DEC-004/009 |
| Missing category factor | Mark incomplete score and identify missing factor |
| Two formula versions | Comparisons flag version mismatch or recalculate consistently |

## Gate
Before any numeric result is rendered as calculated, approve: factor equations, weights, input definitions, measurement vs model label, unit consistency, snapshots, uncertainty disclosure and automated reference tests. Without approval, retain placeholders and qualitative counts only.


## Agent acceptance checklist (proposed)

- [ ] No score/impact numeric example is mislabeled measured or production-calculated.
- [ ] Unit and time period survive aggregation without mixing weekly/monthly values.
- [ ] Joined duplicate reports do not multiply estimated savings.
- [ ] Formula version, observation period and quality status are available to UI/tests.
- [ ] Estimate updates after eligible resolution follow an approved transition policy.

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
| `REQ-GOAL-005` | Estimate environmental impact of resolved supported issues | §3 (G5) | P1 | DEC-009 |
| `REQ-FLOW-005` | Recompute relevant impact and campus intelligence after applicable issue changes | §6, §§9–10, 14 | P1 | DEC-001, DEC-009 |
| `REQ-MAP-001` | Provide a 2D interactive campus map rather than 3D digital twin | §9 | P1 | DEC-001, DEC-008 |
| `REQ-MAP-002` | Display building-specific Eco Score on map | §9 | P1 | DEC-001, DEC-008 |
| `REQ-MAP-003` | Display building issue information on map | §9 | P1 | DEC-001, DEC-008 |
| `REQ-MAP-004` | Provide building sustainability profile | §9 | P1 | DEC-001, DEC-008 |
| `REQ-MAP-005` | Show example profile dimensions: Waste, Water, Energy, Greenery, Maintenance | §9 | P1 | DEC-001, DEC-008 |
| `REQ-MAP-006` | Show active, resolved and recurring issue totals in building profile | §9 | P1 | DEC-001, DEC-008 |
| `REQ-IMPACT-001` | Estimate environmental impact after issue resolution | §14 | P1 | DEC-009 |
| `REQ-IMPACT-002` | Provide estimated water saving outputs with volume/time units | §14 | P1 | DEC-009 |
| `REQ-IMPACT-003` | Provide estimated electricity outputs in kWh/time | §14 | P1 | DEC-009 |
| `REQ-IMPACT-004` | Provide estimated waste handled outputs in kg | §14 | P1 | DEC-009 |
| `REQ-IMPACT-005` | Label non-verified impact values explicitly as estimates | §14 | P1 | DEC-009 |
| `REQ-IMPACT-006` | Do not claim verified impact without real sensor or utility evidence | §14 | P1 | DEC-009 |
| `REQ-SIM-001` | Let administrator select interventions such as resolving top water/waste/energy issues | §16 | P2 | DEC-001, DEC-009, DEC-013 |
| `REQ-SIM-002` | Calculate estimated projected Eco Score after intervention | §16 | P2 | DEC-001, DEC-009, DEC-013 |
| `REQ-SIM-003` | Display estimated projected environmental impact with units | §16 | P2 | DEC-001, DEC-009, DEC-013 |
| `REQ-SIM-004` | Disclose that simulated outcomes are not guaranteed predictions | §16 | P2 | DEC-001, DEC-009, DEC-013 |

18 source-linked rows displayed of 18 applicable rows. The full master registry in the earlier control docs remains authoritative; this subset is informational.


## Approval record

| Field | Value |
|---|---|
| Product reviewer | TBD |
| Technical reviewer | TBD |
| Security / quality reviewer, where applicable | TBD |
| Blocking decisions approved? | No — consult decision register |
| Implementation status | Not assessed; this is a planning/specification document |
| Approval date / revision | Pending |
