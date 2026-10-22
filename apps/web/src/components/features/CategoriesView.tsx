'use client';

import React from 'react';
import { IssueCategory, ReportItem } from '@/types/database';
import {
  Trash,
  Droplets,
  Zap,
  Building,
  TreePine,
  Sparkles,
  HelpCircle,
  Layers,
  ArrowRight,
} from 'lucide-react';
import { CategoryBadge } from '@/components/ui/Badge';

interface CategoriesViewProps {
  reports: ReportItem[];
  onSelectCategoryFilter: (category: string) => void;
}

export function CategoriesView({ reports, onSelectCategoryFilter }: CategoriesViewProps) {
  const categoryDefs: {
    id: IssueCategory;
    name: string;
    description: string;
    icon: React.ComponentType<{ className?: string }>;
    defaultDept: string;
    bgColor: string;
  }[] = [
    {
      id: 'waste',
      name: 'Waste Management',
      description: 'Overflowing bins, improper dumping, recycling contamination, unsegregated garbage.',
      icon: Trash,
      defaultDept: 'Housekeeping & Waste Management',
      bgColor: 'bg-emerald-50 text-emerald-700',
    },
    {
      id: 'water',
      name: 'Water Systems & Conservation',
      description: 'Leaking taps, running restrooms, pipe bursts, standing water, drinking water issues.',
      icon: Droplets,
      defaultDept: 'Plumbing & Facilities',
      bgColor: 'bg-blue-50 text-blue-700',
    },
    {
      id: 'electricity',
      name: 'Electricity & Energy',
      description: 'Lights left on, faulty switches, AC cooling wastage, broken sensors, solar panel alerts.',
      icon: Zap,
      defaultDept: 'Electrical Maintenance',
      bgColor: 'bg-amber-50 text-amber-700',
    },
    {
      id: 'infrastructure',
      name: 'Estate & Infrastructure',
      description: 'Broken doors/windows, pathway damage, fence repairs, structural safety concerns.',
      icon: Building,
      defaultDept: 'Estate & Civil Infrastructure',
      bgColor: 'bg-orange-50 text-orange-700',
    },
    {
      id: 'greenery',
      name: 'Campus Greenery & Horticulture',
      description: 'Dry lawns, tree maintenance, irrigation needs, invasive weeds, botanical health.',
      icon: TreePine,
      defaultDept: 'Horticulture & Landscape',
      bgColor: 'bg-teal-50 text-teal-700',
    },
    {
      id: 'cleanliness',
      name: 'Sanitation & Hygiene',
      description: 'Restroom cleanliness, littering in common areas, corridor spills, sanitization.',
      icon: Sparkles,
      defaultDept: 'Sanitation & Hygiene',
      bgColor: 'bg-cyan-50 text-cyan-700',
    },
    {
      id: 'other',
      name: 'General Campus Quality',
      description: 'Miscellaneous campus environmental issues not falling under standard categories.',
      icon: HelpCircle,
      defaultDept: 'General Administration',
      bgColor: 'bg-slate-100 text-slate-700',
    },
  ];

  // Count active reports per category
  const activeCounts = React.useMemo(() => {
    const counts: Record<string, number> = {};
    reports.forEach((r) => {
      if (!r.deleted_at && r.status !== 'RESOLVED') {
        counts[r.category] = (counts[r.category] || 0) + 1;
      }
    });
    return counts;
  }, [reports]);

  return (
    <div className="space-y-4 animate-in fade-in duration-150">
      <div className="bg-white rounded-2xl border border-slate-200/90 p-4 shadow-2xs">
        <h2 className="text-sm font-bold text-slate-900">Issue Category Taxonomies</h2>
        <p className="text-xs text-slate-500">
          The 7 approved PRD issue classification taxonomies used by students and AI triage
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {categoryDefs.map((cat) => {
          const Icon = cat.icon;
          const count = activeCounts[cat.id] || 0;

          return (
            <div
              key={cat.id}
              className="bg-white rounded-2xl border border-slate-200/90 p-4 shadow-2xs space-y-3 flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between mb-2">
                  <div className={`w-8 h-8 rounded-xl flex items-center justify-center ${cat.bgColor}`}>
                    <Icon className="w-4 h-4" />
                  </div>
                  <CategoryBadge category={cat.id} />
                </div>

                <h3 className="font-bold text-slate-900 text-sm mt-1">{cat.name}</h3>
                <p className="text-xs text-slate-500 mt-1 leading-relaxed">{cat.description}</p>
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-between text-xs">
                <div className="flex items-center gap-1.5 text-slate-500">
                  <Layers className="w-3.5 h-3.5 text-slate-400" />
                  <span>
                    <strong className="text-slate-800 font-bold">{count}</strong> active
                  </span>
                </div>

                <button
                  type="button"
                  onClick={() => onSelectCategoryFilter(cat.id)}
                  className="font-bold text-emerald-700 hover:text-emerald-900 inline-flex items-center gap-1 cursor-pointer"
                >
                  <span>Filter Queue</span>
                  <ArrowRight className="w-3 h-3" />
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
