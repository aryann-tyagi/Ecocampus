# 💻 EcoCampus Web Administration Dashboard

The operations and department management web console for the **EcoCampus** platform, built with **Next.js 16 (App Router)**, **TypeScript**, and **Tailwind CSS**.

---

## 🌟 Key Features

- **Operational KPI Overview:** Live metrics tracking total, open, in-progress, and resolved issues, as well as EcoPoints awarded and average resolution time.
- **Issue Triage Queue:** Filter, search, and sort reports by status, category, severity, department, and submission date.
- **Issue Detail & Department Assignment:** Update lifecycle status (`REPORTED` $\rightarrow$ `ASSIGNED` $\rightarrow$ `IN_PROGRESS` $\rightarrow$ `RESOLVED`), assign departments, add internal maintenance notes, view photos via signed URLs, and link duplicate issues.
- **Soft Deletion Modal:** Safely mark reports as soft-deleted with an audit trail without compromising historical data integrity.
- **Challenge Management:** Create and schedule campus-wide sustainability challenges with point rewards.
- **Notice Management:** Publish and manage urgent sustainability alerts and announcements for the student mobile app.
- **Role-Based Authentication:** Protected routes for Administrators and Department Staff via Supabase Auth.

---

## 🛠️ Tech Stack

- **Framework:** Next.js 16 (React 19, Turbopack)
- **Styling:** Tailwind CSS v4
- **Icons:** `lucide-react`
- **Backend Integration:** `@supabase/ssr`, `@supabase/supabase-js`
- **Language:** TypeScript 5

---

## 🚀 Getting Started

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Environment Variables
Create `.env.local` in this directory:
```env
NEXT_PUBLIC_SUPABASE_URL=https://<your-project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<your-anon-key>
```

### 3. Run Development Server
```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to access the console.

---

## 🧪 Testing & Linting

```bash
# Run unit and integration tests
npm test

# Run ESLint
npm run lint
```
