'use client';

import React, { useState, useEffect } from 'react';
import {
  ReportItem,
  Department,
  ReportStatus,
  UserRole,
  ReportStatusEvent,
} from '@/types/database';
import { CategoryBadge, SeverityBadge, StatusBadge } from '@/components/ui/Badge';
import { formatDate, resolveReportTitle } from '@/lib/utils';
import { createClient } from '@/lib/supabase/client';
import {
  X,
  MapPin,
  Building2,
  Calendar,
  CheckCircle2,
  AlertTriangle,
  Wrench,
  Image as ImageIcon,
  History,
  Layers,
  ArrowRight,
  MessageSquare,
  Sparkles,
} from 'lucide-react';

interface IssueDetailModalProps {
  report: ReportItem;
  departments: Department[];
  userRole: UserRole;
  userDepartmentId?: string | null;
  onClose: () => void;
  onReportUpdated: (updatedReportId: string) => void;
}

export function IssueDetailModal({
  report,
  departments,
  userRole,
  userDepartmentId,
  onClose,
  onReportUpdated,
}: IssueDetailModalProps) {
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const [isLoadingPhoto, setIsLoadingPhoto] = useState(false);
  const [timelineEvents, setTimelineEvents] = useState<ReportStatusEvent[]>([]);
  const [isLoadingTimeline, setIsLoadingTimeline] = useState(false);

  // Assignment state
  const [selectedDeptId, setSelectedDeptId] = useState(report.assigned_department_id || '');
  const [isAssigning, setIsAssigning] = useState(false);
  const [assignmentError, setAssignmentError] = useState<string | null>(null);

  // Status transition state
  const [isTransitioning, setIsTransitioning] = useState(false);
  const [transitionError, setTransitionError] = useState<string | null>(null);
  const [resolutionNote, setResolutionNote] = useState('');
  const [showResolveDialog, setShowResolveDialog] = useState(false);
  const [generalError, setGeneralError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const supabase = createClient();
  const isAdmin = userRole === 'admin';
  const isStaff = userRole === 'staff';
  const isAssignedStaff =
    isStaff &&
    Boolean(userDepartmentId) &&
    report.assigned_department_id === userDepartmentId;

  // 1. Fetch authorized signed URL for photo preview
  useEffect(() => {
    let isCancelled = false;
    async function loadPhoto() {
      const mediaList = report.report_media;
      if (!mediaList || mediaList.length === 0) return;

      const primaryMedia = mediaList[0];
      if (!primaryMedia?.storage_path) return;

      setIsLoadingPhoto(true);
      try {
        const { data } = await supabase.storage
          .from('report-photos')
          .createSignedUrl(primaryMedia.storage_path, 3600);

        if (!isCancelled && data?.signedUrl) {
          setPhotoUrl(data.signedUrl);
        }
      } catch (err) {
        console.error('Failed to load signed photo url:', err);
      } finally {
        if (!isCancelled) setIsLoadingPhoto(false);
      }
    }

    loadPhoto();
    return () => {
      isCancelled = true;
    };
  }, [report.id, report.report_media, supabase]);

  // 2. Fetch full chronological audit events
  useEffect(() => {
    let isCancelled = false;
    async function loadTimeline() {
      setIsLoadingTimeline(true);
      try {
        const { data } = await supabase
          .from('report_status_events')
          .select('*')
          .eq('report_id', report.id)
          .order('occurred_at', { ascending: true });

        if (!isCancelled && data) {
          setTimelineEvents(data as ReportStatusEvent[]);
        }
      } catch (err) {
        console.error('Failed to load status timeline:', err);
      } finally {
        if (!isCancelled) setIsLoadingTimeline(false);
      }
    }

    loadTimeline();
    return () => {
      isCancelled = true;
    };
  }, [report.id, supabase]);

  // Handle department assignment
  async function handleAssignDepartment() {
    if (!selectedDeptId || selectedDeptId === report.assigned_department_id) return;
    if (!isAdmin) {
      setAssignmentError('Only administrators can assign departments.');
      return;
    }

    setIsAssigning(true);
    setAssignmentError(null);
    setGeneralError(null);
    setSuccessMessage(null);

    try {
      const { error } = await supabase.rpc('assign_report_department', {
        p_report_id: report.id,
        p_department_id: selectedDeptId,
      });

      if (error) {
        setAssignmentError(error.message || 'Failed to assign department.');
        return;
      }

      setSuccessMessage('Department assigned successfully.');
      onReportUpdated(report.id);

      // Asynchronously trigger FCM push to report owner
      if (report.reporter_id) {
        const deptObj = departments.find((d) => d.id === selectedDeptId);
        supabase.functions
          .invoke('send-fcm-notification', {
            body: {
              userId: report.reporter_id,
              title: 'Report Assigned',
              body: `Your report has been assigned to ${deptObj?.name || 'a campus department'}.`,
              data: { report_id: report.id, event_type: 'report_assigned' },
            },
          })
          .catch((pushErr) => console.log('FCM dispatch notice:', pushErr));
      }
    } catch (err: unknown) {
      setAssignmentError(err instanceof Error ? err.message : 'Failed to assign department.');
    } finally {
      setIsAssigning(false);
    }
  }

  // Handle status transition execution
  async function handleTransition(newStatus: ReportStatus, noteText?: string) {
    if (isTransitioning) return;

    setIsTransitioning(true);
    setTransitionError(null);
    setGeneralError(null);
    setSuccessMessage(null);

    try {
      const { error } = await supabase.rpc('transition_report_status', {
        p_report_id: report.id,
        p_new_status: newStatus,
        p_note: noteText?.trim() || null,
        p_assigned_department_id: selectedDeptId || null,
      });

      if (error) {
        setTransitionError(error.message || 'Failed to transition issue status.');
        return;
      }

      setSuccessMessage(`Status updated to ${newStatus}.`);
      setShowResolveDialog(false);
      setResolutionNote('');
      onReportUpdated(report.id);

      // Asynchronously trigger FCM push to report owner
      if (report.reporter_id) {
        const titleMap: Record<ReportStatus, string> = {
          REPORTED: 'Report Updated',
          ASSIGNED: 'Report Assigned',
          IN_PROGRESS: 'Work In Progress 🔨',
          RESOLVED: 'Issue Resolved! 🎉',
        };
        const bodyMap: Record<ReportStatus, string> = {
          REPORTED: 'Your report is logged for review.',
          ASSIGNED: 'Your report has been assigned to a campus department.',
          IN_PROGRESS: 'Campus staff have begun work on your report.',
          RESOLVED: `Your report has been resolved.${noteText ? ` Note: ${noteText}` : ''}`,
        };

        supabase.functions
          .invoke('send-fcm-notification', {
            body: {
              userId: report.reporter_id,
              title: titleMap[newStatus] || 'Report Status Update',
              body: bodyMap[newStatus] || `Status updated to ${newStatus}`,
              data: { report_id: report.id, event_type: `report_${newStatus.toLowerCase()}` },
            },
          })
          .catch((pushErr) => console.log('FCM dispatch notice:', pushErr));
      }
    } catch (err: unknown) {
      setTransitionError(err instanceof Error ? err.message : 'Failed to transition issue status.');
    } finally {
      setIsTransitioning(false);
    }
  }

  const buildingName = report.buildings?.name ?? 'Campus Building';
  const floorDisplay = report.floors?.label ?? (report.floor_text ? `Floor ${report.floor_text}` : 'General Floor');
  const assignedDept = departments.find((d) => d.id === report.assigned_department_id);

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-3 sm:p-6 animate-in fade-in duration-200">
      <div className="bg-white rounded-3xl max-w-3xl w-full max-h-[92vh] flex flex-col shadow-2xl border border-slate-200 overflow-hidden">
        {/* Header */}
        <div className="p-5 sm:p-6 border-b border-slate-100 flex items-start justify-between bg-slate-50/70">
          <div>
            <div className="flex items-center gap-2 mb-1.5 flex-wrap">
              <StatusBadge status={report.status} />
              <SeverityBadge severity={report.severity} />
              <CategoryBadge category={report.category} />
              <span className="text-slate-400 text-xs font-mono">#{report.id.slice(0, 8)}</span>
            </div>
            <h2 className="text-lg sm:text-xl font-bold text-slate-900 leading-snug break-words">
              {resolveReportTitle(report)}
            </h2>
          </div>

          <button
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600 p-1.5 rounded-full hover:bg-slate-200/60 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <div className="flex-1 overflow-y-auto p-5 sm:p-6 space-y-6">
          {/* Notifications / Alerts */}
          {successMessage && (
            <div className="p-3.5 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-xl text-xs flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
              <span>{successMessage}</span>
            </div>
          )}

          {generalError && (
            <div className="p-3.5 bg-rose-50 border border-rose-200 text-rose-800 rounded-xl text-xs flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-rose-600 shrink-0" />
              <span>{generalError}</span>
            </div>
          )}

          {transitionError && (
            <div className="p-3.5 bg-rose-50 border border-rose-200 text-rose-800 rounded-xl text-xs flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-rose-600 shrink-0" />
              <span>{transitionError}</span>
            </div>
          )}

          {/* Section 1: Overview & Location Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Description & Metadata */}
            <div className="space-y-3">
              <div>
                <label className="text-xs font-bold text-slate-500 uppercase tracking-wider block mb-1">
                  Issue Description
                </label>
                <div className="p-3.5 bg-slate-50 rounded-xl text-slate-800 text-xs leading-relaxed border border-slate-100 whitespace-pre-wrap">
                  {report.description}
                </div>
              </div>

              {/* AI Suggestion tag if available */}
              {report.suggested_department_label && (
                <div className="p-3 bg-amber-50/60 border border-amber-200/60 rounded-xl text-xs flex items-start gap-2">
                  <Sparkles className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                  <div>
                    <span className="font-semibold text-amber-900">AI Suggested Department:</span>
                    <p className="text-amber-800 text-[11px] mt-0.5">
                      {report.suggested_department_label}
                    </p>
                  </div>
                </div>
              )}
            </div>

            {/* Location & Photo Box */}
            <div className="space-y-3">
              <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-100 space-y-2">
                <label className="text-xs font-bold text-slate-500 uppercase tracking-wider block mb-1">
                  Physical Campus Location
                </label>

                <div className="flex items-center gap-2 text-xs font-semibold text-slate-800">
                  <Building2 className="w-4 h-4 text-[#144D37]" />
                  <span>{buildingName}</span>
                </div>

                <div className="flex items-center gap-2 text-xs text-slate-600">
                  <Layers className="w-4 h-4 text-slate-400" />
                  <span>{floorDisplay}</span>
                </div>

                <div className="flex items-center gap-2 text-xs text-slate-600">
                  <MapPin className="w-4 h-4 text-slate-400" />
                  <span className="font-medium text-slate-900">
                    {report.location_details || 'No exact room specified'}
                  </span>
                </div>

                <div className="text-[11px] text-slate-400 pt-1 border-t border-slate-200/60 flex items-center gap-1.5">
                  <Calendar className="w-3.5 h-3.5" />
                  <span>Submitted {formatDate(report.created_at)}</span>
                </div>
              </div>

              {/* Photo preview */}
              <div>
                <label className="text-xs font-bold text-slate-500 uppercase tracking-wider block mb-1">
                  Attached Issue Photograph
                </label>
                {isLoadingPhoto ? (
                  <div className="h-40 bg-slate-100 rounded-xl flex items-center justify-center animate-pulse">
                    <span className="text-xs text-slate-400">Loading authorized photo...</span>
                  </div>
                ) : photoUrl ? (
                  <div className="relative rounded-xl overflow-hidden border border-slate-200 max-h-48 bg-slate-950 flex items-center justify-center">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={photoUrl}
                      alt={report.title}
                      className="max-h-48 w-full object-contain"
                    />
                  </div>
                ) : (
                  <div className="h-28 bg-slate-50 rounded-xl border border-slate-100 flex flex-col items-center justify-center text-slate-400 gap-1.5">
                    <ImageIcon className="w-6 h-6" />
                    <span className="text-xs">No photograph attached</span>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Section 2: Department Assignment Controls */}
          <div className="p-4 bg-emerald-50/40 rounded-2xl border border-emerald-100/80 space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-xs font-bold text-[#144D37] uppercase tracking-wider flex items-center gap-1.5">
                <Wrench className="w-4 h-4" />
                Responsible Campus Department
              </label>
              {assignedDept ? (
                <span className="text-xs font-semibold text-emerald-800 bg-emerald-100/70 px-2.5 py-0.5 rounded-full border border-emerald-200">
                  Assigned: {assignedDept.name}
                </span>
              ) : (
                <span className="text-xs font-semibold text-amber-700 bg-amber-100/60 px-2.5 py-0.5 rounded-full">
                  Unassigned
                </span>
              )}
            </div>

            {isAdmin ? (
              <div className="flex flex-col sm:flex-row gap-2 items-stretch sm:items-center">
                <select
                  value={selectedDeptId}
                  onChange={(e) => setSelectedDeptId(e.target.value)}
                  className="flex-1 px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs font-medium text-slate-800 focus:outline-none focus:ring-2 focus:ring-[#144D37]"
                >
                  <option value="">— Select Responsible Department —</option>
                  {departments.map((d) => (
                    <option key={d.id} value={d.id}>
                      {d.name}
                    </option>
                  ))}
                </select>

                <button
                  onClick={handleAssignDepartment}
                  disabled={!selectedDeptId || selectedDeptId === report.assigned_department_id || isAssigning}
                  className="px-4 py-2 bg-[#144D37] hover:bg-[#0f3a29] text-white text-xs font-bold rounded-xl transition disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-1.5 shrink-0"
                >
                  {isAssigning ? 'Assigning...' : 'Save Assignment'}
                </button>
              </div>
            ) : (
              <p className="text-xs text-slate-600">
                {assignedDept
                  ? `This issue is assigned to ${assignedDept.name}.`
                  : 'This report has not been assigned a department by campus administrators.'}
              </p>
            )}

            {assignmentError && (
              <p className="text-xs text-rose-600 font-medium">{assignmentError}</p>
            )}
          </div>

          {/* Section 3: Status Transition Workflow Controls */}
          <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200/80 space-y-3">
            <label className="text-xs font-bold text-slate-700 uppercase tracking-wider block">
              Workflow Status Actions
            </label>

            <div className="flex flex-wrap items-center gap-2.5">
              {/* If REPORTED: Admin can advance to ASSIGNED or IN_PROGRESS */}
              {report.status === 'REPORTED' && (
                <>
                  {isAdmin ? (
                    <>
                      <button
                        onClick={() => handleTransition('IN_PROGRESS', 'Admin initiated investigation and work.')}
                        disabled={isTransitioning}
                        className="px-4 py-2 bg-purple-700 hover:bg-purple-800 text-white text-xs font-bold rounded-xl transition flex items-center gap-1.5 shadow-xs disabled:opacity-50"
                      >
                        <Wrench className="w-3.5 h-3.5" />
                        Start Investigation (In Progress)
                      </button>
                    </>
                  ) : (
                    <span className="text-xs text-slate-500 italic">
                      Awaiting administrative triage and assignment.
                    </span>
                  )}
                </>
              )}

              {/* If ASSIGNED: Assigned Staff or Admin can start work */}
              {report.status === 'ASSIGNED' && (
                <>
                  {(isAdmin || isAssignedStaff) ? (
                    <button
                      onClick={() => handleTransition('IN_PROGRESS', 'Department technician initiated work on site.')}
                      disabled={isTransitioning}
                      className="px-4 py-2 bg-purple-700 hover:bg-purple-800 text-white text-xs font-bold rounded-xl transition flex items-center gap-1.5 shadow-xs disabled:opacity-50"
                    >
                      <Wrench className="w-3.5 h-3.5" />
                      Begin Work (In Progress)
                    </button>
                  ) : (
                    <span className="text-xs text-slate-500 italic">
                      Only assigned department staff ({assignedDept?.name ?? 'Assigned Dept'}) or administrators can begin work.
                    </span>
                  )}
                </>
              )}

              {/* If IN_PROGRESS: Assigned Staff or Admin can resolve */}
              {report.status === 'IN_PROGRESS' && (
                <>
                  {(isAdmin || isAssignedStaff) ? (
                    <button
                      onClick={() => setShowResolveDialog(true)}
                      disabled={isTransitioning}
                      className="px-4 py-2 bg-emerald-700 hover:bg-emerald-800 text-white text-xs font-bold rounded-xl transition flex items-center gap-1.5 shadow-xs disabled:opacity-50"
                    >
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      Mark Issue as Resolved
                    </button>
                  ) : (
                    <span className="text-xs text-slate-500 italic">
                      Active work underway by {assignedDept?.name ?? 'assigned department'}.
                    </span>
                  )}
                </>
              )}

              {/* If RESOLVED: Display completion badge */}
              {report.status === 'RESOLVED' && (
                <div className="flex items-center gap-2 text-emerald-800 text-xs font-semibold bg-emerald-50 px-3 py-1.5 rounded-xl border border-emerald-200">
                  <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                  <span>Issue has been successfully resolved and closed.</span>
                </div>
              )}
            </div>
          </div>

          {/* Resolve Prompt Dialog */}
          {showResolveDialog && (
            <div className="p-4 bg-emerald-50/80 rounded-2xl border border-emerald-200 space-y-3 animate-in fade-in duration-150">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-emerald-900 uppercase tracking-wide">
                  Resolution Note (Required)
                </span>
                <button
                  onClick={() => setShowResolveDialog(false)}
                  className="text-slate-400 hover:text-slate-600"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              <textarea
                value={resolutionNote}
                onChange={(e) => setResolutionNote(e.target.value)}
                placeholder="Explain the corrective actions taken (e.g. Replaced faulty washer, cleared bin overflow, tightened connection)..."
                rows={3}
                className="w-full p-2.5 text-xs bg-white border border-emerald-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-600"
              />

              <div className="flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setShowResolveDialog(false)}
                  className="px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-200/50 rounded-lg"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={() => handleTransition('RESOLVED', resolutionNote)}
                  disabled={!resolutionNote.trim() || isTransitioning}
                  className="px-4 py-1.5 bg-emerald-700 hover:bg-emerald-800 text-white text-xs font-bold rounded-lg transition disabled:opacity-40"
                >
                  {isTransitioning ? 'Resolving...' : 'Confirm & Close Issue'}
                </button>
              </div>
            </div>
          )}

          {/* Section 4: Chronological Audit Trail Timeline */}
          <div className="space-y-3 pt-2">
            <label className="text-xs font-bold text-slate-700 uppercase tracking-wider flex items-center gap-1.5">
              <History className="w-4 h-4 text-slate-400" />
              Status & Assignment History Timeline
            </label>

            {isLoadingTimeline ? (
              <div className="h-16 bg-slate-100 rounded-xl animate-pulse" />
            ) : timelineEvents.length === 0 ? (
              <p className="text-xs text-slate-400 italic">No historical events recorded.</p>
            ) : (
              <div className="relative pl-6 space-y-4 before:absolute before:left-2 before:top-2 before:bottom-2 before:w-0.5 before:bg-slate-200">
                {timelineEvents.map((ev, idx) => (
                  <div key={ev.id || idx} className="relative group text-xs">
                    {/* Timeline dot */}
                    <div className="absolute -left-6 top-1 w-2.5 h-2.5 rounded-full bg-[#144D37] border-2 border-white shadow-xs" />

                    <div className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                      <div className="flex items-center justify-between mb-1">
                        <div className="flex items-center gap-1.5 font-bold text-slate-800">
                          {ev.from_status ? (
                            <>
                              <span>{ev.from_status}</span>
                              <ArrowRight className="w-3 h-3 text-slate-400" />
                              <span className="text-[#144D37]">{ev.to_status}</span>
                            </>
                          ) : (
                            <span className="text-[#144D37]">{ev.to_status}</span>
                          )}
                        </div>

                        <span className="text-[11px] text-slate-400">
                          {formatDate(ev.occurred_at)}
                        </span>
                      </div>

                      {ev.note && (
                        <p className="text-slate-600 mt-1 text-[11px] flex items-start gap-1">
                          <MessageSquare className="w-3 h-3 text-slate-400 shrink-0 mt-0.5" />
                          <span>{ev.note}</span>
                        </p>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Modal Footer */}
        <div className="p-4 px-6 border-t border-slate-100 bg-slate-50 flex items-center justify-between">
          <span className="text-[11px] text-slate-400">
            EcoCampus Administrative Authority · Changes synchronize immediately with student apps
          </span>
          <button
            onClick={onClose}
            className="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-700 text-xs font-semibold rounded-xl transition"
          >
            Close Details
          </button>
        </div>
      </div>
    </div>
  );
}
