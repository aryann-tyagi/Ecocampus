'use client';

import React, { useState } from 'react';
import { ReportItem } from '@/types/database';
import { createClient } from '@/lib/supabase/client';
import { resolveReportTitle } from '@/lib/utils';
import {
  AlertTriangle,
  X,
  Trash2,
  CheckCircle2,
  ShieldAlert,
} from 'lucide-react';

interface DeleteReportModalProps {
  report: ReportItem;
  isOpen: boolean;
  onClose: () => void;
  onSuccess: (reportId: string, reason: string) => void;
}

const PRESET_REASONS = [
  { id: 'duplicate', label: 'Duplicate report', description: 'This incident was already reported elsewhere on campus.' },
  { id: 'invalid', label: 'Invalid report', description: 'The issue cannot be verified or does not exist at this location.' },
  { id: 'inappropriate', label: 'Inappropriate content', description: 'The report contains prohibited, offensive, or irrelevant content.' },
  { id: 'other', label: 'Other reason', description: 'Provide a custom explanation for removing this report.' },
];

export function DeleteReportModal({
  report,
  isOpen,
  onClose,
  onSuccess,
}: DeleteReportModalProps) {
  const supabase = createClient();
  const [selectedPreset, setSelectedPreset] = useState<string>('duplicate');
  const [customExplanation, setCustomExplanation] = useState<string>('');
  const [isDeleting, setIsDeleting] = useState<boolean>(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  if (!isOpen) return null;

  const reportTitle = resolveReportTitle(report);
  const buildingName = report.buildings?.name ?? 'Campus Building';
  const locationDetails = report.location_details || 'General campus location';

  async function handleConfirmDelete() {
    if (isDeleting) return;

    let finalReason = '';
    const presetObj = PRESET_REASONS.find((p) => p.id === selectedPreset);

    if (selectedPreset === 'other') {
      if (!customExplanation.trim()) {
        setErrorMessage('Please provide an explanation for the deletion reason.');
        return;
      }
      finalReason = customExplanation.trim();
    } else {
      if (customExplanation.trim()) {
        finalReason = `${presetObj?.label ?? 'Removed'}: ${customExplanation.trim()}`;
      } else {
        finalReason = presetObj?.label ?? 'Removed by administrator';
      }
    }

    setIsDeleting(true);
    setErrorMessage(null);

    try {
      // Execute atomic server-side soft-deletion RPC
      const { data, error } = await supabase.rpc('soft_delete_report', {
        p_report_id: report.id,
        p_reason: finalReason,
      });

      if (error) {
        setErrorMessage(error.message || 'Failed to soft delete report.');
        setIsDeleting(false);
        return;
      }

      onSuccess(report.id, finalReason);
      onClose();
    } catch (err: unknown) {
      setErrorMessage(
        err instanceof Error ? err.message : 'An unexpected error occurred while deleting the report.'
      );
      setIsDeleting(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-3 sm:p-6 animate-in fade-in duration-150">
      <div className="bg-white rounded-3xl max-w-xl w-full shadow-2xl border border-slate-200 overflow-hidden">
        {/* Header with restrained warning treatment */}
        <div className="p-5 sm:p-6 border-b border-rose-100 bg-rose-50/60 flex items-start justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-rose-100 text-rose-700 flex items-center justify-center shrink-0 border border-rose-200">
              <Trash2 className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-slate-900">
                Remove Report from Campus Queue
              </h2>
              <p className="text-xs text-slate-500 mt-0.5">
                Soft-delete report record and inform student
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            disabled={isDeleting}
            className="text-slate-400 hover:text-slate-600 p-1.5 rounded-full hover:bg-slate-200/60 transition disabled:opacity-50"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="p-5 sm:p-6 space-y-5">
          {/* Identified Report Card */}
          <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200 space-y-1.5">
            <div className="flex items-center justify-between text-xs">
              <span className="font-mono text-slate-400 font-semibold">#{report.id.slice(0, 8)}</span>
              <span className="text-slate-500">{buildingName}</span>
            </div>
            <h3 className="text-sm font-bold text-slate-900 line-clamp-1">
              {reportTitle}
            </h3>
            <p className="text-xs text-slate-500 line-clamp-2">
              {report.description || locationDetails}
            </p>
          </div>

          {/* Critical Soft-Deletion Notice */}
          <div className="p-3.5 bg-amber-50/70 border border-amber-200/80 rounded-2xl text-xs text-amber-900 flex items-start gap-2.5">
            <ShieldAlert className="w-4 h-4 text-amber-700 shrink-0 mt-0.5" />
            <div className="space-y-1">
              <span className="font-bold">Soft-Deletion Policy</span>
              <p className="text-amber-800 leading-relaxed text-[11px]">
                This will remove the issue from the public campus feed, building statistics, and active technician queues.
                The record is preserved for audits, and the student will see this explanation in their report history.
              </p>
            </div>
          </div>

          {/* Reason Selection */}
          <div className="space-y-2">
            <label className="text-xs font-bold text-slate-700 uppercase tracking-wider block">
              Reason for Removal <span className="text-rose-600">*</span>
            </label>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {PRESET_REASONS.map((preset) => (
                <button
                  key={preset.id}
                  type="button"
                  onClick={() => setSelectedPreset(preset.id)}
                  className={`text-left p-3 rounded-xl border text-xs transition cursor-pointer ${
                    selectedPreset === preset.id
                      ? 'border-[#144D37] bg-emerald-50/40 text-slate-900 ring-1 ring-[#144D37]'
                      : 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span className="font-bold">{preset.label}</span>
                    {selectedPreset === preset.id && (
                      <CheckCircle2 className="w-3.5 h-3.5 text-[#144D37]" />
                    )}
                  </div>
                  <p className="text-[11px] text-slate-500 mt-1 leading-snug">
                    {preset.description}
                  </p>
                </button>
              ))}
            </div>
          </div>

          {/* Explanation Textarea */}
          <div className="space-y-1.5">
            <label className="text-xs font-bold text-slate-700 uppercase tracking-wider block">
              Student-Facing Note {selectedPreset === 'other' ? '(Required)' : '(Optional context)'}
            </label>
            <textarea
              value={customExplanation}
              onChange={(e) => setCustomExplanation(e.target.value)}
              placeholder={
                selectedPreset === 'other'
                  ? 'Please describe why this report is being removed...'
                  : 'Add additional details for the student (e.g. Duplicate of issue #4f2a; already addressed by plumbing team)...'
              }
              rows={3}
              className="w-full p-3 text-xs bg-white border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-[#144D37] text-slate-800"
            />
          </div>

          {errorMessage && (
            <div className="p-3 bg-rose-50 border border-rose-200 text-rose-800 rounded-xl text-xs flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-rose-600 shrink-0" />
              <span>{errorMessage}</span>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="p-4 sm:p-5 border-t border-slate-100 bg-slate-50/80 flex items-center justify-end gap-3">
          <button
            type="button"
            onClick={onClose}
            disabled={isDeleting}
            className="px-4 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-200/60 rounded-xl transition"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleConfirmDelete}
            disabled={isDeleting}
            className="px-5 py-2.5 bg-rose-700 hover:bg-rose-800 text-white text-xs font-bold rounded-xl shadow-xs transition flex items-center gap-1.5 disabled:opacity-50"
          >
            {isDeleting ? (
              <>
                <div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                Removing Report...
              </>
            ) : (
              <>
                <Trash2 className="w-3.5 h-3.5" />
                Confirm Removal
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}
