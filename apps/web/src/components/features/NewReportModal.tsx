'use client';

import React, { useState, useEffect } from 'react';
import { Department, Building, Floor, IssueCategory, IssueSeverity } from '@/types/database';
import { createClient } from '@/lib/supabase/client';
import { X, Plus, AlertCircle } from 'lucide-react';

interface NewReportModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  departments: Department[];
  buildings: Building[];
}

export function NewReportModal({
  isOpen,
  onClose,
  onSuccess,
  departments,
  buildings,
}: NewReportModalProps) {
  const supabase = createClient();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState<IssueCategory>('waste');
  const [severity, setSeverity] = useState<IssueSeverity>('medium');
  const [buildingId, setBuildingId] = useState(buildings[0]?.id || '');
  const [floors, setFloors] = useState<Floor[]>([]);
  const [floorId, setFloorId] = useState('');
  const [locationDetails, setLocationDetails] = useState('');
  const [assignedDepartmentId, setAssignedDepartmentId] = useState('');

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // When building changes, fetch floors for that building
  useEffect(() => {
    if (!buildingId) {
      setFloors([]);
      setFloorId('');
      return;
    }

    async function loadFloors() {
      const { data } = await supabase
        .from('floors')
        .select('*')
        .eq('building_id', buildingId)
        .eq('active', true)
        .order('sort_order', { ascending: true });

      if (data) {
        setFloors(data as Floor[]);
        if (data.length > 0) {
          setFloorId(data[0].id);
        } else {
          setFloorId('');
        }
      }
    }

    loadFloors();
  }, [buildingId, supabase]);

  if (!isOpen) return null;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (!title.trim()) {
      setError('Issue title is required.');
      return;
    }
    if (!buildingId) {
      setError('Please select a campus building.');
      return;
    }

    setIsSubmitting(true);

    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (!session?.user) {
        throw new Error('You must be logged in to create a report.');
      }

      const initialStatus = assignedDepartmentId ? 'ASSIGNED' : 'REPORTED';

      const insertPayload = {
        reporter_id: session.user.id,
        issue_label: title.trim(),
        description: description.trim() || 'Logged via Campus Operations Portal',
        category,
        severity,
        status: initialStatus,
        building_id: buildingId,
        floor_id: floorId || null,
        location_details: locationDetails.trim() || 'General building area',
        assigned_department_id: assignedDepartmentId || null,
      };

      const { data: newReport, error: insertError } = await supabase
        .from('reports')
        .insert(insertPayload)
        .select('id')
        .single();

      if (insertError) throw insertError;

      // Log initial status event
      if (newReport?.id) {
        await supabase.from('report_status_events').insert({
          report_id: newReport.id,
          from_status: null,
          to_status: initialStatus,
          actor_id: session.user.id,
          note: assignedDepartmentId
            ? 'Report logged and assigned by Campus Administrator'
            : 'Report logged by Campus Administrator',
        });
      }

      onSuccess();
      onClose();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create report.');
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs animate-in fade-in duration-150">
      <div className="bg-white rounded-3xl max-w-lg w-full p-6 shadow-2xl border border-slate-200 space-y-4 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between border-b border-slate-100 pb-3">
          <div>
            <h2 className="text-lg font-black text-slate-900 tracking-tight">Log Campus Report</h2>
            <p className="text-xs text-slate-500">
              Submit a verified environmental or maintenance issue to the active queue.
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {error && (
          <div className="p-3 bg-rose-50 border border-rose-200 text-rose-800 rounded-xl text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-3.5 text-xs">
          <div>
            <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
              Issue Title *
            </label>
            <input
              type="text"
              required
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Overflowing Outdoor Campus Trash Bin"
              className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#144D37]/20 focus:border-[#144D37]"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
                Category
              </label>
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value as IssueCategory)}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:bg-white focus:outline-none"
              >
                <option value="waste">Waste</option>
                <option value="water">Water</option>
                <option value="electricity">Energy</option>
                <option value="infrastructure">Infrastructure</option>
                <option value="greenery">Greenery</option>
                <option value="cleanliness">Cleanliness</option>
                <option value="other">Other</option>
              </select>
            </div>

            <div>
              <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
                Severity
              </label>
              <select
                value={severity}
                onChange={(e) => setSeverity(e.target.value as IssueSeverity)}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:bg-white focus:outline-none"
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
                <option value="critical">Critical</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
                Campus Building *
              </label>
              <select
                required
                value={buildingId}
                onChange={(e) => setBuildingId(e.target.value)}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:bg-white focus:outline-none"
              >
                <option value="">Select Building</option>
                {buildings.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
                Floor
              </label>
              <select
                value={floorId}
                onChange={(e) => setFloorId(e.target.value)}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:bg-white focus:outline-none"
              >
                <option value="">Ground / General</option>
                {floors.map((f) => (
                  <option key={f.id} value={f.id}>
                    {f.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
              Location Details / Room Number
            </label>
            <input
              type="text"
              value={locationDetails}
              onChange={(e) => setLocationDetails(e.target.value)}
              placeholder="e.g. Fourth Floor - Room 222 or North Courtyard"
              className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:bg-white focus:outline-none"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
              Assign to Department (Optional)
            </label>
            <select
              value={assignedDepartmentId}
              onChange={(e) => setAssignedDepartmentId(e.target.value)}
              className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:bg-white focus:outline-none"
            >
              <option value="">Unassigned (Awaiting Triage)</option>
              {departments.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
              Description
            </label>
            <textarea
              rows={2}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Contextual details regarding the environmental issue..."
              className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:bg-white focus:outline-none resize-none"
            />
          </div>

          <div className="pt-2 flex items-center justify-end gap-2 border-t border-slate-100">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 text-slate-600 hover:bg-slate-100 rounded-xl font-semibold transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-5 py-2 bg-[#144D37] hover:bg-[#0f3a29] text-white font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 disabled:opacity-60 cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              <span>{isSubmitting ? 'Submitting...' : 'Create Issue'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
