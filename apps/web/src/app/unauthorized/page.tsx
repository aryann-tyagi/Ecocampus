'use client';

import React from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { ShieldAlert, ArrowLeft, LogOut } from 'lucide-react';

export default function UnauthorizedPage() {
  const router = useRouter();
  const supabase = createClient();

  async function handleSignOut() {
    await supabase.auth.signOut();
    router.push('/login');
  }

  return (
    <div className="min-h-screen bg-[#F8FAF8] flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-3xl p-8 border border-slate-200/80 shadow-lg text-center space-y-6">
        <div className="w-16 h-16 bg-rose-50 border border-rose-200 text-rose-600 rounded-2xl mx-auto flex items-center justify-center">
          <ShieldAlert className="w-8 h-8" />
        </div>

        <div className="space-y-2">
          <h1 className="text-xl font-bold text-slate-900">Access Restricted</h1>
          <p className="text-xs text-slate-600 leading-relaxed">
            This dashboard is reserved for authorized SRM University campus staff and administrators.
            Your authenticated account does not have staff or administrator privileges.
          </p>
        </div>

        <div className="p-4 bg-slate-50 border border-slate-200/60 rounded-2xl text-left text-xs text-slate-600 space-y-1">
          <p className="font-semibold text-slate-800">What you can do:</p>
          <ul className="list-disc list-inside space-y-0.5 text-slate-500">
            <li>Use the EcoCampus mobile app to submit and track your reports.</li>
            <li>If you are campus staff, request administrative role provisioning.</li>
            <li>Sign in with an authorized campus staff or admin account.</li>
          </ul>
        </div>

        <div className="flex flex-col sm:flex-row gap-3 pt-2">
          <button
            onClick={handleSignOut}
            className="flex-1 py-2.5 px-4 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold rounded-xl transition flex items-center justify-center gap-1.5"
          >
            <LogOut className="w-4 h-4" />
            Sign Out
          </button>
          <button
            onClick={() => router.push('/login')}
            className="flex-1 py-2.5 px-4 bg-[#144D37] hover:bg-[#0f3a29] text-white text-xs font-bold rounded-xl transition flex items-center justify-center gap-1.5"
          >
            <ArrowLeft className="w-4 h-4" />
            Switch Account
          </button>
        </div>
      </div>
    </div>
  );
}
