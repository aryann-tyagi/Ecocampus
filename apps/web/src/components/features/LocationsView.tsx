'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { Building, Floor, ReportItem, UserRole } from '@/types/database';
import { createClient } from '@/lib/supabase/client';
import {
  MapPin,
  Building2,
  Plus,
  RotateCcw,
  Layers,
  ChevronDown,
  ChevronRight,
  X,
  AlertCircle,
} from 'lucide-react';

interface LocationsViewProps {
  buildings: Building[];
  reports: ReportItem[];
  userRole: UserRole;
  onRefresh: () => void;
}

export function LocationsView({ buildings, reports, userRole, onRefresh }: LocationsViewProps) {
  const supabase = createClient();
  const isAdmin = userRole === 'admin';

  const [expandedBuildingId, setExpandedBuildingId] = useState<string | null>(buildings[0]?.id || null);
  const [floorsMap, setFloorsMap] = useState<Record<string, Floor[]>>({});
  const [isLoadingFloors, setIsLoadingFloors] = useState(false);

  // New building modal
  const [isAddBuildingOpen, setIsAddBuildingOpen] = useState(false);
  const [newBldName, setNewBldName] = useState('');
  const [newBldZone, setNewBldZone] = useState('Academic Zone');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Load floors for all buildings
  const loadFloors = useCallback(async () => {
    setIsLoadingFloors(true);
    try {
      const { data } = await supabase
        .from('floors')
        .select('*')
        .eq('active', true)
        .order('sort_order', { ascending: true });

      if (data) {
        const grouped: Record<string, Floor[]> = {};
        (data as Floor[]).forEach((f) => {
          if (!grouped[f.building_id]) grouped[f.building_id] = [];
          grouped[f.building_id].push(f);
        });
        setFloorsMap(grouped);
      }
    } catch (e) {
      console.error('Failed to load floors:', e);
    } finally {
      setIsLoadingFloors(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadFloors();
  }, [loadFloors]);

  // Compute active issue counts per building
  const buildingIssueCounts = React.useMemo(() => {
    const counts: Record<string, number> = {};
    reports.forEach((r) => {
      if (!r.deleted_at && r.status !== 'RESOLVED' && r.building_id) {
        counts[r.building_id] = (counts[r.building_id] || 0) + 1;
      }
    });
    return counts;
  }, [reports]);

  async function handleCreateBuilding(e: React.FormEvent) {
    e.preventDefault();
    if (!newBldName.trim()) return;
    setIsSubmitting(true);
    setError(null);

    const slug = newBldName
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '');

    try {
      const { error: insertErr } = await supabase.from('buildings').insert({
        name: newBldName.trim(),
        slug,
        zone: newBldZone,
        active: true,
      });

      if (insertErr) throw insertErr;

      setIsAddBuildingOpen(false);
      setNewBldName('');
      onRefresh();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create building.');
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div className="space-y-4 animate-in fade-in duration-150">
      {/* Top Header */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-4 shadow-2xs flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
        <div>
          <h2 className="text-sm font-bold text-slate-900">Campus Facilities & Locations</h2>
          <p className="text-xs text-slate-500">
            SRM University Sonepat official buildings and verified floor levels
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => {
              loadFloors();
              onRefresh();
            }}
            className="p-2.5 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl text-slate-600 shadow-2xs transition cursor-pointer"
            title="Refresh locations"
          >
            <RotateCcw className="w-4 h-4" />
          </button>

          {isAdmin && (
            <button
              type="button"
              onClick={() => setIsAddBuildingOpen(true)}
              className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-bold text-white bg-[#144D37] hover:bg-[#0f3a29] rounded-xl shadow-xs transition cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              <span>Add Facility</span>
            </button>
          )}
        </div>
      </div>

      {/* Buildings List with Expandable Floors */}
      <div className="space-y-3">
        {buildings.map((b) => {
          const isExpanded = expandedBuildingId === b.id;
          const buildingFloors = floorsMap[b.id] || [];
          const activeCount = buildingIssueCounts[b.id] || 0;

          return (
            <div
              key={b.id}
              className="bg-white rounded-2xl border border-slate-200/90 shadow-2xs overflow-hidden"
            >
              <div
                onClick={() => setExpandedBuildingId(isExpanded ? null : b.id)}
                className="p-4 flex items-center justify-between hover:bg-slate-50/70 transition cursor-pointer select-none"
              >
                <div className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-xl bg-emerald-50 border border-emerald-200/70 flex items-center justify-center text-emerald-700">
                    <Building2 className="w-4.5 h-4.5" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <h3 className="font-bold text-slate-900 text-xs sm:text-sm">{b.name}</h3>
                      <span className="text-[10px] font-semibold text-slate-500 bg-slate-100 px-2 py-0.5 rounded-full">
                        {b.zone || 'Campus Zone'}
                      </span>
                    </div>
                    <p className="text-[11px] text-slate-400 mt-0.5">
                      {buildingFloors.length} registered floor levels
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <div className="flex items-center gap-1.5 text-xs text-slate-600 bg-slate-100/70 px-2.5 py-1 rounded-lg">
                    <Layers className="w-3.5 h-3.5 text-slate-400" />
                    <span>
                      <strong className="text-slate-800 font-bold">{activeCount}</strong> active
                    </span>
                  </div>

                  {isExpanded ? (
                    <ChevronDown className="w-4 h-4 text-slate-400" />
                  ) : (
                    <ChevronRight className="w-4 h-4 text-slate-400" />
                  )}
                </div>
              </div>

              {/* Expanded Floor Levels */}
              {isExpanded && (
                <div className="px-5 pb-4 pt-2 border-t border-slate-100 bg-slate-50/40">
                  <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-2">
                    Floor Levels
                  </div>
                  {buildingFloors.length === 0 ? (
                    <p className="text-xs text-slate-400 italic">No specific floors registered.</p>
                  ) : (
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                      {buildingFloors.map((f) => (
                        <div
                          key={f.id}
                          className="p-2.5 bg-white rounded-xl border border-slate-200 text-xs flex items-center gap-2"
                        >
                          <MapPin className="w-3.5 h-3.5 text-emerald-700" />
                          <span className="font-semibold text-slate-800">{f.label}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Add Building Modal */}
      {isAddBuildingOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-md w-full p-6 shadow-2xl border border-slate-200 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h3 className="font-bold text-slate-900 text-sm">Add Campus Facility</h3>
                <p className="text-xs text-slate-400">Register a new campus facility or block</p>
              </div>
              <button
                onClick={() => setIsAddBuildingOpen(false)}
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

            <form onSubmit={handleCreateBuilding} className="space-y-3.5 text-xs">
              <div>
                <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Building / Block Name *
                </label>
                <input
                  type="text"
                  required
                  value={newBldName}
                  onChange={(e) => setNewBldName(e.target.value)}
                  placeholder="e.g. Science & Innovation Tower"
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:bg-white focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Campus Zone
                </label>
                <select
                  value={newBldZone}
                  onChange={(e) => setNewBldZone(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:bg-white focus:outline-none"
                >
                  <option value="Academic Zone">Academic Zone</option>
                  <option value="Hostel & Residential">Hostel & Residential</option>
                  <option value="Sports & Recreational">Sports & Recreational</option>
                  <option value="Administrative Complex">Administrative Complex</option>
                </select>
              </div>

              <div className="pt-2 flex justify-end gap-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setIsAddBuildingOpen(false)}
                  className="px-3.5 py-1.5 text-slate-600 hover:bg-slate-100 rounded-xl font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-4 py-1.5 bg-[#144D37] text-white font-bold rounded-xl shadow-sm hover:bg-[#0f3a29] transition disabled:opacity-60 cursor-pointer"
                >
                  {isSubmitting ? 'Saving...' : 'Add Facility'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
