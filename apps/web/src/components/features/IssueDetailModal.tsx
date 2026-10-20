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
import { DeleteReportModal } from '@/components/features/DeleteReportModal';
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
  Trash2,
  ShieldAlert,
  User,
  Info,
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

  // Soft delete modal state
  const [showDeleteModal, setShowDeleteModal] = useState(false);

  const supabase = createClient();
  const isAdmin = userRole === 'admin';
  const isStaff = userRole === 'staff';
  const isAssignedStaff =
    isStaff &&
    Boolean(userDepartmentId) &&
    report.assigned_department_id === userDepartmentId;

  const isDeleted = Boolean(report.deleted_at);

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
    if (!selectedDeptId || selectedDeptId === report.assigned_department_id || isDeleted) return;
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
    if (isTransitioning || isDeleted) return;

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

  function handleDeletionSuccess(_reportId: string, _reason: string) {
    setSuccessMessage('Report has been successfully removed from active queues.');
    onReportUpdated(report.id);
  }

  const buildingName = report.buildings?.name ?? 'Campus Building';
  const floorDisplay = report.floors?.label ?? (report.floor_text ? `Floor ${report.floor_text}` : 'General Floor');
  const assignedDept = departments.find((d) => d.id === report.assigned_department_id);

  return (
    <>
      <div className="fixed inset-0 z-50 overflow-y-auto bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-3 sm:p-6 animate-in fade-in duration-150">
        <div className="bg-white rounded-3xl max-w-3xl w-full max-h-[92vh] flex flex-col shadow-2xl border border-slate-200 overflow-hidden">
          {/* Header */}
          <div className="p-5 sm:p-6 border-b border-slate-100 flex items-start justify-between bg-slate-50/70">
            <div>
              <div className="flex items-center gap-2 mb-1.5 flex-wrap">
                {isDeleted ? (
                  <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-bold bg-rose-50 text-rose-800 border border-rose-200">
                    <span className="w-1.5 h-1.5 rounded-full bg-rose-600" />
                    Removed by Admin
                  </span>
                ) : (
                  <StatusBadge status={report.status} />
                )}
                <SeverityBadge severity={report.severity} />
                <CategoryBadge category={report.category} />
                <span className="text-slate-400 text-xs font-mono font-medium">#{report.id.slice(0, 8)}</span>
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

          {/* Prominent Deletion Warning Banner if Soft-Deleted */}
          {isDeleted && (
            <div className="px-5 py-3.5 bg-rose-50 border-b border-rose-200 flex items-start gap-3">
              <ShieldAlert className="w-5 h-5 text-rose-700 shrink-0 mt-0.5" />
              <div className="text-xs space-y-1">
                <div className="font-bold text-rose-900">
                  This report was removed by an administrator on {formatDate(report.deleted_at)}
                </div>
                <p className="text-rose-800">
                  <span className="font-semibold">Reason provided:</span>{' '}
                  {report.deletion_reason || 'Administrative removal'}
                </p>
                <p className="text-rose-600 text-[11px]">
                  The record is preserved for audit history and remains visible with this explanation in the owning student’s account.
                </p>
              </div>
            </div>
          )}

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
              {/* Description & Reporter info */}
              <div className="space-y-3">
                <div>
                  <label className="text-xs font-bold text-slate-500 uppercase tracking-wider block mb-1">
                    Issue Description
                  </label>
                  <p className="text-xs text-slate-700 bg-slate-50 p-3.5 rounded-2xl border border-slate-200/80 whitespace-pre-wrap leading-relaxed">
                    {report.description || 'No detailed description supplied.'}
                  </p>
                </div>

                {/* Reporter identity snippet */}
                <div className="flex items-center gap-2 text-xs text-slate-600 bg-slate-50 p-3 rounded-xl border border-slate-200/80">
                  <User className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                  <span className="font-medium text-slate-500">Reporter:</span>
                  <span className="font-mono text-slate-800">
                    {report.reporter_id ? `Student (#${report.reporter_id.slice(0, 8)})` : 'Campus Community'}
                  </span>
                </div>

                {/* AI / Suggested department */}
                {report.suggested_department_label && (
                  <div className="flex items-start gap-2 text-xs bg-emerald-50/60 border border-emerald-200/60 p-3 rounded-xl">
                    <Sparkles className="w-3.5 h-3.5 text-emerald-700 shrink-0 mt-0.5" />
                    <div>
                      <span className="font-bold text-emerald-950">AI Suggested Department: </span>
                      <span className="text-emerald-800">{report.suggested_department_label}</span>
                    </div>
                  </div>
                )}
              </div>

              {/* Location & Metadata card */}
              <div className="space-y-3">
                <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200/80 space-y-2.5">
                  <div className="flex items-center gap-2 text-xs text-slate-800 font-semibold">
                    <Building2 className="w-4 h-4 text-[#144D37]" />
                    <span>{buildingName}</span>
                  </div>

                  <div className="flex items-center gap-2 text-xs text-slate-600">
                    <MapPin className="w-4 h-4 text-[#144D37]" />
                    <span>
                      {floorDisplay} · {report.location_details || 'General Campus Space'}
                    </span>
                  </div>

                  <div className="flex items-center gap-2 text-xs text-slate-500 pt-1 border-t border-slate-200/60">
                    <Calendar className="w-4 h-4 text-slate-400" />
                    <span>Submitted on {formatDate(report.created_at)}</span>
                  </div>

                  {report.updated_at && (
                    <div className="text-[11px] text-slate-400">
                      Last updated {formatDate(report.updated_at)}
                    </div>
                  )}
                </div>

                {/* Attached Photo Preview */}
                <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200/80">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
                      <ImageIcon className="w-3.5 h-3.5" />
                      Attached Photo
                    </span>
                    {photoUrl && (
                      <a
                        href={photoUrl}
                        target="_blank"
                        rel="noreferrer"
                        className="text-[11px] font-semibold text-[#144D37] hover:underline"
                      >
                        Open full size
                      </a>
                    )}
                  </div>

                  {isLoadingPhoto ? (
                    <div className="h-32 w-full bg-slate-200 animate-pulse rounded-xl" />
                  ) : photoUrl ? (
                    <div className="relative rounded-xl overflow-hidden border border-slate-200 bg-black/5">
                      <img
                        src={photoUrl}
                        alt="Issue photo"
                        className="w-full h-40 object-cover hover:scale-105 transition duration-300"
                      />
                    </div>
                  ) : (
                    <div className="h-24 w-full bg-white rounded-xl border border-dashed border-slate-200 flex flex-col items-center justify-center text-slate-400 text-xs">
                      <ImageIcon className="w-6 h-6 mb-1 text-slate-300" />
                      <span>No photo attached to this report</span>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Section 2: Department Assignment Controls */}
            {!isDeleted && (
              <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200/80 space-y-3">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-slate-700 uppercase tracking-wider">
                    Department Assignment
                  </label>
                  {isAdmin && (
                    <span className="text-[11px] text-slate-400 font-medium">
                      Admin Authority
                    </span>
                  )}
                </div>

                {isAdmin ? (
                  <div className="flex flex-col sm:flex-row gap-2">
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
            )}

            {/* Section 3: Status Transition Workflow & Deletion Controls */}
            {!isDeleted && (
              <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200/80 space-y-3">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-slate-700 uppercase tracking-wider">
                    Workflow Actions
                  </label>
                  {isAdmin && (
                    <button
                      type="button"
                      onClick={() => setShowDeleteModal(true)}
                      className="inline-flex items-center gap-1.5 px-3 py-1 text-xs font-semibold text-rose-700 hover:text-rose-800 hover:bg-rose-100/70 border border-rose-200/80 bg-rose-50/60 rounded-xl transition shadow-2xs"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                      Delete Report
                    </button>
                  )}
                </div>

                <div className="flex flex-wrap items-center gap-2.5">
                  {/* If REPORTED: Admin can advance to IN_PROGRESS */}
                  {report.status === 'REPORTED' && (
                    <>
                      {isAdmin ? (
                        <button
                          onClick={() => handleTransition('IN_PROGRESS', 'Admin initiated investigation and work.')}
                          disabled={isTransitioning}
                          className="px-4 py-2 bg-purple-700 hover:bg-purple-800 text-white text-xs font-bold rounded-xl transition flex items-center gap-1.5 shadow-xs disabled:opacity-50"
                        >
                          <Wrench className="w-3.5 h-3.5" />
                          Start Investigation (In Progress)
                        </button>
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
            )}

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

            {/* Section 4: Audit & Lifecycle Timeline */}
            <div className="space-y-3">
              <label className="text-xs font-bold text-slate-700 uppercase tracking-wider flex items-center gap-1.5">
                <History className="w-3.5 h-3.5" />
                Audit Trail & Status History
              </label>

              {isLoadingTimeline ? (
                <div className="space-y-2">
                  <div className="h-10 bg-slate-100 rounded-xl animate-pulse" />
                  <div className="h-10 bg-slate-100 rounded-xl animate-pulse" />
                </div>
              ) : (timelineEvents.length === 0 && !report.deleted_at) ? (
                <div className="text-xs text-slate-400 italic bg-slate-50 p-4 rounded-xl border border-dashed border-slate-200 text-center">
                  No status transition events recorded yet.
                </div>
              ) : (
                <div className="relative pl-6 space-y-4 before:absolute before:left-2 before:top-2 before:bottom-2 before:w-0.5 before:bg-slate-200">
                  {timelineEvents.map((evt) => {
                    const isResolve = evt.to_status === 'RESOLVED';
                    const isDeletion = evt.note?.toLowerCase().includes('removed by administrator');
                    return (
                      <div key={evt.id} className="relative text-xs group">
                        <div
                          className={`absolute -left-6 top-0.5 w-4 h-4 rounded-full border-2 bg-white flex items-center justify-center ${
                            isDeletion
                              ? 'border-rose-600'
                              : isResolve
                              ? 'border-emerald-600'
                              : 'border-[#144D37]'
                          }`}
                        >
                          <div
                            className={`w-1.5 h-1.5 rounded-full ${
                              isDeletion
                                ? 'bg-rose-600'
                                : isResolve
                                ? 'bg-emerald-600'
                                : 'bg-[#144D37]'
                            }`}
                          />
                        </div>

                        <div className="flex items-center gap-2 flex-wrap">
                          <span className="font-bold text-slate-900">
                            {isDeletion
                              ? 'Report Removed'
                              : evt.from_status
                              ? `${evt.from_status} → ${evt.to_status}`
                              : `Initial status: ${evt.to_status}`}
                          </span>
                          <span className="text-slate-400 text-[11px]">
                            {formatDate(evt.occurred_at)}
                          </span>
                        </div>

                        {evt.note && (
                          <div
                            className={`mt-1 p-2 rounded-lg text-[11px] leading-relaxed ${
                              isDeletion
                                ? 'bg-rose-50 text-rose-800 border border-rose-200'
                                : 'bg-slate-50 text-slate-600 border border-slate-200/60'
                            }`}
                          >
                            <MessageSquare className="w-3 h-3 inline mr-1 opacity-70" />
                            {evt.note}
                          </div>
                        )}
                      </div>
                    );
                  })}

                  {/* Dedicated administrative removal audit event in timeline */}
                  {report.deleted_at && (
                    <div className="relative text-xs group">
                      <div className="absolute -left-6 top-0.5 w-4 h-4 rounded-full border-2 bg-white flex items-center justify-center border-rose-600">
                        <div className="w-1.5 h-1.5 rounded-full bg-rose-600" />
                      </div>

                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-bold text-rose-900">
                          Report Removed by Administrator
                        </span>
                        <span className="text-slate-400 text-[11px]">
                          {formatDate(report.deleted_at)}
                        </span>
                      </div>

                      {report.deletion_reason && (
                        <div className="mt-1 p-2 rounded-lg text-[11px] leading-relaxed bg-rose-50 text-rose-800 border border-rose-200">
                          <MessageSquare className="w-3 h-3 inline mr-1 opacity-70" />
                          Reason: {report.deletion_reason}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Modal Footer */}
          <div className="p-4 sm:p-5 border-t border-slate-100 bg-slate-50/80 flex items-center justify-between">
            <span className="text-slate-400 text-xs font-mono">
              ID: {report.id}
            </span>

            <div className="flex items-center gap-2">
              <button
                onClick={onClose}
                className="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 text-xs font-bold rounded-xl transition"
              >
                Close Window
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Delete Confirmation Modal */}
      {showDeleteModal && (
        <DeleteReportModal
          report={report}
          isOpen={showDeleteModal}
          onClose={() => setShowDeleteModal(false)}
          onSuccess={handleDeletionSuccess}
        />
      )}
    </>
  );
}
