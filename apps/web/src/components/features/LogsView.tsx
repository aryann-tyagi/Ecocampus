'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import {
  FileText,
  RotateCcw,
  Search,
  CheckCircle2,
  AlertCircle,
  Filter,
  User,
  ArrowRight,
} from 'lucide-react';
import { formatDate, formatRelativeTime } from '@/lib/utils';

interface AuditLogEvent {
  id: string;
  report_id: string;
  from_status: string | null;
  to_status: string;
  actor_id: string | null;
  note: string | null;
  occurred_at: string;
}

interface LogsViewProps {
  onSelectReportId?: (reportId: string) => void;
}

export function LogsView({ onSelectReportId }: LogsViewProps) {
  const supabase = createClient();
  const [logs, setLogs] = useState<AuditLogEvent[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');

  const loadLogs = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const { data, error: fetchErr } = await supabase
        .from('report_status_events')
        .select('*')
        .order('occurred_at', { ascending: false })
        .limit(100);

      if (fetchErr) throw fetchErr;
      setLogs((data as AuditLogEvent[]) || []);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to fetch operational audit logs.');
    } finally {
      setIsLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadLogs();
  }, [loadLogs]);

  const filteredLogs = logs.filter((log) => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    const note = (log.note || '').toLowerCase();
    const repId = log.report_id.toLowerCase();
    const actor = (log.actor_id || '').toLowerCase();
    return note.includes(q) || repId.includes(q) || actor.includes(q);
  });

  return (
    <div className="space-y-4 animate-in fade-in duration-150">
      {/* Header & Controls */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-4 shadow-2xs flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search audit trail by note, report ID, or actor..."
            className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm text-slate-800 focus:bg-white focus:outline-none focus:ring-1 focus:ring-[#144D37]"
          />
        </div>

        <button
          type="button"
          onClick={loadLogs}
          disabled={isLoading}
          className="p-2.5 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl text-slate-600 shadow-2xs transition disabled:opacity-50 cursor-pointer self-end sm:self-auto"
          title="Refresh logs"
        >
          <RotateCcw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {/* Logs Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-2xs overflow-hidden">
        {error ? (
          <div className="p-8 text-center text-xs text-rose-600">{error}</div>
        ) : isLoading ? (
          <div className="p-8 text-center text-xs text-slate-400">Loading operational audit logs...</div>
        ) : filteredLogs.length === 0 ? (
          <div className="p-12 text-center text-xs text-slate-400">No audit events recorded.</div>
        ) : (
          <table className="w-full text-left text-xs border-collapse">
            <thead className="bg-[#FAFBFB] text-slate-400 font-bold uppercase tracking-wider text-[11px] border-b border-slate-200/80">
              <tr>
                <th className="py-3 px-4">Event & Transition</th>
                <th className="py-3 px-3">Report Reference</th>
                <th className="py-3 px-3">Actor</th>
                <th className="py-3 px-3">Audit Note</th>
                <th className="py-3 px-3">Occurred At</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700">
              {filteredLogs.map((log) => (
                <tr key={log.id} className="hover:bg-slate-50/70 transition">
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-1.5 font-semibold text-slate-800">
                      <span className="text-slate-400 font-mono text-[11px]">
                        {log.from_status || 'NEW'}
                      </span>
                      <ArrowRight className="w-3 h-3 text-slate-400" />
                      <span className="text-emerald-700 font-bold">{log.to_status}</span>
                    </div>
                  </td>

                  <td className="py-3 px-3">
                    <button
                      type="button"
                      onClick={() => onSelectReportId?.(log.report_id)}
                      className="font-mono text-emerald-700 hover:underline"
                    >
                      {log.report_id.slice(0, 8)}...
                    </button>
                  </td>

                  <td className="py-3 px-3 text-slate-500">
                    <div className="flex items-center gap-1 font-mono text-[11px]">
                      <User className="w-3 h-3 text-slate-400" />
                      <span>{log.actor_id ? log.actor_id.slice(0, 8) : 'System'}</span>
                    </div>
                  </td>

                  <td className="py-3 px-3 text-slate-600 max-w-xs truncate">
                    {log.note || 'Status transition logged'}
                  </td>

                  <td className="py-3 px-3 text-slate-500 text-[11px] whitespace-nowrap">
                    <div>{formatRelativeTime(log.occurred_at)}</div>
                    <div className="text-slate-400 text-[10px]">{formatDate(log.occurred_at)}</div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
