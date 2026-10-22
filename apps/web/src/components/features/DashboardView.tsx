'use client';

import React from 'react';
import { DashboardMetrics, ReportItem, Department } from '@/types/database';
import {
  AlertTriangle,
  CheckCircle2,
  Clock,
  ArrowRight,
  TrendingUp,
  Leaf,
  Layers,
  Megaphone,
  BarChart3,
  Building2,
} from 'lucide-react';
import { resolveReportTitle, formatRelativeTime } from '@/lib/utils';
import { CategoryBadge, SeverityBadge } from '@/components/ui/Badge';

interface DashboardViewProps {
  metrics: DashboardMetrics;
  reports: ReportItem[];
  departments: Department[];
  onNavigateToIssues: (statusFilter?: string) => void;
  onNavigateToNotices: () => void;
  onNavigateToAnalytics: () => void;
}

export function DashboardView({
  metrics,
  reports,
  departments,
  onNavigateToIssues,
  onNavigateToNotices,
  onNavigateToAnalytics,
}: DashboardViewProps) {
  // Urgent reports needing triage or critical severity
  const urgentReports = reports
    .filter((r) => !r.deleted_at && (r.severity === 'critical' || r.status === 'REPORTED'))
    .slice(0, 5);

  // Recently resolved reports
  const resolvedReports = reports
    .filter((r) => !r.deleted_at && r.status === 'RESOLVED')
    .slice(0, 4);

  const resolutionRate =
    metrics.total + metrics.resolved > 0
      ? Math.round((metrics.resolved / (metrics.total + metrics.resolved)) * 100)
      : 0;

  return (
    <div className="space-y-6 animate-in fade-in duration-150">
      {/* Top Operational Metrics */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* KPI 1: Active Queue */}
        <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-2xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Active Queue
            </span>
            <div className="w-7 h-7 rounded-lg bg-emerald-50 text-emerald-700 flex items-center justify-center">
              <Layers className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-slate-900 tracking-tight">{metrics.total}</div>
          <div className="text-xs text-slate-400 mt-1 flex items-center gap-1">
            <Clock className="w-3.5 h-3.5 text-amber-500" />
            <span>{metrics.newReported} awaiting initial triage</span>
          </div>
        </div>

        {/* KPI 2: Critical Items */}
        <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-2xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Urgent Attention
            </span>
            <div className="w-7 h-7 rounded-lg bg-rose-50 text-rose-700 flex items-center justify-center">
              <AlertTriangle className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-slate-900 tracking-tight">{metrics.critical}</div>
          <div className="text-xs text-slate-400 mt-1 flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-rose-500" />
            <span>Active critical-severity items</span>
          </div>
        </div>

        {/* KPI 3: Resolution Rate */}
        <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-2xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Resolution Rate
            </span>
            <div className="w-7 h-7 rounded-lg bg-blue-50 text-blue-700 flex items-center justify-center">
              <TrendingUp className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-slate-900 tracking-tight">{resolutionRate}%</div>
          <div className="text-xs text-slate-400 mt-1 flex items-center gap-1">
            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
            <span>{metrics.resolved} verified completions</span>
          </div>
        </div>

        {/* KPI 4: Campus Sustainability Impact */}
        <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-2xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Campus Impact
            </span>
            <div className="w-7 h-7 rounded-lg bg-emerald-50 text-emerald-700 flex items-center justify-center">
              <Leaf className="w-4 h-4" />
            </div>
          </div>
          <div className="text-2xl font-black text-slate-900 tracking-tight">Active</div>
          <div className="text-xs text-slate-400 mt-1">
            Modeled projections for energy, water & waste
          </div>
        </div>
      </div>

      {/* Main Split: Urgent Reports + Quick Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Urgent Attention Queue */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-slate-200/90 p-5 shadow-2xs">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-sm font-bold text-slate-900">Priority Triage Queue</h2>
              <p className="text-xs text-slate-500">Unresolved reports requiring administrative attention</p>
            </div>
            <button
              onClick={() => onNavigateToIssues('')}
              className="text-xs font-bold text-emerald-700 hover:text-emerald-900 flex items-center gap-1"
            >
              <span>View All Issues</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {urgentReports.length === 0 ? (
            <div className="p-8 text-center text-xs text-slate-400">
              No urgent issues currently pending triage.
            </div>
          ) : (
            <div className="divide-y divide-slate-100">
              {urgentReports.map((report) => (
                <div
                  key={report.id}
                  onClick={() => onNavigateToIssues(report.severity === 'critical' ? 'CRITICAL' : 'REPORTED')}
                  className="py-3 flex items-center justify-between gap-3 hover:bg-slate-50 rounded-xl px-2 transition cursor-pointer"
                >
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-bold text-xs text-slate-900 truncate">
                        {resolveReportTitle(report)}
                      </span>
                      <SeverityBadge severity={report.severity} />
                      <CategoryBadge category={report.category} />
                    </div>
                    <div className="text-[11px] text-slate-500 flex items-center gap-2">
                      <span>{report.buildings?.name || 'Campus Building'}</span>
                      <span>·</span>
                      <span>{formatRelativeTime(report.created_at)}</span>
                    </div>
                  </div>

                  <span className="text-xs text-emerald-700 font-bold flex items-center gap-0.5 shrink-0">
                    Review
                    <ArrowRight className="w-3 h-3" />
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Right 1 Col: Operational Actions & Departments */}
        <div className="space-y-6">
          {/* Quick Shortcuts */}
          <div className="bg-white rounded-2xl border border-slate-200/90 p-5 shadow-2xs">
            <h2 className="text-sm font-bold text-slate-900 mb-3">Operational Shortcuts</h2>
            <div className="space-y-2">
              <button
                type="button"
                onClick={() => onNavigateToIssues('REPORTED')}
                className="w-full text-left p-3 rounded-xl border border-slate-200 hover:border-emerald-600 hover:bg-emerald-50/40 transition flex items-center justify-between text-xs font-semibold text-slate-800 cursor-pointer"
              >
                <div className="flex items-center gap-2.5">
                  <Clock className="w-4 h-4 text-amber-600" />
                  <span>Review Newly Reported ({metrics.newReported})</span>
                </div>
                <ArrowRight className="w-3.5 h-3.5 text-slate-400" />
              </button>

              <button
                type="button"
                onClick={onNavigateToNotices}
                className="w-full text-left p-3 rounded-xl border border-slate-200 hover:border-emerald-600 hover:bg-emerald-50/40 transition flex items-center justify-between text-xs font-semibold text-slate-800 cursor-pointer"
              >
                <div className="flex items-center gap-2.5">
                  <Megaphone className="w-4 h-4 text-blue-600" />
                  <span>Broadcast Campus Notice</span>
                </div>
                <ArrowRight className="w-3.5 h-3.5 text-slate-400" />
              </button>

              <button
                type="button"
                onClick={onNavigateToAnalytics}
                className="w-full text-left p-3 rounded-xl border border-slate-200 hover:border-emerald-600 hover:bg-emerald-50/40 transition flex items-center justify-between text-xs font-semibold text-slate-800 cursor-pointer"
              >
                <div className="flex items-center gap-2.5">
                  <BarChart3 className="w-4 h-4 text-purple-600" />
                  <span>Campus Analytics & Trends</span>
                </div>
                <ArrowRight className="w-3.5 h-3.5 text-slate-400" />
              </button>
            </div>
          </div>

          {/* Department Readiness */}
          <div className="bg-white rounded-2xl border border-slate-200/90 p-5 shadow-2xs">
            <h2 className="text-sm font-bold text-slate-900 mb-2">Campus Departments</h2>
            <p className="text-xs text-slate-400 mb-3">Active service teams handling issues</p>
            <div className="space-y-1.5 max-h-48 overflow-y-auto">
              {departments.slice(0, 6).map((dept) => (
                <div
                  key={dept.id}
                  className="flex items-center justify-between py-1.5 px-2 text-xs text-slate-700 bg-slate-50 rounded-lg"
                >
                  <div className="flex items-center gap-2 truncate">
                    <Building2 className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <span className="truncate">{dept.name}</span>
                  </div>
                  <span className="text-[10px] font-bold text-emerald-700 bg-emerald-100/60 px-1.5 py-0.5 rounded">
                    Active
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
