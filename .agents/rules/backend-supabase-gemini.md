---
trigger: always_on
description: "Supabase PostgreSQL architecture, Row Level Security (RLS), Edge Functions, and secure Gemini API integration conventions."
---

# EcoCampus Backend, Database & AI Integration Conventions

## 1. Supabase PostgreSQL Schema & Migrations
- Track all schema modifications through versioned, repeatable SQL migrations under `supabase/migrations/`.
- **Primary Keys & Types:** Use `UUID` primary keys (`gen_random_uuid()`) and `TIMESTAMPTZ` for all temporal fields (default `now()`).
- **Domain Enums:** Enforce PostgreSQL `ENUM` types matching PRD taxonomies:
  ```sql
  CREATE TYPE report_status AS ENUM ('REPORTED', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'REJECTED', 'DUPLICATE');
  CREATE TYPE issue_category AS ENUM ('waste', 'water', 'electricity', 'infrastructure', 'greenery', 'cleanliness', 'other');
  CREATE TYPE issue_severity AS ENUM ('low', 'medium', 'high', 'critical');
  CREATE TYPE user_role AS ENUM ('student', 'staff', 'admin');
  ```
- Establish foreign keys with appropriate referential integrity constraints (`ON DELETE CASCADE` or `RESTRICT`).

## 2. Row Level Security (RLS) Mandate
- **Enable RLS on EVERY Public Table:**
  ```sql
  ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
  ```
- **Access Policies:**
  - `Students`: Permitted to `INSERT` and `SELECT` their own reports (`reporter_id = auth.uid()`). Strictly prohibited from updating reports, changing status, or reading unredacted reports of other users.
  - `Department Staff`: Permitted to view and update status/notes for issues assigned to their department/account.
  - `Campus Administrators`: Permitted full operational read/write access across reports, departments, and analytics.
- Protect user roles in a dedicated table or app metadata controlled exclusively by trusted administrative functions, preventing self-escalation during signup.

## 3. Supabase Edge Functions
- Write Edge Functions in TypeScript running on Deno under `supabase/functions/<function_name>/`.
- Validate JWT identity headers (`Authorization: Bearer <token>`) using `supabase-js` or cryptographic verification before executing privileged operations.
- Enforce request validation using schemas (e.g., Zod) and return standardized JSON responses with consistent error contracts (`{ ok: boolean, data?: ..., error?: { message, code } }`).

## 4. Secure Gemini API Integration
- **Server-Side Exclusivity (PRD §20):** All calls to the Gemini API must originate strictly within Supabase Edge Functions (e.g., `analyze-report`).
- **Secret Management:** Store the Gemini API key in Supabase Secrets (`GEMINI_API_KEY`). **NEVER** expose the key in client code, public repository files, or client environment variables.
- **Structured JSON Prompts:** Use structured output mode or explicit system instructions requesting a JSON payload containing only:
  - `issue` (string label)
  - `category` (one of the 7 valid `issue_category` enum values)
  - `severity` (one of `low`, `medium`, `high`, `critical`)
  - `department` (suggested department from campus table)
  - `description` (short contextual description)
- **Validation & Fallback (PRD §24):** Always validate Gemini responses against the enum taxonomy before returning them to the client. If the model fails or produces invalid JSON, return a graceful fallback allowing manual user entry.

## 5. Environmental Impact & Eco Score Integrity (PRD §14, §16)
- Clearly distinguish measured facts from modeled projections.
- All water, electricity, and waste metrics computed by the impact engine must be explicitly labeled in APIs and databases as **estimates**.
- Do not fabricate synthetic or arbitrary scores without documenting the exact mathematical formula and baseline assumptions.
