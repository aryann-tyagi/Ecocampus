'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { CampusNotice, Building } from '@/types/database';
import { createClient } from '@/lib/supabase/client';
import {
  Megaphone,
  Plus,
  Search,
  Filter,
  RefreshCw,
  Building2,
  Calendar,
  Pin,
  Edit3,
  Archive,
  CheckCircle,
  Eye,
  AlertCircle,
  Clock,
  Sparkles,
} from 'lucide-react';
import {
  getNoticeTypeBadge,
  getNoticePriorityBadge,
  getNoticeStatusBadge,
  formatDate,
  formatRelativeTime,
  cn,
} from '@/lib/utils';
import { NoticeEditorModal } from './NoticeEditorModal';

interface NoticeManagementProps {
  buildings: Building[];
}

export function NoticeManagement({ buildings }: NoticeManagementProps) {
  const supabase = createClient();

  const [notices, setNotices] = useState<CampusNotice[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [priorityFilter, setPriorityFilter] = useState('all');
  const [typeFilter, setTypeFilter] = useState('all');

  // Modal State
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [editingNotice, setEditingNotice] = useState<CampusNotice | null>(null);

  // Load notices
  const loadNotices = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const { data, error: fetchErr } = await supabase
        .from('campus_notices')
        .select(`
          *,
          target_building:buildings(id, name)
        `)
        .order('is_pinned', { ascending: false })
        .order('starts_at', { ascending: false });

      if (fetchErr) throw fetchErr;

      setNotices((data as CampusNotice[]) || []);
    } catch (err: unknown) {
      console.error('Failed to load notices:', err);
      setError(err instanceof Error ? err.message : 'Failed to load notices from database.');
    } finally {
      setIsLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadNotices();
  }, [loadNotices]);

  // Quick action: Archive or Unpublish
  async function handleToggleStatus(notice: CampusNotice, nextStatus: 'published' | 'archived' | 'draft') {
    try {
      const updates: Partial<CampusNotice> = {
        status: nextStatus,
        updated_at: new Date().toISOString(),
      };
      if (nextStatus === 'published') {
        updates.published_at = new Date().toISOString();
      }

      const { error: updateErr } = await supabase
        .from('campus_notices')
        .update(updates)
        .eq('id', notice.id);

      if (updateErr) throw updateErr;

      if (nextStatus === 'published') {
        // Trigger notification RPC
        await supabase.rpc('publish_campus_notice', { p_notice_id: notice.id });
      }

      await loadNotices();
    } catch (err: unknown) {
      console.error('Failed to update notice status:', err);
      alert(err instanceof Error ? err.message : 'Failed to update notice status');
    }
  }

  // Filter notices
  const filteredNotices = notices.filter((n) => {
    if (statusFilter !== 'all' && n.status !== statusFilter) return false;
    if (priorityFilter !== 'all' && n.priority !== priorityFilter) return false;
    if (typeFilter !== 'all' && n.notice_type !== typeFilter) return false;

    if (searchQuery.trim().length > 0) {
      const q = searchQuery.toLowerCase();
      const matchTitle = n.title.toLowerCase().includes(q);
      const matchMsg = n.message.toLowerCase().includes(q);
      const matchSummary = n.summary?.toLowerCase().includes(q) || false;
      const matchBldg = n.target_building?.name?.toLowerCase().includes(q) || false;
      if (!matchTitle && !matchMsg && !matchSummary && !matchBldg) return false;
    }
    return true;
  });

  // Calculate quick stats
  const publishedCount = notices.filter((n) => n.status === 'published').length;
  const draftCount = notices.filter((n) => n.status === 'draft').length;
  const urgentCount = notices.filter((n) => n.priority === 'urgent' && n.status === 'published').length;

  return (
    <div className="space-y-6">
      {/* Overview Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Total Notices</p>
            <p className="text-2xl font-black text-slate-900 mt-1">{notices.length}</p>
          </div>
          <div className="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center text-slate-600">
            <Megaphone className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-[11px] font-bold text-emerald-600 uppercase tracking-wider">Active Published</p>
            <p className="text-2xl font-black text-emerald-700 mt-1">{publishedCount}</p>
          </div>
          <div className="w-10 h-10 rounded-xl bg-emerald-50 flex items-center justify-center text-emerald-600">
            <CheckCircle className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-[11px] font-bold text-amber-600 uppercase tracking-wider">Drafts</p>
            <p className="text-2xl font-black text-amber-700 mt-1">{draftCount}</p>
          </div>
          <div className="w-10 h-10 rounded-xl bg-amber-50 flex items-center justify-center text-amber-600">
            <Clock className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-[11px] font-bold text-rose-600 uppercase tracking-wider">Urgent Alerts</p>
            <p className="text-2xl font-black text-rose-700 mt-1">{urgentCount}</p>
          </div>
          <div className="w-10 h-10 rounded-xl bg-rose-50 flex items-center justify-center text-rose-600">
            <AlertCircle className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Control Bar: Search, Filters & Create Button */}
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
          {/* Search Box */}
          <div className="relative w-full sm:w-80">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search notices by title, text, or building..."
              className="w-full pl-9 pr-4 py-2 text-xs font-medium rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 bg-slate-50/50 text-slate-900 placeholder:text-slate-400"
            />
          </div>

          <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
            <button
              onClick={loadNotices}
              disabled={isLoading}
              className="p-2 rounded-xl border border-slate-200 text-slate-600 hover:text-slate-900 hover:bg-slate-50 transition-colors disabled:opacity-50"
              title="Refresh notices"
            >
              <RefreshCw className={cn('w-4 h-4', isLoading && 'animate-spin')} />
            </button>

            <button
              onClick={() => {
                setEditingNotice(null);
                setIsEditorOpen(true);
              }}
              className="px-4 py-2 text-xs font-bold text-white bg-emerald-700 hover:bg-emerald-800 rounded-xl transition-all shadow-md shadow-emerald-900/10 flex items-center gap-1.5"
            >
              <Plus className="w-4 h-4" />
              <span>Create Notice</span>
            </button>
          </div>
        </div>

        {/* Filter Chips */}
        <div className="flex items-center gap-3 flex-wrap pt-2 border-t border-slate-100 text-xs">
          <div className="flex items-center gap-1 text-slate-500 font-semibold">
            <Filter className="w-3.5 h-3.5" />
            <span>Filters:</span>
          </div>

          {/* Status Filter */}
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-2.5 py-1 text-xs font-medium rounded-lg border border-slate-200 bg-white text-slate-700 focus:outline-none focus:ring-1 focus:ring-emerald-600"
          >
            <option value="all">All Statuses</option>
            <option value="published">Published</option>
            <option value="draft">Draft</option>
            <option value="archived">Archived</option>
          </select>

          {/* Priority Filter */}
          <select
            value={priorityFilter}
            onChange={(e) => setPriorityFilter(e.target.value)}
            className="px-2.5 py-1 text-xs font-medium rounded-lg border border-slate-200 bg-white text-slate-700 focus:outline-none focus:ring-1 focus:ring-emerald-600"
          >
            <option value="all">All Priorities</option>
            <option value="urgent">Urgent</option>
            <option value="important">Important</option>
            <option value="normal">Normal</option>
          </select>

          {/* Type Filter */}
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
            className="px-2.5 py-1 text-xs font-medium rounded-lg border border-slate-200 bg-white text-slate-700 focus:outline-none focus:ring-1 focus:ring-emerald-600"
          >
            <option value="all">All Notice Types</option>
            <option value="campus_announcement">Campus Announcement</option>
            <option value="issue_notice">Issue Notice</option>
            <option value="maintenance_update">Maintenance Update</option>
            <option value="utility_notice">Utility Notice</option>
            <option value="safety_notice">Safety Notice</option>
            <option value="general_notice">General Notice</option>
          </select>

          {(statusFilter !== 'all' || priorityFilter !== 'all' || typeFilter !== 'all' || searchQuery) && (
            <button
              onClick={() => {
                setStatusFilter('all');
                setPriorityFilter('all');
                setTypeFilter('all');
                setSearchQuery('');
              }}
              className="text-[11px] font-semibold text-emerald-700 hover:underline ml-auto"
            >
              Reset Filters
            </button>
          )}
        </div>
      </div>

      {/* Notices List */}
      {isLoading ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center shadow-sm">
          <div className="w-8 h-8 border-2 border-emerald-600 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          <p className="text-xs font-semibold text-slate-600">Loading campus notices...</p>
        </div>
      ) : error ? (
        <div className="bg-rose-50 rounded-2xl border border-rose-200 p-6 text-center text-rose-800">
          <AlertCircle className="w-8 h-8 text-rose-600 mx-auto mb-2" />
          <p className="text-xs font-bold">{error}</p>
          <button
            onClick={loadNotices}
            className="mt-3 px-3 py-1 bg-white border border-rose-300 rounded-lg text-xs font-semibold hover:bg-rose-100"
          >
            Retry
          </button>
        </div>
      ) : filteredNotices.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center shadow-sm">
          <Megaphone className="w-10 h-10 text-slate-300 mx-auto mb-3" />
          <h3 className="text-sm font-bold text-slate-800">No notices found</h3>
          <p className="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
            {searchQuery || statusFilter !== 'all'
              ? 'Try adjusting your search criteria or filters.'
              : 'Create your first campus notice to broadcast announcements or maintenance alerts.'}
          </p>
          <button
            onClick={() => {
              setEditingNotice(null);
              setIsEditorOpen(true);
            }}
            className="mt-4 px-4 py-2 bg-emerald-700 text-white rounded-xl text-xs font-bold hover:bg-emerald-800 transition-colors inline-flex items-center gap-1.5"
          >
            <Plus className="w-3.5 h-3.5" />
            Create Notice
          </button>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredNotices.map((notice) => {
            const typeBadge = getNoticeTypeBadge(notice.notice_type);
            const priorityBadge = getNoticePriorityBadge(notice.priority);
            const statusBadge = getNoticeStatusBadge(notice.status);

            const isCurrentlyActive =
              notice.status === 'published' &&
              new Date(notice.starts_at) <= new Date() &&
              (!notice.expires_at || new Date(notice.expires_at) > new Date());

            return (
              <div
                key={notice.id}
                className={cn(
                  'bg-white rounded-2xl border transition-all p-4 sm:p-5 shadow-sm hover:shadow-md flex flex-col md:flex-row md:items-center justify-between gap-4',
                  notice.is_pinned
                    ? 'border-emerald-300 bg-emerald-50/10'
                    : 'border-slate-200'
                )}
              >
                {/* Notice Info */}
                <div className="flex-1 min-w-0 space-y-2">
                  {/* Badges Row */}
                  <div className="flex items-center gap-2 flex-wrap">
                    <span
                      className={cn(
                        'text-[10px] font-bold px-2 py-0.5 rounded-full border',
                        typeBadge.bg
                      )}
                    >
                      {typeBadge.label}
                    </span>

                    {notice.priority !== 'normal' && (
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

                    <span
                      className={cn(
                        'text-[10px] font-bold px-2 py-0.5 rounded-full border flex items-center gap-1',
                        statusBadge.bg
                      )}
                    >
                      <span className={cn('w-1 h-1 rounded-full', statusBadge.dot)} />
                      {statusBadge.label}
                    </span>

                    {isCurrentlyActive && (
                      <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-700 border border-emerald-500/20 flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                        Live on Mobile
                      </span>
                    )}

                    {notice.is_pinned && (
                      <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-emerald-100 text-emerald-800 flex items-center gap-0.5">
                        <Pin className="w-2.5 h-2.5" /> Pinned
                      </span>
                    )}
                  </div>

                  {/* Title */}
                  <h3 className="text-base font-bold text-slate-900 tracking-tight">
                    {notice.title}
                  </h3>

                  {/* Summary / Message Preview */}
                  <p className="text-xs text-slate-600 line-clamp-2">
                    {notice.summary || notice.message}
                  </p>

                  {/* Meta Details */}
                  <div className="flex items-center gap-4 flex-wrap text-[11px] text-slate-400 pt-1">
                    <span className="flex items-center gap-1 text-slate-600 font-medium">
                      <Building2 className="w-3.5 h-3.5 text-emerald-600" />
                      {notice.target_building?.name || 'Entire Campus (All Students)'}
                    </span>

                    <span className="flex items-center gap-1">
                      <Calendar className="w-3.5 h-3.5" />
                      Starts: {formatDate(notice.starts_at)}
                    </span>

                    {notice.expires_at && (
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5 text-amber-600" />
                        Expires: {formatDate(notice.expires_at)}
                      </span>
                    )}

                    <span>Created {formatRelativeTime(notice.created_at)}</span>
                  </div>
                </div>

                {/* Actions */}
                <div className="flex items-center gap-2 self-end md:self-center shrink-0 pt-2 md:pt-0 border-t md:border-t-0 border-slate-100 w-full md:w-auto justify-end">
                  {/* Edit */}
                  <button
                    onClick={() => {
                      setEditingNotice(notice);
                      setIsEditorOpen(true);
                    }}
                    className="p-2 rounded-xl border border-slate-200 text-slate-700 hover:text-slate-900 hover:bg-slate-50 transition-colors flex items-center gap-1 text-xs font-semibold"
                    title="Edit Notice"
                  >
                    <Edit3 className="w-3.5 h-3.5" />
                    <span className="hidden sm:inline">Edit</span>
                  </button>

                  {/* Publish Quick Toggle if draft or archived */}
                  {notice.status !== 'published' ? (
                    <button
                      onClick={() => handleToggleStatus(notice, 'published')}
                      className="px-3 py-1.5 rounded-xl bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors text-xs font-bold flex items-center gap-1"
                    >
                      <CheckCircle className="w-3.5 h-3.5" />
                      Publish
                    </button>
                  ) : (
                    <button
                      onClick={() => handleToggleStatus(notice, 'archived')}
                      className="px-3 py-1.5 rounded-xl bg-slate-100 text-slate-600 border border-slate-200 hover:bg-slate-200 transition-colors text-xs font-medium flex items-center gap-1"
                      title="Archive Notice"
                    >
                      <Archive className="w-3.5 h-3.5" />
                      Archive
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Editor & Preview Modal */}
      <NoticeEditorModal
        notice={editingNotice}
        buildings={buildings}
        isOpen={isEditorOpen}
        onClose={() => {
          setIsEditorOpen(false);
          setEditingNotice(null);
        }}
        onSaved={loadNotices}
      />
    </div>
  );
}
