'use client';

import React from 'react';
import { DashboardMetrics } from '@/types/database';
import { Clock, FolderPlus, Wrench, CheckCircle2, AlertTriangle, Layers } from 'lucide-react';

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
      id: 'ALL',
      title: 'Total Campus Issues',
      count: metrics.total,
      icon: Layers,
      color: 'text-slate-800',
      bgColor: 'bg-white',
      borderColor: 'border-slate-200',
      activeBorder: 'border-slate-800 ring-2 ring-slate-800/10',
      subtext: 'All recorded reports',
    },
    {
      id: 'REPORTED',
      title: 'Newly Reported',
      count: metrics.newReported,
      icon: Clock,
      color: 'text-amber-700',
      bgColor: 'bg-amber-50/50',
      borderColor: 'border-amber-200',
      activeBorder: 'border-amber-600 ring-2 ring-amber-600/20',
      subtext: 'Awaiting review / triage',
    },
    {
      id: 'ASSIGNED',
      title: 'Assigned to Dept',
      count: metrics.assigned,
      icon: FolderPlus,
      color: 'text-blue-700',
      bgColor: 'bg-blue-50/50',
      borderColor: 'border-blue-200',
      activeBorder: 'border-blue-600 ring-2 ring-blue-600/20',
      subtext: 'Department notified',
    },
    {
      id: 'IN_PROGRESS',
      title: 'In Progress',
      count: metrics.inProgress,
      icon: Wrench,
      color: 'text-purple-700',
      bgColor: 'bg-purple-50/50',
      borderColor: 'border-purple-200',
      activeBorder: 'border-purple-600 ring-2 ring-purple-600/20',
      subtext: 'Active repairs underway',
    },
    {
      id: 'RESOLVED',
      title: 'Resolved',
      count: metrics.resolved,
      icon: CheckCircle2,
      color: 'text-emerald-700',
      bgColor: 'bg-emerald-50/50',
      borderColor: 'border-emerald-200',
      activeBorder: 'border-emerald-600 ring-2 ring-emerald-600/20',
      subtext: 'Verified completions',
    },
    {
      id: 'CRITICAL',
      title: 'Active Critical',
      count: metrics.critical,
      icon: AlertTriangle,
      color: 'text-rose-700',
      bgColor: 'bg-rose-50/50',
      borderColor: 'border-rose-200',
      activeBorder: 'border-rose-600 ring-2 ring-rose-600/20',
      subtext: 'Urgent attention needed',
    },
  ];

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 sm:gap-4 mb-6">
      {cards.map((card) => {
        const Icon = card.icon;
        const isActive =
          card.id === 'ALL'
            ? selectedStatus === ''
            : card.id === 'CRITICAL'
            ? selectedStatus === 'CRITICAL'
            : selectedStatus === card.id;

        return (
          <button
            key={card.id}
            type="button"
            onClick={() => {
              if (card.id === 'ALL') {
                onSelectStatus('');
              } else {
                onSelectStatus(card.id);
              }
            }}
            className={`text-left p-4 rounded-2xl border transition-all duration-150 cursor-pointer ${
              card.bgColor
            } ${isActive ? card.activeBorder : `${card.borderColor} hover:shadow-sm`}`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
                {card.title}
              </span>
              <Icon className={`w-4 h-4 ${card.color}`} />
            </div>

            <div className="flex items-baseline gap-1">
              {isLoading ? (
                <div className="h-7 w-12 bg-slate-200 animate-pulse rounded my-0.5" />
              ) : (
                <span className={`text-2xl font-extrabold tracking-tight ${card.color}`}>
                  {card.count}
                </span>
              )}
            </div>

            <p className="text-[11px] text-slate-500 mt-1 truncate">{card.subtext}</p>
          </button>
        );
      })}
    </div>
  );
}
