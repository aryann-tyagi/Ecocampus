'use client';

import React, { useState } from 'react';
import { UserRole, Department } from '@/types/database';
import {
  Settings,
  ShieldCheck,
  Database,
  Globe,
  Bell,
  CheckCircle2,
  Lock,
  Server,
} from 'lucide-react';

interface SettingsViewProps {
  userEmail: string;
  userRole: UserRole;
  userDepartment?: Department | null;
}

export function SettingsView({ userEmail, userRole, userDepartment }: SettingsViewProps) {
  const [emailAlerts, setEmailAlerts] = useState(true);
  const [criticalPush, setCriticalPush] = useState(true);
  const [isSaved, setIsSaved] = useState(false);

  function handleSavePreferences(e: React.FormEvent) {
    e.preventDefault();
    setIsSaved(true);
    setTimeout(() => setIsSaved(false), 3000);
  }

  return (
    <div className="space-y-6 max-w-4xl animate-in fade-in duration-150">
      {/* Admin Identity Card */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-5 shadow-2xs">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-9 h-9 rounded-xl bg-emerald-50 border border-emerald-200/70 flex items-center justify-center text-emerald-700">
            <ShieldCheck className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-sm font-bold text-slate-900">Administrator Credentials</h2>
            <p className="text-xs text-slate-500">Authenticated Supabase Auth session</p>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
          <div className="p-3 bg-slate-50 rounded-xl border border-slate-200/60">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Campus Email
            </span>
            <span className="font-semibold text-slate-800">{userEmail}</span>
          </div>

          <div className="p-3 bg-slate-50 rounded-xl border border-slate-200/60">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Authority Level
            </span>
            <span className="font-semibold text-emerald-700 capitalize">
              {userRole === 'admin'
                ? 'Campus Administrator (Full Access)'
                : `Staff (${userDepartment?.name || 'Department Staff'})`}
            </span>
          </div>
        </div>
      </div>

      {/* Backend & Supabase Configuration */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-5 shadow-2xs">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-9 h-9 rounded-xl bg-blue-50 border border-blue-200/70 flex items-center justify-center text-blue-700">
            <Database className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-sm font-bold text-slate-900">Authoritative Database Engine</h2>
            <p className="text-xs text-slate-500">PostgreSQL connection & Supabase infrastructure</p>
          </div>
        </div>

        <div className="space-y-3 text-xs">
          <div className="flex items-center justify-between p-3 bg-slate-50 rounded-xl border border-slate-200/60">
            <div>
              <span className="font-bold text-slate-800 block">Supabase Project Reference</span>
              <span className="text-[11px] text-slate-400 font-mono">scwssqiocxotgmjgwqjg</span>
            </div>
            <span className="inline-flex items-center gap-1 text-[11px] font-bold text-emerald-800 bg-emerald-100/70 px-2 py-0.5 rounded-full">
              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
              Verified Active
            </span>
          </div>

          <div className="flex items-center justify-between p-3 bg-slate-50 rounded-xl border border-slate-200/60">
            <div>
              <span className="font-bold text-slate-800 block">Row Level Security (RLS)</span>
              <span className="text-[11px] text-slate-400">Strictly enforced on public tables</span>
            </div>
            <span className="inline-flex items-center gap-1 text-[11px] font-bold text-emerald-800 bg-emerald-100/70 px-2 py-0.5 rounded-full">
              <Lock className="w-3.5 h-3.5 text-emerald-600" />
              Enforced
            </span>
          </div>
        </div>
      </div>

      {/* Campus Operational Environment */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-5 shadow-2xs">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-9 h-9 rounded-xl bg-purple-50 border border-purple-200/70 flex items-center justify-center text-purple-700">
            <Globe className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-sm font-bold text-slate-900">Campus Environment Defaults</h2>
            <p className="text-xs text-slate-500">Regional and operational parameters</p>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs">
          <div className="p-3 bg-slate-50 rounded-xl border border-slate-200/60">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Institution
            </span>
            <span className="font-semibold text-slate-800">SRM University Sonepat</span>
          </div>

          <div className="p-3 bg-slate-50 rounded-xl border border-slate-200/60">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Timezone
            </span>
            <span className="font-semibold text-slate-800">Asia/Kolkata (IST, UTC+05:30)</span>
          </div>

          <div className="p-3 bg-slate-50 rounded-xl border border-slate-200/60">
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              Portal Release
            </span>
            <span className="font-semibold text-slate-800">EcoCampus Web v1.0.0</span>
          </div>
        </div>
      </div>
    </div>
  );
}
