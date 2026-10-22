'use client';

import React, { useState, useEffect, useRef } from 'react';
import {
  ReportItem,
  Department,
  Building,
  UserRole,
} from '@/types/database';
import { CategoryBadge, SeverityBadge, StatusBadge } from '@/components/ui/Badge';
import { formatDate, formatRelativeTime, resolveReportTitle } from '@/lib/utils';
import { DeleteReportModal } from '@/components/features/DeleteReportModal';
import { ReportThumbnail } from '@/components/features/ReportThumbnail';
import { NewReportModal } from '@/components/features/NewReportModal';
import { createClient } from '@/lib/supabase/client';
import {
  Search,
  Building2,
  MapPin,
  RotateCcw,
  Download,
  Plus,
  Eye,
  Trash2,
  ListFilter,
  LayoutGrid,
  AlertTriangle,
  Users,
  CheckSquare,
  Square,
  User,
  Inbox,
  AlertCircle,
  X,
  ArrowUpDown,
  ChevronRight,
} from 'lucide-react';

interface IssueQueueProps {
  reports: ReportItem[];
  departments: Department[];
  buildings: Building[];
  selectedReportId: string | null;
  onSelectReport: (report: ReportItem) => void;
  isLoading: boolean;
  error: string | null;
  onRefresh: () => void;
  userRole?: UserRole;

  // Filters state
  searchQuery: string;
  onSearchChange: (q: string) => void;
  statusFilter: string;
  onStatusFilterChange: (s: string) => void;
  categoryFilter: string;
  onCategoryFilterChange: (c: string) => void;
  severityFilter: string;
  onSeverityFilterChange: (s: string) => void;
  buildingFilter: string;
  onBuildingFilterChange: (b: string) => void;
  departmentFilter: string;
  onDepartmentFilterChange: (d: string) => void;
  onResetFilters: () => void;
}

export function IssueQueue({
  reports,
  departments,
  buildings,
  selectedReportId,
  onSelectReport,
  isLoading,
  error,
  onRefresh,
  userRole = 'student',
  searchQuery,
  onSearchChange,
  statusFilter,
  onStatusFilterChange,
  categoryFilter,
  onCategoryFilterChange,
  severityFilter,
  onSeverityFilterChange,
  buildingFilter,
  onBuildingFilterChange,
  departmentFilter,
  onDepartmentFilterChange,
  onResetFilters,
}: IssueQueueProps) {
  const supabase = createClient();
  const searchInputRef = useRef<HTMLInputElement>(null);

  // Selection & Modal states
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [reportToDelete, setReportToDelete] = useState<ReportItem | null>(null);
  const [isNewReportOpen, setIsNewReportOpen] = useState(false);
  const [isBulkProcessing, setIsBulkProcessing] = useState(false);

  // Sorting
  const [sortField, setSortField] = useState<'created_at' | 'status' | 'severity'>('created_at');
  const [sortAsc, setSortAsc] = useState<boolean>(false);

  const isAdmin = userRole === 'admin';
  const hasActiveFilters =
    searchQuery.trim().length > 0 ||
    statusFilter !== '' ||
    categoryFilter !== '' ||
    severityFilter !== '' ||
    buildingFilter !== '' ||
    departmentFilter !== '';

  // Keyboard shortcut listener for Ctrl+K / Cmd+K
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        searchInputRef.current?.focus();
      }
    }
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Sort reports
  const sortedReports = [...reports].sort((a, b) => {
    if (sortField === 'created_at') {
      const timeA = new Date(a.created_at).getTime();
      const timeB = new Date(b.created_at).getTime();
      return sortAsc ? timeA - timeB : timeB - timeA;
    }
    if (sortField === 'status') {
      return sortAsc ? a.status.localeCompare(b.status) : b.status.localeCompare(a.status);
    }
    if (sortField === 'severity') {
      return sortAsc ? a.severity.localeCompare(b.severity) : b.severity.localeCompare(a.severity);
    }
    return 0;
  });

  // Toggle single row selection
  function toggleSelectRow(id: string, e: React.MouseEvent) {
    e.stopPropagation();
    const next = new Set(selectedIds);
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    setSelectedIds(next);
  }

  // Toggle select all visible
  function toggleSelectAll() {
    if (selectedIds.size === sortedReports.length && sortedReports.length > 0) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(sortedReports.map((r) => r.id)));
    }
  }

  // Export current filtered set as CSV
  function handleExportCSV() {
    if (sortedReports.length === 0) return;

    const headers = [
      'Report ID',
      'Title',
      'Category',
      'Severity',
      'Status',
      'Building',
      'Location / Room',
      'Assigned Department',
      'Suggested Department',
      'Reporter ID',
      'Created At',
      'Deleted At',
      'Deletion Reason',
    ];

    const rows = sortedReports.map((r) => [
      r.id,
      `"${(resolveReportTitle(r) || '').replace(/"/g, '""')}"`,
      r.category,
      r.severity,
      r.status,
      `"${(r.buildings?.name || '').replace(/"/g, '""')}"`,
      `"${(r.location_details || '').replace(/"/g, '""')}"`,
      `"${(r.assigned_department?.name || '').replace(/"/g, '""')}"`,
      `"${(r.suggested_department_label || '').replace(/"/g, '""')}"`,
      r.reporter_id || '',
      r.created_at,
      r.deleted_at || '',
      `"${(r.deletion_reason || '').replace(/"/g, '""')}"`,
    ]);

    const csvContent = [headers.join(','), ...rows.map((row) => row.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `ecocampus-reports-${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  // Bulk Assign Department
  async function handleBulkAssignDept(deptId: string) {
    if (!deptId || selectedIds.size === 0) return;
    setIsBulkProcessing(true);
    try {
      for (const id of Array.from(selectedIds)) {
        await supabase.rpc('assign_report_department', {
          p_report_id: id,
          p_department_id: deptId,
        });
      }
      setSelectedIds(new Set());
      onRefresh();
    } catch (e) {
      console.error('Bulk assign failed:', e);
    } finally {
      setIsBulkProcessing(false);
    }
  }

  // Bulk Status Update
  async function handleBulkStatus(newStatus: 'IN_PROGRESS' | 'RESOLVED') {
    if (selectedIds.size === 0) return;
    setIsBulkProcessing(true);
    try {
      for (const id of Array.from(selectedIds)) {
        await supabase.rpc('transition_report_status', {
          p_report_id: id,
          p_new_status: newStatus,
          p_note: `Bulk updated to ${newStatus} by Campus Administrator`,
        });
      }
      setSelectedIds(new Set());
      onRefresh();
    } catch (e) {
      console.error('Bulk status failed:', e);
    } finally {
      setIsBulkProcessing(false);
    }
  }

  return (
    <>
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-2xs overflow-hidden flex flex-col mb-8">
        {/* TOP SEARCH & ACTION TOOLBAR */}
        <div className="p-4 sm:p-5 border-b border-slate-100 bg-white space-y-3.5">
          {/* Row 1: Search + Refresh + Export + New Report */}
          <div className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
            {/* Search Input with Ctrl+K */}
            <div className="relative flex-1 max-w-lg">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
              <input
                ref={searchInputRef}
                type="text"
                value={searchQuery}
                onChange={(e) => onSearchChange(e.target.value)}
                placeholder="Search reports by title, description, room number, or student..."
                className="w-full pl-9 pr-18 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm text-slate-800 placeholder:text-slate-400 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#144D37]/20 focus:border-[#144D37] transition"
              />
              <div className="absolute right-2.5 top-1/2 -translate-y-1/2 flex items-center gap-1">
                {searchQuery && (
                  <button
                    onClick={() => onSearchChange('')}
                    className="p-1 text-slate-400 hover:text-slate-600 rounded-lg"
                    title="Clear search"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                )}
                <kbd className="hidden sm:inline-block px-1.5 py-0.5 text-[10px] font-semibold text-slate-400 bg-slate-100 border border-slate-200 rounded shadow-2xs">
                  Ctrl + K
                </kbd>
              </div>
            </div>

            {/* Action Buttons: Refresh, Export, New Report */}
            <div className="flex items-center gap-2.5 self-end sm:self-auto">
              {hasActiveFilters && (
                <button
                  type="button"
                  onClick={onResetFilters}
                  className="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-semibold text-rose-700 bg-rose-50 hover:bg-rose-100 border border-rose-200 rounded-xl transition cursor-pointer"
                >
                  <X className="w-3.5 h-3.5" />
                  <span>Clear Filters</span>
                </button>
              )}

              {/* Refresh Button */}
              <button
                type="button"
                onClick={onRefresh}
                disabled={isLoading}
                className="p-2.5 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl text-slate-600 hover:text-slate-900 shadow-2xs transition disabled:opacity-50 cursor-pointer"
                title="Refresh issues list"
              >
                <RotateCcw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
              </button>

              {/* Export Button */}
              <button
                type="button"
                onClick={handleExportCSV}
                className="inline-flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold text-slate-700 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl shadow-2xs transition cursor-pointer"
                title="Export current filtered list to CSV"
              >
                <Download className="w-3.5 h-3.5 text-slate-500" />
                <span>Export</span>
              </button>

              {/* + New Report Button */}
              {isAdmin && (
                <button
                  type="button"
                  onClick={() => setIsNewReportOpen(true)}
                  className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-bold text-white bg-[#144D37] hover:bg-[#0f3a29] rounded-xl shadow-xs transition cursor-pointer"
                >
                  <Plus className="w-4 h-4" />
                  <span>New Report</span>
                </button>
              )}
            </div>
          </div>

          {/* Row 2: 5 Dropdown Filters */}
          <div className="grid grid-cols-2 sm:grid-cols-5 gap-2.5 pt-1">
            {/* Filter 1: Status */}
            <div className="relative">
              <div className="absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none text-slate-400">
                <ListFilter className="w-3.5 h-3.5" />
              </div>
              <select
                value={statusFilter}
                onChange={(e) => onStatusFilterChange(e.target.value)}
                className="w-full pl-8 pr-6 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:bg-white focus:outline-none focus:ring-1 focus:ring-[#144D37] cursor-pointer"
              >
                <option value="">All Active Reports</option>
                <option value="REPORTED">Reported (New)</option>
                <option value="ASSIGNED">Assigned</option>
                <option value="IN_PROGRESS">In Progress</option>
                <option value="RESOLVED">Resolved</option>
                <option value="CRITICAL">Active Critical</option>
                <option value="REMOVED">Removed by Admin</option>
                <option value="ALL_WITH_REMOVED">All (Including Removed)</option>
              </select>
            </div>

            {/* Filter 2: Category */}
            <div className="relative">
              <div className="absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none text-slate-400">
                <LayoutGrid className="w-3.5 h-3.5" />
              </div>
              <select
                value={categoryFilter}
                onChange={(e) => onCategoryFilterChange(e.target.value)}
                className="w-full pl-8 pr-6 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:bg-white focus:outline-none focus:ring-1 focus:ring-[#144D37] cursor-pointer"
              >
                <option value="">All Categories</option>
                <option value="waste">Waste</option>
                <option value="water">Water</option>
                <option value="electricity">Energy</option>
                <option value="infrastructure">Infrastructure</option>
                <option value="greenery">Greenery</option>
                <option value="cleanliness">Cleanliness</option>
                <option value="other">Other</option>
              </select>
            </div>

            {/* Filter 3: Severity */}
            <div className="relative">
              <div className="absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none text-slate-400">
                <AlertTriangle className="w-3.5 h-3.5" />
              </div>
              <select
                value={severityFilter}
                onChange={(e) => onSeverityFilterChange(e.target.value)}
                className="w-full pl-8 pr-6 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:bg-white focus:outline-none focus:ring-1 focus:ring-[#144D37] cursor-pointer"
              >
                <option value="">All Severities</option>
                <option value="critical">Critical</option>
                <option value="high">High</option>
                <option value="medium">Medium</option>
                <option value="low">Low</option>
              </select>
            </div>

            {/* Filter 4: Building */}
            <div className="relative">
              <div className="absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none text-slate-400">
                <Building2 className="w-3.5 h-3.5" />
              </div>
              <select
                value={buildingFilter}
                onChange={(e) => onBuildingFilterChange(e.target.value)}
                className="w-full pl-8 pr-6 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:bg-white focus:outline-none focus:ring-1 focus:ring-[#144D37] cursor-pointer"
              >
                <option value="">All Buildings</option>
                {buildings.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>
            </div>

            {/* Filter 5: Department */}
            <div className="relative">
              <div className="absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none text-slate-400">
                <Users className="w-3.5 h-3.5" />
              </div>
              <select
                value={departmentFilter}
                onChange={(e) => onDepartmentFilterChange(e.target.value)}
                className="w-full pl-8 pr-6 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:bg-white focus:outline-none focus:ring-1 focus:ring-[#144D37] cursor-pointer"
              >
                <option value="">All Departments</option>
                {departments.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.name}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>

        {/* BULK ACTIONS FLOATING BAR */}
        {selectedIds.size > 0 && (
          <div className="bg-emerald-950 text-white px-5 py-3 flex flex-wrap items-center justify-between gap-3 border-b border-emerald-800 animate-in slide-in-from-top-2 duration-150">
            <div className="flex items-center gap-2 text-xs font-bold">
              <span className="w-5 h-5 rounded-full bg-emerald-500 text-slate-950 flex items-center justify-center text-[10px]">
                {selectedIds.size}
              </span>
              <span>reports selected</span>
            </div>

            <div className="flex items-center gap-2">
              <select
                disabled={isBulkProcessing}
                onChange={(e) => {
                  if (e.target.value) handleBulkAssignDept(e.target.value);
                }}
                defaultValue=""
                className="px-2.5 py-1.5 bg-emerald-900 border border-emerald-700 text-white rounded-lg text-xs font-medium focus:outline-none cursor-pointer"
              >
                <option value="" disabled>
                  Assign to Department...
                </option>
                {departments.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.name}
                  </option>
                ))}
              </select>

              <button
                type="button"
                disabled={isBulkProcessing}
                onClick={() => handleBulkStatus('IN_PROGRESS')}
                className="px-3 py-1.5 bg-emerald-800 hover:bg-emerald-700 rounded-lg text-xs font-semibold text-white transition cursor-pointer"
              >
                Mark In Progress
              </button>

              <button
                type="button"
                disabled={isBulkProcessing}
                onClick={() => handleBulkStatus('RESOLVED')}
                className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 rounded-lg text-xs font-bold text-white transition cursor-pointer"
              >
                Mark Resolved
              </button>

              <button
                type="button"
                onClick={() => setSelectedIds(new Set())}
                className="p-1 text-emerald-300 hover:text-white"
                title="Deselect all"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}

        {/* REPORT TABLE */}
        <div className="flex-1 overflow-x-auto">
          {error ? (
            <div className="p-12 text-center">
              <AlertCircle className="w-10 h-10 text-rose-500 mx-auto mb-3" />
              <h3 className="text-sm font-bold text-slate-800">Failed to load reports</h3>
              <p className="text-xs text-slate-500 mt-1 max-w-md mx-auto">{error}</p>
              <button
                onClick={onRefresh}
                className="mt-4 px-4 py-2 bg-[#144D37] text-white text-xs font-semibold rounded-xl hover:bg-[#0e3626] transition"
              >
                Retry Query
              </button>
            </div>
          ) : isLoading ? (
            <div className="divide-y divide-slate-100 p-4 space-y-4">
              {[1, 2, 3, 4, 5].map((i) => (
                <div key={i} className="animate-pulse flex items-center justify-between py-3">
                  <div className="flex items-center gap-3 flex-1">
                    <div className="w-10 h-10 bg-slate-200 rounded-xl shrink-0" />
                    <div className="space-y-1.5 flex-1">
                      <div className="h-4 bg-slate-200 rounded w-1/3" />
                      <div className="h-3 bg-slate-100 rounded w-1/2" />
                    </div>
                  </div>
                  <div className="h-6 bg-slate-200 rounded-full w-20" />
                </div>
              ))}
            </div>
          ) : sortedReports.length === 0 ? (
            <div className="p-16 text-center">
              <Inbox className="w-12 h-12 text-slate-300 mx-auto mb-3" />
              <h3 className="text-sm font-bold text-slate-700">No issues matching criteria</h3>
              <p className="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
                {hasActiveFilters
                  ? 'Try broadening your search or clearing active filters to see more reports.'
                  : 'There are currently no reported issues in this queue.'}
              </p>
              {hasActiveFilters && (
                <button
                  onClick={onResetFilters}
                  className="mt-4 px-3.5 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold rounded-xl transition cursor-pointer"
                >
                  Clear all filters
                </button>
              )}
            </div>
          ) : (
            <table className="w-full text-left text-xs border-collapse">
              <thead className="bg-[#FAFBFB] text-slate-400 font-bold uppercase tracking-wider text-[11px] border-b border-slate-200/80">
                <tr>
                  {/* Select All Checkbox */}
                  <th className="py-3 px-3.5 w-10 text-center">
                    <button
                      type="button"
                      onClick={toggleSelectAll}
                      className="p-1 text-slate-400 hover:text-slate-700 focus:outline-none"
                    >
                      {selectedIds.size === sortedReports.length && sortedReports.length > 0 ? (
                        <CheckSquare className="w-4 h-4 text-[#144D37]" />
                      ) : (
                        <Square className="w-4 h-4" />
                      )}
                    </button>
                  </th>

                  <th className="py-3 px-3">Issue Details</th>
                  <th className="py-3 px-3">Category</th>
                  <th className="py-3 px-3">Severity</th>
                  <th className="py-3 px-4">Location</th>
                  <th className="py-3 px-3">Assigned Dept</th>

                  {/* Status with Sort Arrow */}
                  <th className="py-3 px-3">
                    <button
                      type="button"
                      onClick={() => {
                        setSortField('status');
                        setSortAsc(!sortAsc);
                      }}
                      className="inline-flex items-center gap-1 hover:text-slate-700 focus:outline-none cursor-pointer"
                    >
                      <span>Status</span>
                      <ArrowUpDown className="w-3 h-3 text-slate-400" />
                    </button>
                  </th>

                  {/* Submitted with Sort Arrow */}
                  <th className="py-3 px-3">
                    <button
                      type="button"
                      onClick={() => {
                        setSortField('created_at');
                        setSortAsc(!sortAsc);
                      }}
                      className="inline-flex items-center gap-1 hover:text-slate-700 focus:outline-none cursor-pointer"
                    >
                      <span>Submitted</span>
                      <ArrowUpDown className="w-3 h-3 text-slate-400" />
                    </button>
                  </th>

                  <th className="py-3 px-3 text-center">Actions</th>
                </tr>
              </thead>

              <tbody className="divide-y divide-slate-100 text-slate-700">
                {sortedReports.map((report) => {
                  const isSelected = selectedReportId === report.id;
                  const isChecked = selectedIds.has(report.id);
                  const isDeleted = Boolean(report.deleted_at);

                  const buildingName = report.buildings?.name ?? 'Campus Building';
                  const floorDisplay =
                    report.floors?.label ?? (report.floor_text ? `Floor ${report.floor_text}` : null);
                  const assignedDeptName = report.assigned_department?.name;
                  const displayTitle = resolveReportTitle(report);

                  // Extract primary photo storage path
                  const primaryStoragePath =
                    report.report_media && report.report_media.length > 0
                      ? report.report_media[0].storage_path
                      : null;

                  return (
                    <tr
                      key={report.id}
                      onClick={() => onSelectReport(report)}
                      className={`hover:bg-emerald-50/40 transition cursor-pointer ${
                        isSelected ? 'bg-emerald-50/80 font-medium' : ''
                      } ${isDeleted ? 'bg-slate-50/70 opacity-80' : ''}`}
                    >
                      {/* Row Checkbox */}
                      <td
                        className="py-3 px-3.5 text-center"
                        onClick={(e) => toggleSelectRow(report.id, e)}
                      >
                        <button
                          type="button"
                          className="p-1 text-slate-400 hover:text-slate-700 focus:outline-none cursor-pointer"
                        >
                          {isChecked ? (
                            <CheckSquare className="w-4 h-4 text-[#144D37]" />
                          ) : (
                            <Square className="w-4 h-4" />
                          )}
                        </button>
                      </td>

                      {/* Issue Details: Thumbnail + Title + Snippet + Reporter */}
                      <td className="py-3 px-3 max-w-sm">
                        <div className="flex items-start gap-3">
                          <ReportThumbnail
                            storagePath={primaryStoragePath}
                            title={displayTitle}
                            className="w-10 h-10"
                          />

                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-1.5">
                              <span
                                className="font-bold text-slate-900 text-xs sm:text-sm truncate"
                                title={displayTitle}
                              >
                                {displayTitle}
                              </span>
                              {isDeleted && (
                                <span className="inline-flex items-center px-1.5 py-0.2 rounded text-[10px] font-bold bg-rose-100 text-rose-800">
                                  Removed
                                </span>
                              )}
                            </div>

                            <p
                              className="text-slate-500 text-xs truncate max-w-xs mt-0.5"
                              title={report.description}
                            >
                              {report.description || 'No additional description'}
                            </p>

                            {/* Reporter Info */}
                            <div className="text-[11px] text-slate-400 flex items-center gap-1 mt-0.5">
                              <User className="w-3 h-3 text-slate-300" />
                              <span>
                                {report.reporter_id
                                  ? `Student #${report.reporter_id.slice(0, 6)}`
                                  : 'Campus Member'}
                              </span>
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Category Badge */}
                      <td className="py-3 px-3 whitespace-nowrap">
                        <CategoryBadge category={report.category} />
                      </td>

                      {/* Severity Badge with colored dot */}
                      <td className="py-3 px-3 whitespace-nowrap">
                        <SeverityBadge severity={report.severity} />
                      </td>

                      {/* Location: Building + Floor/Room */}
                      <td className="py-3 px-4 whitespace-nowrap">
                        <div className="font-semibold text-slate-800 flex items-center gap-1.5">
                          <Building2 className="w-3.5 h-3.5 text-slate-400" />
                          <span>{buildingName}</span>
                        </div>
                        <div className="text-slate-500 text-[11px] flex items-center gap-1.5 mt-0.5">
                          <MapPin className="w-3 h-3 text-slate-400" />
                          <span className="truncate max-w-[170px]">
                            {floorDisplay ? `${floorDisplay} · ` : ''}
                            {report.location_details || 'General campus'}
                          </span>
                        </div>
                      </td>

                      {/* Assigned Department */}
                      <td className="py-3 px-3 whitespace-nowrap">
                        {assignedDeptName ? (
                          <span className="font-semibold text-slate-800 bg-slate-100 px-2.5 py-1 rounded-lg text-xs">
                            {assignedDeptName}
                          </span>
                        ) : report.suggested_department_label ? (
                          <span className="text-slate-500 italic text-[11px]">
                            Suggested: {report.suggested_department_label}
                          </span>
                        ) : (
                          <span className="text-amber-700 bg-amber-50 px-2 py-0.5 rounded text-[11px] font-medium border border-amber-200">
                            Unassigned
                          </span>
                        )}
                      </td>

                      {/* Status */}
                      <td className="py-3 px-3 whitespace-nowrap">
                        {isDeleted ? (
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-700 border border-slate-200">
                            <span className="w-1.5 h-1.5 rounded-full bg-slate-500" />
                            Removed
                          </span>
                        ) : (
                          <StatusBadge status={report.status} />
                        )}
                      </td>

                      {/* Submitted: Relative time + exact timestamp */}
                      <td className="py-3 px-3 whitespace-nowrap text-xs">
                        <div className="font-bold text-slate-700">
                          {formatRelativeTime(report.created_at)}
                        </div>
                        <div className="text-slate-400 text-[10px] mt-0.5">
                          {formatDate(report.created_at)}
                        </div>
                      </td>

                      {/* Actions: Eye & Trash Button matching screenshot */}
                      <td className="py-3 px-3 text-center whitespace-nowrap">
                        <div className="inline-flex items-center justify-center gap-1.5">
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              onSelectReport(report);
                            }}
                            className="p-1.5 text-slate-500 hover:text-emerald-700 hover:bg-emerald-50 rounded-lg border border-slate-200/60 shadow-2xs transition cursor-pointer"
                            title="View report details"
                          >
                            <Eye className="w-3.5 h-3.5" />
                          </button>

                          {isAdmin && !isDeleted && (
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                setReportToDelete(report);
                              }}
                              className="p-1.5 text-rose-500 hover:text-rose-700 hover:bg-rose-50 rounded-lg border border-slate-200/60 shadow-2xs transition cursor-pointer"
                              title="Remove by Admin (Soft-delete)"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>

        {/* FOOTER COUNT */}
        <div className="p-3 px-5 border-t border-slate-100 bg-slate-50/70 text-slate-500 text-xs flex flex-col sm:flex-row items-center justify-between gap-2">
          <div>
            Showing <span className="font-bold text-slate-800">{sortedReports.length}</span> issues
            {hasActiveFilters && ' (filtered)'}
          </div>
          <div className="text-[11px] text-slate-400">
            Click any row or action icon to view full issue details and audit trail.
          </div>
        </div>
      </div>

      {/* Delete Confirmation Modal for Quick Row Action */}
      {reportToDelete && (
        <DeleteReportModal
          report={reportToDelete}
          isOpen={Boolean(reportToDelete)}
          onClose={() => setReportToDelete(null)}
          onSuccess={() => {
            setReportToDelete(null);
            onRefresh();
          }}
        />
      )}

      {/* New Report Modal */}
      {isNewReportOpen && (
        <NewReportModal
          isOpen={isNewReportOpen}
          onClose={() => setIsNewReportOpen(false)}
          onSuccess={onRefresh}
          departments={departments}
          buildings={buildings}
        />
      )}
    </>
  );
}
