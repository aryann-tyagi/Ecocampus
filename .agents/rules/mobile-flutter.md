---
trigger: model_decision
description: "Architectural, state management, security, and UI conventions for Flutter, Dart, and Riverpod mobile app development."
globs: "apps/mobile/**, **/*.dart, lib/**"
---

# EcoCampus Flutter & Riverpod Mobile Conventions

## 1. Architecture & File Structure
- Structure mobile code by feature (`lib/features/<feature_name>/` containing `presentation/`, `domain/`, `data/`) or clean layers.
- Maintain a shared core library (`lib/core/`) for networking, error handling, design tokens, theme, and common widgets.
- Write strict, null-safe Dart adhering to official Flutter lint rules (`flutter_lints`).

## 2. Riverpod State Management
- Use `flutter_riverpod` (Riverpod 2.x+) with code generation (`@riverpod`) or declarative providers (`NotifierProvider`, `AsyncNotifierProvider`).
- Encapsulate async operations inside `AsyncValue` to enforce consistent UI handling of `.loading`, `.error`, and `.data`.
- Keep widgets declarative using `ConsumerWidget` or `ConsumerStatefulWidget`. Avoid storing ephemeral business state in mutable widget properties.
- Invalidate or refresh providers predictably upon data mutations (e.g., after successful issue submission or status refresh).

## 3. Reporting Flow & UX Guarantees
- **Under 60 Seconds Submission (PRD §3, §23):** The photo capture to submission flow must be seamless with minimal form friction.
- **AI Recommendation Editability (PRD §7.3):** All AI-generated values (issue label, category, severity, department, description) **must remain editable** by the student prior to submission.
- **Offline / AI Failure Fallback (PRD §24):** If the AI classification request fails, times out (target <10s), or is offline, **never block the student from reporting**. Provide an immediate manual entry fallback.
- **Location Hierarchy (PRD §7.6):** Campus location selection must follow **Building → Floor → Area**. GPS coordinates are optional supplemental metadata, never the sole requirement.

## 4. Mobile Client Security Boundaries
- **NEVER EXPOSE PRIVATE SECRETS (PRD §20):**
  - **NEVER** embed the Gemini API key anywhere in the Flutter codebase or assets.
  - **NEVER** embed Supabase `service_role` keys or private admin credentials in client code.
  - Only public Supabase project URL and anonymous client key (`anon_key`) are permitted in client configurations (`.env` or compile-time environment variables).
  - All AI processing, duplicate detection, and elevated admin actions must be delegated to server-side Supabase Edge Functions.
- Sensitive authentication tokens must be securely persisted using platform-encrypted storage (e.g., `flutter_secure_storage`).
