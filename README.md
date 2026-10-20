# 🌿 EcoCampus

> **AI-Powered Campus Sustainability & Issue Intelligence Platform**  
> *Report. Resolve. Improve.*

[![Flutter](https://img.shields.io/badge/Flutter-3.7+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Next.js](https://img.shields.io/badge/Next.js-16.4+-000000?logo=next.js&logoColor=white)](https://nextjs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL%20%7C%20Auth%20%7C%20Storage-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Google Gemini](https://img.shields.io/badge/Google%20Gemini-AI%20Intelligence-8E75B2?logo=google-gemini&logoColor=white)](https://deepmind.google/technologies/gemini/)
[![Firebase FCM](https://img.shields.io/badge/Firebase-FCM%20Notifications-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)

---

## 📌 Overview

**EcoCampus** is a full-stack sustainability and campus maintenance platform designed to streamline the lifecycle of campus infrastructure and environmental issues:

$$\text{OBSERVE} \longrightarrow \text{REPORT} \longrightarrow \text{UNDERSTAND} \longrightarrow \text{PRIORITIZE} \longrightarrow \text{RESOLVE} \longrightarrow \text{MEASURE} \longrightarrow \text{PREVENT}$$

The platform connects **students**, **department staff**, and **campus administrators** in a closed-loop system:
- **Students** capture and report sustainability issues (e.g., water leaks, overflowing bins, energy waste) via an intuitive mobile application with instant AI assistance and gamified EcoPoints.
- **Department Staff & Admins** triage, assign, and manage issues to resolution through a real-time web operations dashboard.
- **AI Intelligence** (powered by Google Gemini via secure server-side Edge Functions) automatically categorizes issues, estimates severity, identifies duplicates, and suggests appropriate maintenance departments.

---

## 🏗️ System Architecture & Monorepo Structure

```
eco-campus/
├── apps/
│   ├── mobile/              # Flutter mobile app (iOS & Android)
│   │   ├── lib/
│   │   │   ├── core/        # Theme, network, storage, constants
│   │   │   └── features/    # Feature modules: auth, home, report, tracking,
│   │   │                    # map, rewards, notices, notifications, profile
│   │   ├── assets/          # Sprig mascot, foliage, illustrations, icons
│   │   └── test/            # Comprehensive unit and widget test suite
│   │
│   └── web/                 # Next.js 16 (App Router) + TypeScript + Tailwind CSS
│       ├── src/
│       │   ├── app/         # Admin routes: / (dashboard), /login, /unauthorized
│       │   ├── components/  # MetricsOverview, IssueQueue, IssueDetailModal,
│       │   │                # NoticeManagement, ChallengeManagement
│       │   ├── lib/         # Supabase client/server utilities, helper functions
│       │   └── types/       # Shared database and domain TypeScript definitions
│       └── test/            # Web test suite (Node test runner + tsx)
│
├── supabase/
│   ├── functions/           # Deno Edge Functions
│   │   ├── analyze-report/  # Server-side Gemini AI multimodal classification
│   │   ├── find-duplicates/ # Intelligent proximity & text similarity detection
│   │   └── send-fcm-notification/ # Push notifications to mobile devices
│   └── migrations/          # Versioned PostgreSQL schema, RLS policies & RPCs
│
├── docs/                    # Architectural specifications and control docs
│   ├── 00-control/          # Requirements traceability & governance
│   ├── 01-product/          # Product definitions & taxonomy
│   ├── 02-design/           # Design systems & UI contracts
│   ├── 03-engineering/      # Architecture, security & data flow
│   ├── 04-intelligence/     # Gemini AI prompts & scoring models
│   └── 05-delivery/         # Test plans & deployment guides
│
└── reference/               # PRD and core reference documentation
```

---

## ✨ Key Features

### 📱 Student Mobile Application (`apps/mobile`)
- **Frictionless Reporting:** Snap a photo or select from gallery; automatically captures GPS location and snaps to recognized campus buildings.
- **AI-Assisted Issue Tagging:** Server-side Gemini analysis suggests the title, category, severity, and department, allowing manual user refinement.
- **Nearby Issues Feed:** Live campus feed displaying active sustainability concerns with real-time signed thumbnail rendering.
- **Issue Tracking & Timeline:** Real-time progress updates across the lifecycle: `REPORTED` $\rightarrow$ `ASSIGNED` $\rightarrow$ `IN_PROGRESS` $\rightarrow$ `RESOLVED`.
- **Interactive Campus Map:** 2D SVG campus map showing issue hotspots and building sustainability eco-scores.
- **Gamification & Rewards:** Earn EcoPoints for validated reports; complete daily and weekly sustainability challenges; earn badges.
- **Notices & Alerts:** View campus-wide sustainability announcements and maintenance alerts.
- **Privacy First:** Reporter identity is masked on public campus feeds (DEC-006) with strict Row Level Security.

### 💻 Operations & Admin Dashboard (`apps/web`)
- **Real-Time KPI Metrics:** Live tracking of total reports, pending issues, resolution rates, EcoPoints issued, and average resolution times.
- **Triage & Issue Queue:** Powerful filtering by status, category, severity, department, date, and keyword search.
- **Department Routing:** Assign reports to specific teams (Plumbing, Electrical, Sanitation, Grounds, Infrastructure).
- **Issue Resolution & Soft Deletion:** Update lifecycle states, attach internal resolution notes, link duplicate reports, or soft-delete invalid submissions.
- **Challenge & Notice Management:** Create and schedule campus-wide challenges and broadcast notices with customizable point awards.
- **Role-Based Access Control (RBAC):** Dedicated access tiers for Students, Staff, and Administrators.

### 🧠 Backend & AI Intelligence (`supabase/`)
- **Secure Multimodal AI:** Gemini API integration executed exclusively within Supabase Edge Functions—API keys are never exposed to clients.
- **Taxonomy Validation:** Strict enforcement of domain enums:
  - **Categories:** `waste`, `water`, `electricity`, `infrastructure`, `greenery`, `cleanliness`, `other`
  - **Severities:** `low`, `medium`, `high`, `critical`
  - **Statuses:** `REPORTED`, `ASSIGNED`, `IN_PROGRESS`, `RESOLVED`, `REJECTED`, `DUPLICATE`
- **Private Media Storage:** `report-photos` storage bucket is strictly private (`public = false`), protected by Row Level Security and served through temporary signed URLs.
- **Real-time Push Notifications:** Triggered via Firebase Cloud Messaging (FCM) on status transitions.

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed:
- [Git](https://git-scm.com/)
- [Node.js](https://nodejs.org/) (v20+ recommended)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.7+)
- [Supabase CLI](https://supabase.com/docs/guides/cli)

---

### 1. Database & Backend Setup (Supabase)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/aryann-tyagi/Ecocampus.git
   cd Ecocampus
   ```

2. **Link or start Supabase:**
   ```bash
   # For local development
   npx supabase start

   # Or link to an existing Supabase cloud project
   npx supabase link --project-ref <your-project-ref>
   ```

3. **Apply Database Migrations:**
   ```bash
   npx supabase db push
   ```

4. **Set Edge Function Secrets:**
   ```bash
   npx supabase secrets set GEMINI_API_KEY=your_gemini_api_key
   npx supabase secrets set FIREBASE_SERVICE_ACCOUNT=your_service_account_json
   ```

5. **Deploy Edge Functions:**
   ```bash
   npx supabase functions deploy analyze-report
   npx supabase functions deploy find-duplicates
   npx supabase functions deploy send-fcm-notification
   ```

---

### 2. Mobile App Setup (`apps/mobile`)

1. **Navigate to the mobile directory:**
   ```bash
   cd apps/mobile
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables:**
   Create or verify `lib/core/constants/supabase_constants.dart` (or your local environment configuration) with your project URL and anonymous key:
   ```dart
   const String supabaseUrl = 'https://<your-project-ref>.supabase.co';
   const String supabaseAnonKey = '<your-anon-key>';
   ```

4. **Run the mobile app:**
   ```bash
   # Connect an Android/iOS device or launch an emulator, then:
   flutter run
   ```

---

### 3. Web Admin Dashboard Setup (`apps/web`)

1. **Navigate to the web directory:**
   ```bash
   cd apps/web
   ```

2. **Install Node dependencies:**
   ```bash
   npm install
   ```

3. **Configure Environment Variables:**
   Create a `.env.local` file in `apps/web/`:
   ```env
   NEXT_PUBLIC_SUPABASE_URL=https://<your-project-ref>.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=<your-anon-key>
   ```

4. **Start the development server:**
   ```bash
   npm run dev
   ```
   Open [http://localhost:3000](http://localhost:3000) to view the admin console.

---

## 🧪 Testing & Verification

Run the test suites across each platform to verify system integrity:

### Mobile Tests (Flutter)
```bash
cd apps/mobile
flutter test        # Runs all unit, widget, and mock integration tests
flutter analyze     # Runs static code analysis
```

### Web Tests (Next.js / Node)
```bash
cd apps/web
npm test            # Runs TypeScript test runner
npm run lint        # Verifies code styles and ESLint rules
```

---

## 🔒 Security & Data Governance

- **Zero Client-Side AI Keys:** The Google Gemini API key resides strictly inside Supabase Secrets and is invoked only through authenticated Edge Functions.
- **Row Level Security (RLS):** 
  - Students can read and insert their own reports and view anonymized campus feeds.
  - Staff and Administrators hold elevated capabilities enforced through server-side functions and cryptographic JWT tokens.
- **Private Storage:** Report photos are stored in a non-public bucket. Access requires valid user session authentication and is served via time-delimited signed URLs.
- **Reporter Anonymity:** Public campus issue feeds omit `reporter_id` and personally identifiable information to safeguard user privacy.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
