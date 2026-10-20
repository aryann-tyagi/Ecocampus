'use client';

import React, { useState } from 'react';
import {
  ReportItem,
  Department,
  Building,
  UserRole,
} from '@/types/database';
import { CategoryBadge, SeverityBadge, StatusBadge } from '@/components/ui/Badge';
import { formatDate, formatRelativeTime, resolveReportTitle } from '@/lib/utils';
import { DeleteReportModal } from '@/components/features/DeleteReportModal';
import {
  Search,
  ChevronRight,
  MapPin,
  Building2,
  X,
  RotateCcw,
  AlertCircle,
  Inbox,
  Trash2,
  Image as ImageIcon,
  User,
  ShieldAlert,
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
  const [reportToDelete, setReportToDelete] = useState<ReportItem | null>(null);

  const isAdmin = userRole === 'admin';
  const hasActiveFilters =
    searchQuery.trim().length > 0 ||
    statusFilter !== '' ||
    categoryFilter !== '' ||
    severityFilter !== '' ||
    buildingFilter !== '' ||
    departmentFilter !== '';

  return (
    <>
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-xs overflow-hidden flex flex-col">
        {/* Search and Filters Header */}
        <div className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/60 space-y-3">
          <div className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
            {/* Search Input */}
            <div className="relative flex-1 max-w-md">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => onSearchChange(e.target.value)}
                placeholder="Search reports by title, description, or room..."
                className="w-full pl-9 pr-8 py-2 bg-white border border-slate-200 rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#144D37]/30 focus:border-[#144D37] transition text-slate-800 placeholder:text-slate-400"
              />
              {searchQuery && (
                <button
                  onClick={() => onSearchChange('')}
                  className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                >
                  <X className="w-3.5 h-3.5" />
                </button>
              )}
            </div>

            {/* Refresh & Reset Controls */}
            <div className="flex items-center gap-2 self-end sm:self-auto">
              {hasActiveFilters && (
                <button
                  onClick={onResetFilters}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-rose-700 bg-rose-50 hover:bg-rose-100 border border-rose-200 rounded-xl transition"
                >
                  <X className="w-3.5 h-3.5" />
                  Clear Filters
                </button>
              )}

              <button
                onClick={onRefresh}
                disabled={isLoading}
                className="inline-flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold text-slate-700 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl shadow-2xs transition disabled:opacity-50"
              >
                <RotateCcw className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`} />
                Refresh
              </button>
            </div>
          </div>

          {/* Filter Dropdowns Grid */}
          <div className="grid grid-cols-2 sm:grid-cols-5 gap-2 pt-1">
            {/* Status Filter */}
            <select
              value={statusFilter}
              onChange={(e) => onStatusFilterChange(e.target.value)}
              className="w-full px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:outline-none focus:ring-1 focus:ring-[#144D37]"
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

            {/* Category Filter */}
            <select
              value={categoryFilter}
              onChange={(e) => onCategoryFilterChange(e.target.value)}
              className="w-full px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:outline-none focus:ring-1 focus:ring-[#144D37]"
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

            {/* Severity Filter */}
            <select
              value={severityFilter}
              onChange={(e) => onSeverityFilterChange(e.target.value)}
              className="w-full px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:outline-none focus:ring-1 focus:ring-[#144D37]"
            >
              <option value="">All Severities</option>
              <option value="critical">Critical</option>
              <option value="high">High</option>
              <option value="medium">Medium</option>
              <option value="low">Low</option>
            </select>

            {/* Building Filter */}
            <select
              value={buildingFilter}
              onChange={(e) => onBuildingFilterChange(e.target.value)}
              className="w-full px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:outline-none focus:ring-1 focus:ring-[#144D37]"
            >
              <option value="">All Buildings</option>
              {buildings.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name}
                </option>
              ))}
            </select>

            {/* Department Filter */}
            <select
              value={departmentFilter}
              onChange={(e) => onDepartmentFilterChange(e.target.value)}
              className="w-full px-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:outline-none focus:ring-1 focus:ring-[#144D37]"
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

        {/* Queue Body / Table */}
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
                  <div className="space-y-2 flex-1">
                    <div className="h-4 bg-slate-200 rounded w-1/3" />
                    <div className="h-3 bg-slate-100 rounded w-1/2" />
                  </div>
                  <div className="h-6 bg-slate-200 rounded-full w-20" />
                </div>
              ))}
            </div>
          ) : reports.length === 0 ? (
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
                  className="mt-4 px-3.5 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold rounded-xl transition"
                >
                  Clear all filters
                </button>
              )}
            </div>
          ) : (
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50 text-slate-500 font-semibold uppercase tracking-wider border-b border-slate-200/80">
                <tr>
                  <th className="py-3 px-4">Issue Details</th>
                  <th className="py-3 px-3">Category</th>
                  <th className="py-3 px-3">Severity</th>
                  <th className="py-3 px-4">Location</th>
                  <th className="py-3 px-3">Assigned Dept</th>
                  <th className="py-3 px-3">Status</th>
                  <th className="py-3 px-3">Submitted</th>
                  <th className="py-3 px-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-slate-700">
                {reports.map((report) => {
                  const isSelected = selectedReportId === report.id;
                  const isDeleted = Boolean(report.deleted_at);
                  const buildingName = report.buildings?.name ?? 'Campus Building';
                  const floorDisplay = report.floors?.label ?? (report.floor_text ? `Floor ${report.floor_text}` : null);
                  const assignedDeptName = report.assigned_department?.name;
                  const displayTitle = resolveReportTitle(report);
                  const hasPhoto = Boolean(report.report_media && report.report_media.length > 0);

                  return (
                    <tr
                      key={report.id}
                      onClick={() => onSelectReport(report)}
                      className={`hover:bg-emerald-50/30 transition cursor-pointer ${
                        isSelected ? 'bg-emerald-50/70 font-medium' : ''
                      } ${isDeleted ? 'bg-slate-50/60 opacity-80' : ''}`}
                    >
                      {/* Title & Preview with thumbnail */}
                      <td className="py-3 px-4 max-w-xs">
                        <div className="flex items-start gap-2.5">
                          <div className="w-9 h-9 rounded-xl bg-slate-100 border border-slate-200 flex items-center justify-center shrink-0 overflow-hidden text-slate-400 mt-0.5">
                            {hasPhoto ? (
                              <ImageIcon className="w-4 h-4 text-[#144D37]" />
                            ) : (
                              <Inbox className="w-4 h-4 text-slate-300" />
                            )}
                          </div>

                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-1.5">
                              <div
                                className="font-bold text-slate-900 text-xs sm:text-sm truncate"
                                title={displayTitle}
                              >
                                {displayTitle}
                              </div>
                              {isDeleted && (
                                <span className="inline-flex items-center px-1.5 py-0.2 rounded text-[10px] font-bold bg-rose-100 text-rose-800">
                                  Removed
                                </span>
                              )}
                            </div>

                            <div
                              className="text-slate-500 text-xs truncate max-w-xs mt-0.5"
                              title={report.description}
                            >
                              {report.description || 'No additional description'}
                            </div>

                            {/* Reporter metadata snippet */}
                            <div className="text-[11px] text-slate-400 flex items-center gap-1 mt-0.5">
                              <User className="w-3 h-3 text-slate-300" />
                              <span>{report.reporter_id ? `Student #${report.reporter_id.slice(0, 6)}` : 'Campus Member'}</span>
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Category */}
                      <td className="py-3 px-3 whitespace-nowrap">
                        <CategoryBadge category={report.category} />
                      </td>

                      {/* Severity */}
                      <td className="py-3 px-3 whitespace-nowrap">
                        <SeverityBadge severity={report.severity} />
                      </td>

                      {/* Location */}
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
                          <span className="font-medium text-slate-800 bg-slate-100 px-2 py-0.5 rounded-md text-xs">
                            {assignedDeptName}
                          </span>
                        ) : report.suggested_department_label ? (
                          <span className="text-slate-400 italic text-[11px]">
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
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-rose-50 text-rose-800 border border-rose-200">
                            <span className="w-1.5 h-1.5 rounded-full bg-rose-600" />
                            Removed
                          </span>
                        ) : (
                          <StatusBadge status={report.status} />
                        )}
                      </td>

                      {/* Submitted Timestamp */}
                      <td className="py-3 px-3 whitespace-nowrap text-slate-500 text-[11px]">
                        <div>{formatRelativeTime(report.created_at)}</div>
                        <div className="text-slate-400 text-[10px]">{formatDate(report.created_at)}</div>
                      </td>

                      {/* Action buttons */}
                      <td className="py-3 px-3 text-right whitespace-nowrap">
                        <div className="inline-flex items-center gap-1.5">
                          {isAdmin && !isDeleted && (
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                setReportToDelete(report);
                              }}
                              title="Delete / Remove report"
                              className="p-1.5 text-rose-600 hover:text-rose-700 hover:bg-rose-50 border border-transparent hover:border-rose-200 rounded-lg transition"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          )}

                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              onSelectReport(report);
                            }}
                            className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-[#144D37] hover:bg-emerald-100/70 rounded-lg transition"
                          >
                            Manage
                            <ChevronRight className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>

        {/* Footer Summary / Count */}
        <div className="p-3 px-5 border-t border-slate-100 bg-slate-50 text-slate-500 text-xs flex flex-col sm:flex-row items-center justify-between gap-2">
          <div>
            Showing <span className="font-bold text-slate-800">{reports.length}</span> issues
            {hasActiveFilters && ' (filtered)'}
          </div>
          <div className="text-[11px] text-slate-400">
            Click any row to view details, assign department, or update status.
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
    </>
  );
}
