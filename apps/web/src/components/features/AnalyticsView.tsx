'use client';

import React, { useMemo } from 'react';
import { ReportItem, Building, DashboardMetrics } from '@/types/database';
import {
  BarChart3,
  TrendingUp,
  Clock,
  Layers,
  Building2,
  Trash2,
  AlertTriangle,
  CheckCircle2,
} from 'lucide-react';

interface AnalyticsViewProps {
  reports: ReportItem[];
  buildings: Building[];
  metrics: DashboardMetrics;
}

export function AnalyticsView({ reports, buildings, metrics }: AnalyticsViewProps) {
  // Category Breakdown
  const categoryCounts = useMemo(() => {
    const counts: Record<string, number> = {
      waste: 0,
      water: 0,
      electricity: 0,
      infrastructure: 0,
      greenery: 0,
      cleanliness: 0,
      other: 0,
    };
    reports.forEach((r) => {
      if (!r.deleted_at && counts[r.category] !== undefined) {
        counts[r.category]++;
      }
    });
    return counts;
  }, [reports]);

  // Building Hotspots
  const buildingCounts = useMemo(() => {
    const counts: Record<string, { name: string; count: number }> = {};
    buildings.forEach((b) => {
      counts[b.id] = { name: b.name, count: 0 };
    });
    reports.forEach((r) => {
      if (!r.deleted_at && r.building_id && counts[r.building_id]) {
        counts[r.building_id].count++;
      }
    });
    return Object.values(counts).sort((a, b) => b.count - a.count);
  }, [reports, buildings]);

  // Severity Distribution
  const severityCounts = useMemo(() => {
    const counts = { low: 0, medium: 0, high: 0, critical: 0 };
    reports.forEach((r) => {
      if (!r.deleted_at && counts[r.severity] !== undefined) {
        counts[r.severity]++;
      }
    });
    return counts;
  }, [reports]);

  // Average Resolution Time Calculation (for resolved reports with updated_at / created_at)
  const avgResolutionHours = useMemo(() => {
    const resolved = reports.filter((r) => !r.deleted_at && r.status === 'RESOLVED');
    if (resolved.length === 0) return null;
    let totalMs = 0;
    resolved.forEach((r) => {
      const created = new Date(r.created_at).getTime();
      const updated = new Date(r.updated_at).getTime();
      if (updated > created) {
        totalMs += updated - created;
      }
    });
    const hours = Math.round(totalMs / (resolved.length * 1000 * 3600));
    return hours > 0 ? hours : 1;
  }, [reports]);

  const activeReportsCount = reports.filter((r) => !r.deleted_at).length;

  return (
    <div className="space-y-6 animate-in fade-in duration-150">
      {/* Top Analytics Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-2xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Total Active Reports
            </span>
            <Layers className="w-4 h-4 text-emerald-700" />
          </div>
          <div className="text-2xl font-black text-slate-900">{activeReportsCount}</div>
          <div className="text-xs text-slate-400 mt-1">Excludes administratively removed</div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-2xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Avg Resolution Time
            </span>
            <Clock className="w-4 h-4 text-blue-700" />
          </div>
          <div className="text-2xl font-black text-slate-900">
            {avgResolutionHours !== null ? `${avgResolutionHours}h` : 'N/A'}
          </div>
          <div className="text-xs text-slate-400 mt-1">From submission to verified completion</div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-2xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Resolution Rate
            </span>
            <CheckCircle2 className="w-4 h-4 text-emerald-700" />
          </div>
          <div className="text-2xl font-black text-slate-900">
            {activeReportsCount > 0
              ? `${Math.round((metrics.resolved / (activeReportsCount + metrics.resolved)) * 100)}%`
              : '0%'}
          </div>
          <div className="text-xs text-slate-400 mt-1">{metrics.resolved} issues resolved</div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200/90 shadow-2xs">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">
              Archived by Admin
            </span>
            <Trash2 className="w-4 h-4 text-slate-600" />
          </div>
          <div className="text-2xl font-black text-slate-900">{metrics.deleted}</div>
          <div className="text-xs text-slate-400 mt-1">Retained soft-deleted records</div>
        </div>
      </div>

      {/* Grid: Category Breakdown + Severity Distribution */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Category Breakdown */}
        <div className="bg-white rounded-2xl border border-slate-200/90 p-5 shadow-2xs">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-bold text-slate-900">Reports by Category</h2>
            <BarChart3 className="w-4 h-4 text-slate-400" />
          </div>

          <div className="space-y-3">
            {Object.entries(categoryCounts).map(([cat, count]) => {
              const pct = activeReportsCount > 0 ? Math.round((count / activeReportsCount) * 100) : 0;
              return (
                <div key={cat} className="space-y-1">
                  <div className="flex items-center justify-between text-xs font-medium">
                    <span className="capitalize text-slate-700">{cat}</span>
                    <span className="text-slate-400">
                      {count} ({pct}%)
                    </span>
                  </div>
                  <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden">
                    <div
                      style={{ width: `${pct}%` }}
                      className="h-full bg-emerald-600 rounded-full transition-all duration-300"
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Severity Distribution */}
        <div className="bg-white rounded-2xl border border-slate-200/90 p-5 shadow-2xs">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-bold text-slate-900">Reports by Severity</h2>
            <AlertTriangle className="w-4 h-4 text-slate-400" />
          </div>

          <div className="space-y-3">
            {[
              { label: 'Critical', count: severityCounts.critical, color: 'bg-rose-500' },
              { label: 'High', count: severityCounts.high, color: 'bg-orange-500' },
              { label: 'Medium', count: severityCounts.medium, color: 'bg-amber-500' },
              { label: 'Low', count: severityCounts.low, color: 'bg-slate-400' },
            ].map((item) => {
              const pct = activeReportsCount > 0 ? Math.round((item.count / activeReportsCount) * 100) : 0;
              return (
                <div key={item.label} className="space-y-1">
                  <div className="flex items-center justify-between text-xs font-medium">
                    <span className="text-slate-700">{item.label}</span>
                    <span className="text-slate-400">
                      {item.count} ({pct}%)
                    </span>
                  </div>
                  <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden">
                    <div
                      style={{ width: `${pct}%` }}
                      className={`h-full ${item.color} rounded-full transition-all duration-300`}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Building Hotspots Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-5 shadow-2xs">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-sm font-bold text-slate-900">Campus Building Hotspots</h2>
            <p className="text-xs text-slate-500">Distribution of reports across campus facilities</p>
          </div>
          <Building2 className="w-4 h-4 text-slate-400" />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {buildingCounts.map((b) => (
            <div
              key={b.name}
              className="p-3 bg-slate-50 rounded-xl border border-slate-200/60 flex items-center justify-between"
            >
              <div className="truncate pr-2">
                <span className="font-bold text-xs text-slate-800 truncate block">{b.name}</span>
                <span className="text-[11px] text-slate-400">SRM University Sonepat</span>
              </div>
              <span className="px-2.5 py-1 bg-white border border-slate-200 rounded-lg text-xs font-bold text-slate-800 shadow-2xs">
                {b.count}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
