'use client';

import React from 'react';
import { DashboardMetrics } from '@/types/database';
import {
  Clock,
  Users,
  Wrench,
  CheckCircle2,
  AlertTriangle,
  FileText,
  Trash2,
  PieChart,
  BarChart2,
} from 'lucide-react';

interface MetricsOverviewProps {
  metrics: DashboardMetrics;
  selectedStatus: string;
  onSelectStatus: (status: string) => void;
  onViewAnalytics?: () => void;
  isLoading?: boolean;
}

export function MetricsOverview({
  metrics,
  selectedStatus,
  onSelectStatus,
  onViewAnalytics,
  isLoading = false,
}: MetricsOverviewProps) {
  const cards = [
    {
      id: '',
      label: 'Active Reports',
      count: metrics.total,
      icon: FileText,
      iconBg: 'bg-emerald-50 text-emerald-700 border-emerald-200/60',
      waveColor: '#10B981',
      trend: '+12%',
      trendUp: true,
      subtext: 'Current non-deleted queue',
      cardBorder: selectedStatus === '' ? 'ring-2 ring-emerald-600/30 border-emerald-600' : 'border-slate-200/80',
    },
    {
      id: 'REPORTED',
      label: 'Newly Reported',
      count: metrics.newReported,
      icon: Clock,
      iconBg: 'bg-amber-50 text-amber-700 border-amber-200/60',
      waveColor: '#F59E0B',
      trend: '+50%',
      trendUp: true,
      subtext: 'Awaiting review / triage',
      cardBorder: selectedStatus === 'REPORTED' ? 'ring-2 ring-amber-500/30 border-amber-500' : 'border-slate-200/80',
    },
    {
      id: 'ASSIGNED',
      label: 'Assigned to Dept',
      count: metrics.assigned,
      icon: Users,
      iconBg: 'bg-blue-50 text-blue-700 border-blue-200/60',
      waveColor: '#3B82F6',
      trend: '0%',
      trendNeutral: true,
      subtext: 'Department notified',
      cardBorder: selectedStatus === 'ASSIGNED' ? 'ring-2 ring-blue-500/30 border-blue-500' : 'border-slate-200/80',
    },
    {
      id: 'IN_PROGRESS',
      label: 'In Progress',
      count: metrics.inProgress,
      icon: Wrench,
      iconBg: 'bg-purple-50 text-purple-700 border-purple-200/60',
      waveColor: '#8B5CF6',
      trend: '0%',
      trendNeutral: true,
      subtext: 'Technicians on site',
      cardBorder: selectedStatus === 'IN_PROGRESS' ? 'ring-2 ring-purple-500/30 border-purple-500' : 'border-slate-200/80',
    },
    {
      id: 'RESOLVED',
      label: 'Resolved',
      count: metrics.resolved,
      icon: CheckCircle2,
      iconBg: 'bg-emerald-50 text-emerald-700 border-emerald-200/60',
      waveColor: '#059669',
      trend: '+100%',
      trendUp: true,
      subtext: 'Verified completions',
      cardBorder: selectedStatus === 'RESOLVED' ? 'ring-2 ring-emerald-600/30 border-emerald-600' : 'border-slate-200/80',
    },
    {
      id: 'CRITICAL',
      label: 'Active Critical',
      count: metrics.critical,
      icon: AlertTriangle,
      iconBg: 'bg-rose-50 text-rose-700 border-rose-200/60',
      waveColor: '#F43F5E',
      trend: '0%',
      trendNeutral: true,
      subtext: 'Urgent attention needed',
      cardBorder: selectedStatus === 'CRITICAL' ? 'ring-2 ring-rose-500/30 border-rose-500' : 'border-slate-200/80',
    },
    {
      id: 'REMOVED',
      label: 'Removed by Admin',
      count: metrics.deleted,
      icon: Trash2,
      iconBg: 'bg-slate-100 text-slate-700 border-slate-200',
      waveColor: '#64748B',
      trend: '0%',
      trendNeutral: true,
      subtext: 'Archived with student record',
      cardBorder: selectedStatus === 'REMOVED' ? 'ring-2 ring-slate-500/30 border-slate-500' : 'border-slate-200/80',
    },
  ];

  // Distribution calculation
  const totalRecorded =
    metrics.newReported +
    metrics.assigned +
    metrics.inProgress +
    metrics.resolved +
    metrics.deleted;

  const pct = (val: number) =>
    totalRecorded > 0 ? Math.round((val / totalRecorded) * 100) : 0;

  const segments = [
    { id: 'REPORTED', label: 'Reported', count: metrics.newReported, pct: pct(metrics.newReported), color: 'bg-amber-400' },
    { id: 'ASSIGNED', label: 'Assigned', count: metrics.assigned, pct: pct(metrics.assigned), color: 'bg-blue-500' },
    { id: 'IN_PROGRESS', label: 'In Progress', count: metrics.inProgress, pct: pct(metrics.inProgress), color: 'bg-purple-500' },
    { id: 'RESOLVED', label: 'Resolved', count: metrics.resolved, pct: pct(metrics.resolved), color: 'bg-emerald-500' },
    { id: 'REMOVED', label: 'Removed', count: metrics.deleted, pct: pct(metrics.deleted), color: 'bg-slate-400' },
  ];

  return (
    <div className="space-y-4 mb-6">
      {/* 7 Summary Statistic Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-3">
        {cards.map((card) => {
          const Icon = card.icon;
          const isSelected = selectedStatus === card.id;

          return (
            <button
              key={card.id || 'all-active'}
              type="button"
              onClick={() => onSelectStatus(card.id)}
              className={`relative overflow-hidden bg-white text-left p-3.5 rounded-2xl border transition-all duration-150 cursor-pointer shadow-2xs hover:shadow-sm ${card.cardBorder}`}
            >
              {/* Top Row: Icon + Label */}
              <div className="flex items-center gap-2 mb-2">
                <div className={`w-7 h-7 rounded-lg border flex items-center justify-center shrink-0 ${card.iconBg}`}>
                  <Icon className="w-3.5 h-3.5" />
                </div>
                <span className="text-[11px] font-bold text-slate-700 truncate tracking-tight">
                  {card.label}
                </span>
              </div>

              {/* Middle Row: Big Number + Trend Badge */}
              <div className="flex items-baseline justify-between gap-1 mb-1 relative z-10">
                {isLoading ? (
                  <div className="h-7 w-10 bg-slate-200 animate-pulse rounded my-0.5" />
                ) : (
                  <span className="text-2xl font-black text-slate-900 tracking-tight">
                    {card.count}
                  </span>
                )}

                <span
                  className={`text-[10px] font-bold px-1.5 py-0.5 rounded-full inline-flex items-center ${
                    card.trendUp
                      ? 'bg-emerald-100/70 text-emerald-800'
                      : 'bg-slate-100 text-slate-500'
                  }`}
                >
                  {card.trendUp ? `↑ ${card.trend}` : `→ ${card.trend}`}
                </span>
              </div>

              {/* Subtitle */}
              <p className="text-[10px] text-slate-400 font-medium truncate relative z-10">
                {card.subtext}
              </p>

              {/* Decorative Subtle Wavy Curve at Bottom matching Screenshot */}
              <div className="absolute bottom-0 left-0 right-0 h-6 pointer-events-none opacity-20 overflow-hidden">
                <svg
                  className="w-full h-full"
                  viewBox="0 0 100 24"
                  preserveAspectRatio="none"
                >
                  <path
                    d="M0,14 C25,24 45,5 70,16 C85,22 95,12 100,14 L100,24 L0,24 Z"
                    fill={card.waveColor}
                  />
                </svg>
              </div>
            </button>
          );
        })}
      </div>

      {/* Status Distribution Panel */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-4 shadow-2xs">
        {/* Top Header Row */}
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded-lg bg-emerald-50 text-emerald-700 flex items-center justify-center">
              <PieChart className="w-3.5 h-3.5" />
            </div>
            <div className="flex items-baseline gap-1.5">
              <span className="font-bold text-slate-900 text-xs sm:text-sm">
                Status Distribution
              </span>
              <span className="text-[11px] text-slate-400 font-medium">
                ({totalRecorded} total recorded reports)
              </span>
            </div>
          </div>

          <button
            type="button"
            onClick={onViewAnalytics}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-semibold shadow-2xs transition cursor-pointer"
          >
            <BarChart2 className="w-3.5 h-3.5 text-emerald-700" />
            <span>View Analytics</span>
          </button>
        </div>

        {/* Horizontal Segmented Progress Bar */}
        <div className="h-2.5 w-full bg-slate-100 rounded-full overflow-hidden flex gap-0.5 p-0.5">
          {segments.map((seg) => {
            if (seg.pct <= 0) return null;
            return (
              <div
                key={seg.id}
                style={{ width: `${seg.pct}%` }}
                title={`${seg.label}: ${seg.count} (${seg.pct}%)`}
                onClick={() => onSelectStatus(seg.id)}
                className={`h-full ${seg.color} rounded-xs transition-all hover:opacity-85 cursor-pointer`}
              />
            );
          })}
        </div>

        {/* Legend Row */}
        <div className="flex flex-wrap items-center gap-x-5 gap-y-1.5 mt-3 pt-2.5 border-t border-slate-100 text-xs">
          {segments.map((seg) => {
            const isSegActive = selectedStatus === seg.id;
            return (
              <button
                key={seg.id}
                type="button"
                onClick={() => onSelectStatus(isSegActive ? '' : seg.id)}
                className={`inline-flex items-center gap-1.5 font-medium transition cursor-pointer ${
                  isSegActive
                    ? 'text-slate-900 font-bold underline'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <span className={`w-2 h-2 rounded-full ${seg.color}`} />
                <span>{seg.label}</span>
                <span className="text-slate-400 text-[11px]">({seg.count})</span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
