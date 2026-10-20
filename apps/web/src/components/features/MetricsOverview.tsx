'use client';

import React from 'react';
import { DashboardMetrics } from '@/types/database';
import {
  Clock,
  FolderPlus,
  Wrench,
  CheckCircle2,
  AlertTriangle,
  Layers,
  Trash2,
} from 'lucide-react';

interface MetricsOverviewProps {
  metrics: DashboardMetrics;
  selectedStatus: string;
  onSelectStatus: (status: string) => void;
  isLoading?: boolean;
}

export function MetricsOverview({
  metrics,
  selectedStatus,
  onSelectStatus,
  isLoading = false,
}: MetricsOverviewProps) {
  const cards = [
    {
      id: '',
      title: 'Active Reports',
      count: metrics.total,
      icon: Layers,
      color: 'text-slate-800',
      bgColor: 'bg-white',
      borderColor: 'border-slate-200/80',
      activeBorder: 'border-[#144D37] ring-2 ring-[#144D37]/15 shadow-sm',
      subtext: 'Current non-deleted queue',
    },
    {
      id: 'REPORTED',
      title: 'Newly Reported',
      count: metrics.newReported,
      icon: Clock,
      color: 'text-amber-800',
      bgColor: 'bg-amber-50/40',
      borderColor: 'border-amber-200/70',
      activeBorder: 'border-amber-600 ring-2 ring-amber-600/20 shadow-sm',
      subtext: 'Awaiting review / triage',
    },
    {
      id: 'ASSIGNED',
      title: 'Assigned to Dept',
      count: metrics.assigned,
      icon: FolderPlus,
      color: 'text-blue-800',
      bgColor: 'bg-blue-50/40',
      borderColor: 'border-blue-200/70',
      activeBorder: 'border-blue-600 ring-2 ring-blue-600/20 shadow-sm',
      subtext: 'Department notified',
    },
    {
      id: 'IN_PROGRESS',
      title: 'In Progress',
      count: metrics.inProgress,
      icon: Wrench,
      color: 'text-purple-800',
      bgColor: 'bg-purple-50/40',
      borderColor: 'border-purple-200/70',
      activeBorder: 'border-purple-600 ring-2 ring-purple-600/20 shadow-sm',
      subtext: 'Technicians on site',
    },
    {
      id: 'RESOLVED',
      title: 'Resolved',
      count: metrics.resolved,
      icon: CheckCircle2,
      color: 'text-emerald-800',
      bgColor: 'bg-emerald-50/40',
      borderColor: 'border-emerald-200/70',
      activeBorder: 'border-emerald-600 ring-2 ring-emerald-600/20 shadow-sm',
      subtext: 'Verified completions',
    },
    {
      id: 'CRITICAL',
      title: 'Active Critical',
      count: metrics.critical,
      icon: AlertTriangle,
      color: 'text-rose-800',
      bgColor: 'bg-rose-50/40',
      borderColor: 'border-rose-200/70',
      activeBorder: 'border-rose-600 ring-2 ring-rose-600/20 shadow-sm',
      subtext: 'Urgent attention needed',
    },
    {
      id: 'REMOVED',
      title: 'Removed by Admin',
      count: metrics.deleted,
      icon: Trash2,
      color: 'text-slate-700',
      bgColor: 'bg-slate-100/60',
      borderColor: 'border-slate-200',
      activeBorder: 'border-slate-700 ring-2 ring-slate-700/20 shadow-sm',
      subtext: 'Archived with student reason',
    },
  ];

  // Distribution calculation
  const totalReportsWithDeleted =
    metrics.newReported +
    metrics.assigned +
    metrics.inProgress +
    metrics.resolved +
    metrics.deleted;

  const pct = (val: number) =>
    totalReportsWithDeleted > 0
      ? Math.round((val / totalReportsWithDeleted) * 100)
      : 0;

  const distributionSegments = [
    {
      id: 'REPORTED',
      label: 'Reported',
      count: metrics.newReported,
      pct: pct(metrics.newReported),
      bgClass: 'bg-amber-500',
      textClass: 'text-amber-800',
    },
    {
      id: 'ASSIGNED',
      label: 'Assigned',
      count: metrics.assigned,
      pct: pct(metrics.assigned),
      bgClass: 'bg-blue-500',
      textClass: 'text-blue-800',
    },
    {
      id: 'IN_PROGRESS',
      label: 'In Progress',
      count: metrics.inProgress,
      pct: pct(metrics.inProgress),
      bgClass: 'bg-purple-500',
      textClass: 'text-purple-800',
    },
    {
      id: 'RESOLVED',
      label: 'Resolved',
      count: metrics.resolved,
      pct: pct(metrics.resolved),
      bgClass: 'bg-emerald-600',
      textClass: 'text-emerald-800',
    },
    {
      id: 'REMOVED',
      label: 'Removed',
      count: metrics.deleted,
      pct: pct(metrics.deleted),
      bgClass: 'bg-slate-400',
      textClass: 'text-slate-700',
    },
  ];

  return (
    <div className="space-y-3.5 mb-6">
      {/* Metric Cards Grid */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-7 gap-3">
        {cards.map((card) => {
          const Icon = card.icon;
          const isActive = selectedStatus === card.id;

          return (
            <button
              key={card.id || 'all-active'}
              type="button"
              onClick={() => onSelectStatus(card.id)}
              className={`text-left p-3.5 rounded-2xl border transition-all duration-150 cursor-pointer ${
                card.bgColor
              } ${isActive ? card.activeBorder : `${card.borderColor} hover:border-slate-300 hover:shadow-xs`}`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[11px] font-bold text-slate-600 uppercase tracking-wider truncate">
                  {card.title}
                </span>
                <Icon className={`w-3.5 h-3.5 shrink-0 ${card.color}`} />
              </div>

              <div className="flex items-baseline gap-1">
                {isLoading ? (
                  <div className="h-7 w-12 bg-slate-200 animate-pulse rounded my-0.5" />
                ) : (
                  <span className={`text-2xl font-black tracking-tight ${card.color}`}>
                    {card.count}
                  </span>
                )}
              </div>

              <p className="text-[11px] text-slate-500 mt-1 truncate font-medium">
                {card.subtext}
              </p>
            </button>
          );
        })}
      </div>

      {/* Compact Status Distribution Visualizer */}
      <div className="bg-white rounded-2xl border border-slate-200/80 p-3 sm:p-4 shadow-xs">
        <div className="flex items-center justify-between mb-2 text-xs">
          <div className="flex items-center gap-2">
            <span className="font-bold text-slate-800 uppercase tracking-wider text-[11px]">
              Status Distribution
            </span>
            <span className="text-slate-400 text-[11px]">
              ({totalReportsWithDeleted} total recorded reports)
            </span>
          </div>
          {selectedStatus && (
            <button
              onClick={() => onSelectStatus('')}
              className="text-[11px] font-semibold text-[#144D37] hover:underline"
            >
              Reset filter
            </button>
          )}
        </div>

        {/* Visual Progress Bar */}
        <div className="h-2.5 w-full bg-slate-100 rounded-full overflow-hidden flex gap-0.5 p-0.5">
          {distributionSegments.map((seg) => {
            if (seg.pct <= 0) return null;
            return (
              <div
                key={seg.id}
                style={{ width: `${seg.pct}%` }}
                title={`${seg.label}: ${seg.count} (${seg.pct}%)`}
                onClick={() => onSelectStatus(seg.id)}
                className={`h-full ${seg.bgClass} rounded-xs transition-all hover:opacity-85 cursor-pointer`}
              />
            );
          })}
        </div>

        {/* Legend */}
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1.5 mt-2.5 pt-2 border-t border-slate-100 text-[11px]">
          {distributionSegments.map((seg) => {
            const isSegActive = selectedStatus === seg.id;
            return (
              <button
                key={seg.id}
                type="button"
                onClick={() => onSelectStatus(seg.id)}
                className={`inline-flex items-center gap-1.5 font-medium transition cursor-pointer ${
                  isSegActive
                    ? 'text-slate-900 font-bold underline'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <span className={`w-2 h-2 rounded-full ${seg.bgClass}`} />
                <span>{seg.label}</span>
                <span className="text-slate-400">({seg.count})</span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
