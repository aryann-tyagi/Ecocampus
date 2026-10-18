'use client';

import React, { useState, useEffect } from 'react';
import {
  CampusNotice,
  Building,
  NoticeType,
  NoticePriority,
  NoticeStatus,
} from '@/types/database';
import { createClient } from '@/lib/supabase/client';
import {
  X,
  Megaphone,
  Eye,
  CheckCircle2,
  Calendar,
  Building2,
  Pin,
  AlertTriangle,
  FileText,
  Clock,
  Sparkles,
} from 'lucide-react';
import {
  getNoticeTypeBadge,
  getNoticePriorityBadge,
  formatDate,
  cn,
} from '@/lib/utils';

interface NoticeEditorModalProps {
  notice: CampusNotice | null;
  buildings: Building[];
  isOpen: boolean;
  onClose: () => void;
  onSaved: () => void;
}

export function NoticeEditorModal({
  notice,
  buildings,
  isOpen,
  onClose,
  onSaved,
}: NoticeEditorModalProps) {
  const supabase = createClient();
  const isEditing = !!notice;

  // Form State
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [summary, setSummary] = useState('');
  const [noticeType, setNoticeType] = useState<NoticeType>('campus_announcement');
  const [priority, setPriority] = useState<NoticePriority>('normal');
  const [status, setStatus] = useState<NoticeStatus>('draft');
  const [targetBuildingId, setTargetBuildingId] = useState<string>('all');
  const [isPinned, setIsPinned] = useState(false);
  const [startsAt, setStartsAt] = useState('');
  const [expiresAt, setExpiresAt] = useState('');

  // UI State
  const [activeTab, setActiveTab] = useState<'edit' | 'preview'>('edit');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Initialize form when notice changes or modal opens
  useEffect(() => {
    if (notice) {
      setTitle(notice.title);
      setMessage(notice.message);
      setSummary(notice.summary || '');
      setNoticeType(notice.notice_type);
      setPriority(notice.priority);
      setStatus(notice.status);
      setTargetBuildingId(notice.target_building_id || 'all');
      setIsPinned(notice.is_pinned);

      // Format ISO dates to datetime-local
      const toLocalISO = (isoStr: string) => {
        try {
          const d = new Date(isoStr);
          const offset = d.getTimezoneOffset() * 60000;
          return new Date(d.getTime() - offset).toISOString().slice(0, 16);
        } catch {
          return '';
        }
      };

      setStartsAt(notice.starts_at ? toLocalISO(notice.starts_at) : '');
      setExpiresAt(notice.expires_at ? toLocalISO(notice.expires_at) : '');
    } else {
      // Default new notice
      setTitle('');
      setMessage('');
      setSummary('');
      setNoticeType('campus_announcement');
      setPriority('normal');
      setStatus('draft');
      setTargetBuildingId('all');
      setIsPinned(false);

      const now = new Date();
      const offset = now.getTimezoneOffset() * 60000;
      setStartsAt(new Date(now.getTime() - offset).toISOString().slice(0, 16));
      setExpiresAt('');
    }
    setError(null);
    setActiveTab('edit');
  }, [notice, isOpen]);

  if (!isOpen) return null;

  async function handleSave(newStatus?: NoticeStatus) {
    const finalStatus = newStatus || status;
    setError(null);

    // Validation
    const cleanTitle = title.trim();
    const cleanMessage = message.trim();
    const cleanSummary = summary.trim();

    if (cleanTitle.length < 2 || cleanTitle.length > 160) {
      setError('Title must be between 2 and 160 characters.');
      return;
    }

    if (cleanMessage.length === 0) {
      setError('Notice body or message cannot be empty.');
      return;
    }

    if (cleanSummary.length > 300) {
      setError('Summary cannot exceed 300 characters.');
      return;
    }

    let startIso: string;
    try {
      startIso = startsAt ? new Date(startsAt).toISOString() : new Date().toISOString();
    } catch {
      setError('Invalid publication start date.');
      return;
    }

    let expireIso: string | null = null;
    if (expiresAt) {
      try {
        expireIso = new Date(expiresAt).toISOString();
        if (new Date(expireIso) <= new Date(startIso)) {
          setError('Expiry date and time must be after the publication start date.');
          return;
        }
      } catch {
        setError('Invalid expiry date.');
        return;
      }
    }

    setIsSubmitting(true);
    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (!session?.user) {
        throw new Error('Authentication required.');
      }

      const payload = {
        title: cleanTitle,
        message: cleanMessage,
        summary: cleanSummary.length > 0 ? cleanSummary : null,
        notice_type: noticeType,
        priority,
        status: finalStatus,
        target_building_id: targetBuildingId === 'all' ? null : targetBuildingId,
        is_pinned: isPinned,
        starts_at: startIso,
        expires_at: expireIso,
        published_at: finalStatus === 'published' ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
      };

      if (isEditing && notice) {
        const { error: updateErr } = await supabase
          .from('campus_notices')
          .update(payload)
          .eq('id', notice.id);

        if (updateErr) throw updateErr;

        // If publishing via edit, trigger publish_campus_notice RPC to notify students
        if (finalStatus === 'published' && notice.status !== 'published') {
          await supabase.rpc('publish_campus_notice', { p_notice_id: notice.id });
        }
      } else {
        const { data: inserted, error: insertErr } = await supabase
          .from('campus_notices')
          .insert({
            ...payload,
            created_by: session.user.id,
          })
          .select('id')
          .single();

        if (insertErr) throw insertErr;

        // If published immediately, call RPC to notify students
        if (finalStatus === 'published' && inserted?.id) {
          await supabase.rpc('publish_campus_notice', { p_notice_id: inserted.id });
        }
      }

      onSaved();
      onClose();
    } catch (err: unknown) {
      console.error('Error saving notice:', err);
      setError(err instanceof Error ? err.message : 'Failed to save notice. Please check inputs.');
    } finally {
      setIsSubmitting(false);
    }
  }

  const selectedBuildingName =
    targetBuildingId === 'all'
      ? 'All Campus'
      : buildings.find((b) => b.id === targetBuildingId)?.name || 'Specific Building';

  const typeBadge = getNoticeTypeBadge(noticeType);
  const priorityBadge = getNoticePriorityBadge(priority);

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 animate-in fade-in duration-200">
      <div className="bg-white rounded-3xl max-w-3xl w-full shadow-2xl border border-slate-200 overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="p-5 sm:p-6 bg-slate-900 text-white flex items-center justify-between shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-emerald-500/20 border border-emerald-400/30 flex items-center justify-center text-emerald-400">
              <Megaphone className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold tracking-tight">
                {isEditing ? 'Edit Campus Notice' : 'Create Campus Notice'}
              </h2>
              <p className="text-xs text-slate-400">
                Publish announcements, maintenance updates, and alerts to student devices.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {/* View tabs */}
            <div className="flex rounded-xl bg-slate-800 p-1 border border-slate-700">
              <button
                type="button"
                onClick={() => setActiveTab('edit')}
                className={cn(
                  'px-3 py-1 text-xs font-semibold rounded-lg transition-all',
                  activeTab === 'edit'
                    ? 'bg-emerald-600 text-white shadow-sm'
                    : 'text-slate-400 hover:text-white'
                )}
              >
                Editor
              </button>
              <button
                type="button"
                onClick={() => setActiveTab('preview')}
                className={cn(
                  'px-3 py-1 text-xs font-semibold rounded-lg transition-all flex items-center gap-1.5',
                  activeTab === 'preview'
                    ? 'bg-emerald-600 text-white shadow-sm'
                    : 'text-slate-400 hover:text-white'
                )}
              >
                <Eye className="w-3.5 h-3.5" />
                Preview
              </button>
            </div>

            <button
              onClick={onClose}
              className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Error Alert */}
        {error && (
          <div className="px-6 py-3 bg-rose-50 border-b border-rose-200 text-rose-800 text-xs flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 shrink-0 text-rose-600" />
            <span>{error}</span>
          </div>
        )}

        {/* Content Body */}
        <div className="flex-1 overflow-y-auto p-5 sm:p-6">
          {activeTab === 'edit' ? (
            <div className="space-y-5">
              {/* Title */}
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                  Notice Title <span className="text-rose-500">*</span>
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="e.g. Water Supply Interruption in Boys Hostel Block 2"
                  maxLength={160}
                  className="w-full text-sm font-semibold px-4 py-2.5 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 transition-all text-slate-900 placeholder:text-slate-400"
                />
                <span className="text-[10px] text-slate-400 mt-1 block">
                  {title.length}/160 characters
                </span>
              </div>

              {/* Grid: Type & Priority */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                    Notice Type <span className="text-rose-500">*</span>
                  </label>
                  <select
                    value={noticeType}
                    onChange={(e) => setNoticeType(e.target.value as NoticeType)}
                    className="w-full text-xs font-semibold px-3 py-2.5 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 text-slate-900 bg-white"
                  >
                    <option value="campus_announcement">Campus Announcement</option>
                    <option value="issue_notice">Issue Notice</option>
                    <option value="maintenance_update">Maintenance Update</option>
                    <option value="utility_notice">Utility (Water / Electricity)</option>
                    <option value="safety_notice">Safety Notice</option>
                    <option value="general_notice">General Notice</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                    Priority Level <span className="text-rose-500">*</span>
                  </label>
                  <select
                    value={priority}
                    onChange={(e) => setPriority(e.target.value as NoticePriority)}
                    className="w-full text-xs font-semibold px-3 py-2.5 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 text-slate-900 bg-white"
                  >
                    <option value="normal">Normal (Standard broadcast)</option>
                    <option value="important">Important (Highlighted in feed)</option>
                    <option value="urgent">Urgent (High priority alert)</option>
                  </select>
                </div>
              </div>

              {/* Grid: Target Building & Pinned */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                    Target Audience / Location
                  </label>
                  <select
                    value={targetBuildingId}
                    onChange={(e) => setTargetBuildingId(e.target.value)}
                    className="w-full text-xs font-semibold px-3 py-2.5 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 text-slate-900 bg-white"
                  >
                    <option value="all">Entire Campus (All Students & Staff)</option>
                    {buildings.map((b) => (
                      <option key={b.id} value={b.id}>
                        {b.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="flex items-center gap-3 pt-5">
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      checked={isPinned}
                      onChange={(e) => setIsPinned(e.target.checked)}
                      className="sr-only peer"
                    />
                    <div className="w-11 h-6 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600"></div>
                  </label>
                  <div>
                    <span className="text-xs font-bold text-slate-800 flex items-center gap-1">
                      <Pin className="w-3.5 h-3.5 text-emerald-600" />
                      Pin to Top of Feed
                    </span>
                    <span className="text-[10px] text-slate-400 block">
                      Always appears at the top of the student home screen banner.
                    </span>
                  </div>
                </div>
              </div>

              {/* Summary */}
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                  Short Summary / Preview Snippet
                </label>
                <input
                  type="text"
                  value={summary}
                  onChange={(e) => setSummary(e.target.value)}
                  placeholder="A 1-2 sentence preview shown on notifications and cards..."
                  maxLength={300}
                  className="w-full text-xs px-3 py-2 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 text-slate-900 placeholder:text-slate-400"
                />
                <span className="text-[10px] text-slate-400 mt-1 block">
                  {summary.length}/300 characters
                </span>
              </div>

              {/* Body Message */}
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                  Full Notice Content <span className="text-rose-500">*</span>
                </label>
                <textarea
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  rows={5}
                  placeholder="Detailed information regarding the notice, timelines, alternative arrangements, or steps students should take..."
                  className="w-full text-xs px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 text-slate-900 placeholder:text-slate-400"
                />
              </div>

              {/* Schedule Dates */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 p-4 bg-slate-50 rounded-2xl border border-slate-200">
                <div>
                  <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-600 mb-1 flex items-center gap-1.5">
                    <Calendar className="w-3.5 h-3.5 text-emerald-600" />
                    Publication Start Date & Time
                  </label>
                  <input
                    type="datetime-local"
                    value={startsAt}
                    onChange={(e) => setStartsAt(e.target.value)}
                    className="w-full text-xs font-medium px-3 py-2 rounded-xl border border-slate-300 bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500/20 text-slate-800"
                  />
                  <span className="text-[10px] text-slate-400 mt-0.5 block">
                    Notices remain hidden until this timestamp.
                  </span>
                </div>

                <div>
                  <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-600 mb-1 flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5 text-amber-600" />
                    Expiry Date & Time (Optional)
                  </label>
                  <input
                    type="datetime-local"
                    value={expiresAt}
                    onChange={(e) => setExpiresAt(e.target.value)}
                    className="w-full text-xs font-medium px-3 py-2 rounded-xl border border-slate-300 bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500/20 text-slate-800"
                  />
                  <span className="text-[10px] text-slate-400 mt-0.5 block">
                    Notice will automatically disappear after this date.
                  </span>
                </div>
              </div>
            </div>
          ) : (
            /* Student Mobile Preview */
            <div className="py-4 flex flex-col items-center">
              <p className="text-xs text-slate-500 mb-4 flex items-center gap-1.5">
                <Sparkles className="w-4 h-4 text-emerald-600" />
                This is how the notice will render in the Flutter Student Mobile App:
              </p>

              {/* Mobile Phone Simulation Card */}
              <div className="w-full max-w-sm bg-white rounded-3xl border-4 border-slate-800 shadow-2xl overflow-hidden">
                {/* Phone Top Notch */}
                <div className="bg-slate-800 h-5 w-full flex items-center justify-center">
                  <div className="w-16 h-2.5 bg-slate-900 rounded-full" />
                </div>

                {/* App Notice Banner / Card */}
                <div className="p-4 bg-[#F8FAF8]">
                  <div
                    className={cn(
                      'rounded-2xl p-4 border shadow-sm transition-all bg-white',
                      priority === 'urgent'
                        ? 'border-rose-300 shadow-rose-100'
                        : priority === 'important'
                        ? 'border-amber-300 shadow-amber-100'
                        : 'border-slate-200'
                    )}
                  >
                    {/* Header Row */}
                    <div className="flex items-center justify-between gap-2 mb-2">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span
                          className={cn(
                            'text-[10px] font-bold px-2 py-0.5 rounded-full border',
                            typeBadge.bg
                          )}
                        >
                          {typeBadge.label}
                        </span>

                        {priority !== 'normal' && (
                          <span
                            className={cn(
                              'text-[10px] font-bold px-2 py-0.5 rounded-full border flex items-center gap-1',
                              priorityBadge.bg
                            )}
                          >
                            <span className={cn('w-1 h-1 rounded-full', priorityBadge.dot)} />
                            {priorityBadge.label}
                          </span>
                        )}

                        {isPinned && (
                          <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-emerald-50 text-emerald-700 border border-emerald-200 flex items-center gap-0.5">
                            <Pin className="w-2.5 h-2.5" /> Pinned
                          </span>
                        )}
                      </div>

                      <span className="text-[10px] text-slate-400">
                        {startsAt ? formatDate(new Date(startsAt).toISOString()) : 'Today'}
                      </span>
                    </div>

                    {/* Title */}
                    <h3 className="text-sm font-bold text-slate-900 mb-1 leading-snug">
                      {title.trim() || 'Notice Title Will Appear Here'}
                    </h3>

                    {/* Preview Summary or Message */}
                    <p className="text-xs text-slate-600 line-clamp-3 mb-3 leading-relaxed">
                      {summary.trim() ||
                        message.trim() ||
                        'Notice message preview will be displayed here for students on campus...'}
                    </p>

                    {/* Location Badge */}
                    <div className="flex items-center justify-between pt-2 border-t border-slate-100 text-[11px] text-slate-500">
                      <span className="inline-flex items-center gap-1 font-medium text-emerald-800">
                        <Building2 className="w-3 h-3" />
                        {selectedBuildingName}
                      </span>
                      <span className="text-emerald-700 font-semibold text-[10px]">
                        Read Notice →
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="p-4 sm:p-5 bg-slate-50 border-t border-slate-200 flex flex-col sm:flex-row items-center justify-between gap-3 shrink-0">
          <div className="flex items-center gap-2 w-full sm:w-auto">
            <span className="text-xs font-semibold text-slate-500">
              Current state:{' '}
              <span
                className={cn(
                  'px-2 py-0.5 rounded-md font-bold text-[10px] uppercase tracking-wider',
                  status === 'published'
                    ? 'bg-emerald-100 text-emerald-800'
                    : status === 'archived'
                    ? 'bg-slate-200 text-slate-700'
                    : 'bg-amber-100 text-amber-800'
                )}
              >
                {status}
              </span>
            </span>
          </div>

          <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900 bg-white border border-slate-200 rounded-xl hover:bg-slate-100 transition-colors"
            >
              Cancel
            </button>

            {/* Save Draft */}
            <button
              type="button"
              disabled={isSubmitting}
              onClick={() => handleSave('draft')}
              className="px-4 py-2 text-xs font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 rounded-xl transition-colors disabled:opacity-50"
            >
              Save as Draft
            </button>

            {/* Publish or Update */}
            <button
              type="button"
              disabled={isSubmitting}
              onClick={() => handleSave('published')}
              className="px-5 py-2 text-xs font-bold text-white bg-emerald-700 hover:bg-emerald-800 rounded-xl transition-all shadow-md shadow-emerald-900/10 flex items-center gap-1.5 disabled:opacity-50"
            >
              <CheckCircle2 className="w-4 h-4" />
              {isSubmitting ? 'Saving...' : 'Publish to Students'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
