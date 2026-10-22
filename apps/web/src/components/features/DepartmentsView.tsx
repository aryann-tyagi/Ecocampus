'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { Department, ReportItem, UserRole } from '@/types/database';
import { createClient } from '@/lib/supabase/client';
import {
  Building2,
  Plus,
  RotateCcw,
  CheckCircle2,
  XCircle,
  X,
  AlertCircle,
  Layers,
} from 'lucide-react';
import { formatDate } from '@/lib/utils';

interface DepartmentsViewProps {
  departments: Department[];
  reports: ReportItem[];
  userRole: UserRole;
  onRefresh: () => void;
}

export function DepartmentsView({
  departments,
  reports,
  userRole,
  onRefresh,
}: DepartmentsViewProps) {
  const supabase = createClient();
  const isAdmin = userRole === 'admin';

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [deptName, setDeptName] = useState('');
  const [deptSlug, setDeptSlug] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Compute active issue counts per department
  const activeReportCounts = React.useMemo(() => {
    const counts: Record<string, number> = {};
    reports.forEach((r) => {
      if (!r.deleted_at && r.status !== 'RESOLVED' && r.assigned_department_id) {
        counts[r.assigned_department_id] = (counts[r.assigned_department_id] || 0) + 1;
      }
    });
    return counts;
  }, [reports]);

  function handleNameChange(name: string) {
    setDeptName(name);
    // Auto-generate slug
    const generated = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '');
    setDeptSlug(generated);
  }

  async function handleCreateDepartment(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!deptName.trim() || !deptSlug.trim()) {
      setError('Department name and slug are required.');
      return;
    }

    setIsSubmitting(true);
    try {
      const { error: insertErr } = await supabase.from('departments').insert({
        name: deptName.trim(),
        slug: deptSlug.trim(),
        active: true,
      });

      if (insertErr) throw insertErr;

      setIsModalOpen(false);
      setDeptName('');
      setDeptSlug('');
      onRefresh();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create department.');
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleToggleActive(dept: Department) {
    if (!isAdmin) return;
    try {
      const { error: updateErr } = await supabase
        .from('departments')
        .update({ active: !dept.active })
        .eq('id', dept.id);

      if (updateErr) throw updateErr;
      onRefresh();
    } catch (err) {
      console.error('Failed to toggle department:', err);
    }
  }

  return (
    <div className="space-y-4 animate-in fade-in duration-150">
      {/* Header Bar */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-4 shadow-2xs flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
        <div>
          <h2 className="text-sm font-bold text-slate-900">Campus Departments</h2>
          <p className="text-xs text-slate-500">
            Authoritative service teams handling triage and campus remediation
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={onRefresh}
            className="p-2.5 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl text-slate-600 shadow-2xs transition cursor-pointer"
            title="Refresh departments"
          >
            <RotateCcw className="w-4 h-4" />
          </button>

          {isAdmin && (
            <button
              type="button"
              onClick={() => setIsModalOpen(true)}
              className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-bold text-white bg-[#144D37] hover:bg-[#0f3a29] rounded-xl shadow-xs transition cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              <span>Add Department</span>
            </button>
          )}
        </div>
      </div>

      {/* Department Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {departments.map((dept) => {
          const activeCount = activeReportCounts[dept.id] || 0;
          return (
            <div
              key={dept.id}
              className="bg-white rounded-2xl border border-slate-200/90 p-4 shadow-2xs space-y-3"
            >
              <div className="flex items-start justify-between gap-2">
                <div className="flex items-center gap-2.5">
                  <div className="w-9 h-9 rounded-xl bg-emerald-50 border border-emerald-200/70 flex items-center justify-center text-emerald-700">
                    <Building2 className="w-4.5 h-4.5" />
                  </div>
                  <div>
                    <h3 className="font-bold text-slate-900 text-xs sm:text-sm">{dept.name}</h3>
                    <p className="text-[10px] text-slate-400 font-mono">slug: {dept.slug}</p>
                  </div>
                </div>

                <span
                  className={`inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full ${
                    dept.active
                      ? 'bg-emerald-100/70 text-emerald-800'
                      : 'bg-slate-100 text-slate-500'
                  }`}
                >
                  {dept.active ? (
                    <>
                      <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                      Active
                    </>
                  ) : (
                    <>
                      <XCircle className="w-3 h-3 text-slate-400" />
                      Inactive
                    </>
                  )}
                </span>
              </div>

              <div className="flex items-center justify-between text-xs pt-2 border-t border-slate-100">
                <div className="flex items-center gap-1.5 text-slate-500">
                  <Layers className="w-3.5 h-3.5 text-slate-400" />
                  <span>
                    <strong className="text-slate-800 font-bold">{activeCount}</strong> active issues
                  </span>
                </div>

                {isAdmin && (
                  <button
                    type="button"
                    onClick={() => handleToggleActive(dept)}
                    className="text-[11px] font-semibold text-slate-500 hover:text-slate-900 underline cursor-pointer"
                  >
                    {dept.active ? 'Deactivate' : 'Activate'}
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Add Department Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-md w-full p-6 shadow-2xl border border-slate-200 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h3 className="font-bold text-slate-900 text-sm">Add Campus Department</h3>
                <p className="text-xs text-slate-400">Create a department for issue routing</p>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-700"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {error && (
              <div className="p-3 bg-rose-50 border border-rose-200 text-rose-800 rounded-xl text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
                <span>{error}</span>
              </div>
            )}

            <form onSubmit={handleCreateDepartment} className="space-y-3.5 text-xs">
              <div>
                <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Department Name *
                </label>
                <input
                  type="text"
                  required
                  value={deptName}
                  onChange={(e) => handleNameChange(e.target.value)}
                  placeholder="e.g. Energy Management & Solar Grid"
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:outline-none focus:bg-white"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
                  URL / System Slug *
                </label>
                <input
                  type="text"
                  required
                  value={deptSlug}
                  onChange={(e) => setDeptSlug(e.target.value)}
                  placeholder="e.g. energy-solar-grid"
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-mono text-[11px] focus:outline-none focus:bg-white"
                />
              </div>

              <div className="pt-2 flex justify-end gap-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-3.5 py-1.5 text-slate-600 hover:bg-slate-100 rounded-xl font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-4 py-1.5 bg-[#144D37] text-white font-bold rounded-xl shadow-sm hover:bg-[#0f3a29] transition disabled:opacity-60 cursor-pointer"
                >
                  {isSubmitting ? 'Saving...' : 'Add Department'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
