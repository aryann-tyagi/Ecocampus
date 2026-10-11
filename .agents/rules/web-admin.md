---
trigger: model_decision
description: "Architectural, typing, UI, security, and visualization conventions for Next.js, TypeScript, and Tailwind CSS web admin dashboard."
globs: "apps/web/**, **/*.ts, **/*.tsx, **/*.css"
---

# EcoCampus Web Admin Dashboard Conventions

## 1. Framework & Project Architecture
- Build with **Next.js (App Router)** using strict **TypeScript**.
- Maintain modular folder organization:
  - `app/`: Route segments, layouts, error boundaries, and loading skeletons.
  - `components/ui/`: Reusable, accessible UI primitives.
  - `components/features/`: Feature-specific compound components (e.g., `IssueQueue`, `AnalyticsOverview`, `CampusMap`).
  - `lib/`: Supabase client helpers, API wrappers, date formatting, and utilities.
  - `types/`: Strongly typed domain entities, database schemas, and enum definitions.

## 2. TypeScript & Component Quality
- Enforce strict typing. Disallow `any`; use discriminating unions and proper Zod/type schemas for API responses and form validation.
- Separate Server Components (default for initial data fetching and static markup) from Client Components (`'use client'` for interactive widgets, filters, and real-time listeners).
- Implement explicit React states: always provide skeletons for loading states, empty collection indicators, and resilient error boundaries.

## 3. Styling & Data Visualization
- **Tailwind CSS:** Use semantic design tokens and Tailwind utility classes. Maintain a cohesive, clean color palette (forest greens, neutral slates, clear semantic severity colors for low/medium/high/critical).
- **Charts:** Use **Recharts** for analytics and trend visualization (e.g., issue distribution, building comparisons, recurring hotspots over time).
- **Campus Map (PRD §9):** Use a custom interactive **2D SVG map** displaying building Eco Scores and issue counts. Do **not** attempt to build a 3D digital twin (PRD §4 explicit non-goal).

## 4. Role-Based Access Control (RBAC) & Security Boundaries
- Distinguish between **Campus Administrator** (full system dashboard, department assignment, priority/status overrides, analytics) and **Department Staff** (assigned issue list, update status, add resolution notes).
- UI conditional rendering is for UX convenience only. **Never rely on frontend checks as security boundaries.**
- **Secret Protection:** Never expose service-role keys or Gemini API keys in client-accessible environment variables (`NEXT_PUBLIC_*`). Only public Supabase project URL and anon key may be exposed to the browser.
- All administrative mutations must execute either via authenticated Supabase client queries governed by PostgreSQL RLS or via server actions / Edge Functions verifying user identity.
