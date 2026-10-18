import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';
import type { IssueCategory, IssueSeverity, ReportStatus } from '../types/database';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(dateString: string | null | undefined): string {
  if (!dateString) return '—';
  try {
    const d = new Date(dateString);
    if (isNaN(d.getTime())) return dateString;
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    }).format(d);
  } catch {
    return dateString;
  }
}

export function formatRelativeTime(dateString: string | null | undefined): string {
  if (!dateString) return '—';
  try {
    const d = new Date(dateString);
    const now = new Date();
    const diffSec = Math.floor((now.getTime() - d.getTime()) / 1000);
    if (diffSec < 60) return 'Just now';
    const diffMin = Math.floor(diffSec / 60);
    if (diffMin < 60) return `${diffMin}m ago`;
    const diffHours = Math.floor(diffMin / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    const diffDays = Math.floor(diffHours / 24);
    if (diffDays < 7) return `${diffDays}d ago`;
    return formatDate(dateString);
  } catch {
    return dateString;
  }
}

export function getCategoryBadge(category: IssueCategory) {
  switch (category) {
    case 'waste':
      return { label: 'Waste', bg: 'bg-emerald-50 text-emerald-700 border-emerald-200' };
    case 'water':
      return { label: 'Water', bg: 'bg-blue-50 text-blue-700 border-blue-200' };
    case 'electricity':
      return { label: 'Energy', bg: 'bg-amber-50 text-amber-700 border-amber-200' };
    case 'infrastructure':
      return { label: 'Infrastructure', bg: 'bg-orange-50 text-orange-700 border-orange-200' };
    case 'greenery':
      return { label: 'Greenery', bg: 'bg-teal-50 text-teal-700 border-teal-200' };
    case 'cleanliness':
      return { label: 'Cleanliness', bg: 'bg-cyan-50 text-cyan-700 border-cyan-200' };
    case 'other':
    default:
      return { label: 'Other', bg: 'bg-slate-50 text-slate-700 border-slate-200' };
  }
}

export function getSeverityBadge(severity: IssueSeverity) {
  switch (severity) {
    case 'low':
      return { label: 'Low', bg: 'bg-slate-100 text-slate-700 border-slate-200', dot: 'bg-slate-500' };
    case 'medium':
      return { label: 'Medium', bg: 'bg-amber-50 text-amber-800 border-amber-200', dot: 'bg-amber-500' };
    case 'high':
      return { label: 'High', bg: 'bg-orange-50 text-orange-800 border-orange-200', dot: 'bg-orange-500' };
    case 'critical':
      return { label: 'Critical', bg: 'bg-rose-50 text-rose-800 border-rose-200', dot: 'bg-rose-600' };
    default:
      return { label: severity, bg: 'bg-slate-100 text-slate-700 border-slate-200', dot: 'bg-slate-400' };
  }
}

export function getStatusBadge(status: ReportStatus) {
  switch (status) {
    case 'REPORTED':
      return { label: 'Reported', bg: 'bg-amber-50 text-amber-800 border-amber-200', dot: 'bg-amber-500' };
    case 'ASSIGNED':
      return { label: 'Assigned', bg: 'bg-blue-50 text-blue-800 border-blue-200', dot: 'bg-blue-500' };
    case 'IN_PROGRESS':
      return { label: 'In Progress', bg: 'bg-purple-50 text-purple-800 border-purple-200', dot: 'bg-purple-500' };
    case 'RESOLVED':
      return { label: 'Resolved', bg: 'bg-emerald-50 text-emerald-800 border-emerald-200', dot: 'bg-emerald-600' };
    default:
      return { label: status, bg: 'bg-slate-100 text-slate-700 border-slate-200', dot: 'bg-slate-400' };
  }
}

export interface ReportTitleContext {
  title?: string | null;
  issue_label?: string | null;
  description?: string | null;
  category?: IssueCategory | string | null;
  buildings?: { name?: string | null } | null;
}

/**
 * Resolves the issue report title with strict 4-tier fallback:
 * 1. Saved title / issue_label if non-empty (and not 'Unnamed').
 * 2. Derived temporary display title from description (first sentence, max 60 chars).
 * 3. Truthful neutral label derived from category and building (e.g. 'Water issue — Boys Hostel').
 * 4. Truthful fallback: 'Untitled report' (never 'Unnamed').
 */
export function resolveReportTitle(report: ReportTitleContext): string {
  // 1. Use the existing title / issue_label if non-empty
  const rawTitle = (report.title ?? report.issue_label ?? '').trim();
  if (rawTitle.length > 0 && rawTitle.toLowerCase() !== 'unnamed') {
    return rawTitle;
  }

  // 2. Otherwise, derive a temporary display title from the existing description
  const rawDesc = (report.description ?? '').trim();
  if (rawDesc.length > 0) {
    const firstSentence = rawDesc.split(/[.\n]/)[0].trim();
    if (firstSentence.length > 0) {
      return firstSentence.length > 60
        ? `${firstSentence.slice(0, 57)}...`
        : firstSentence;
    }
  }

  // 3. Truthful neutral label derived from category and building
  const categoryLabel = report.category
    ? `${report.category.charAt(0).toUpperCase()}${report.category.slice(1)} issue`
    : 'Campus issue';
  const buildingName = report.buildings?.name?.trim();
  if (buildingName) {
    return `${categoryLabel} — ${buildingName}`;
  }

  // 4. Safe truthful fallback
  return 'Untitled report';
}

export function getNoticeTypeBadge(type: string) {
  switch (type) {
    case 'issue_notice':
      return { label: 'Issue Notice', bg: 'bg-rose-50 text-rose-700 border-rose-200' };
    case 'campus_announcement':
      return { label: 'Announcement', bg: 'bg-emerald-50 text-emerald-700 border-emerald-200' };
    case 'maintenance_update':
      return { label: 'Maintenance', bg: 'bg-amber-50 text-amber-700 border-amber-200' };
    case 'utility_notice':
      return { label: 'Utility (Water/Power)', bg: 'bg-blue-50 text-blue-700 border-blue-200' };
    case 'safety_notice':
      return { label: 'Safety Alert', bg: 'bg-red-50 text-red-700 border-red-200' };
    case 'general_notice':
    default:
      return { label: 'General', bg: 'bg-slate-50 text-slate-700 border-slate-200' };
  }
}

export function getNoticePriorityBadge(priority: string) {
  switch (priority) {
    case 'urgent':
      return { label: 'Urgent', bg: 'bg-rose-100 text-rose-800 border-rose-300', dot: 'bg-rose-600' };
    case 'important':
      return { label: 'Important', bg: 'bg-amber-100 text-amber-800 border-amber-300', dot: 'bg-amber-500' };
    case 'normal':
    default:
      return { label: 'Normal', bg: 'bg-slate-100 text-slate-700 border-slate-200', dot: 'bg-slate-400' };
  }
}

export function getNoticeStatusBadge(status: string) {
  switch (status) {
    case 'published':
      return { label: 'Published', bg: 'bg-emerald-50 text-emerald-800 border-emerald-200', dot: 'bg-emerald-600' };
    case 'archived':
      return { label: 'Archived', bg: 'bg-slate-100 text-slate-600 border-slate-200', dot: 'bg-slate-400' };
    case 'draft':
    default:
      return { label: 'Draft', bg: 'bg-amber-50 text-amber-800 border-amber-200', dot: 'bg-amber-500' };
  }
}

export function getChallengeTypeBadge(type: string) {
  switch (type) {
    case 'report_issue':
      return { label: 'Report Issue', bg: 'bg-emerald-50 text-emerald-700 border-emerald-200' };
    case 'category_reporting':
      return { label: 'Category Target', bg: 'bg-blue-50 text-blue-700 border-blue-200' };
    case 'building_reporting':
      return { label: 'Building Target', bg: 'bg-purple-50 text-purple-700 border-purple-200' };
    case 'multiple_reports':
      return { label: 'Multiple Reports', bg: 'bg-indigo-50 text-indigo-700 border-indigo-200' };
    default:
      return { label: type, bg: 'bg-slate-50 text-slate-700 border-slate-200' };
  }
}

export function getChallengeRecurrenceBadge(recurrence: string) {
  switch (recurrence) {
    case 'daily':
      return { label: 'Daily', bg: 'bg-teal-50 text-teal-800 border-teal-200' };
    case 'weekly':
      return { label: 'Weekly', bg: 'bg-cyan-50 text-cyan-800 border-cyan-200' };
    case 'one_time':
    default:
      return { label: 'One-Time', bg: 'bg-slate-100 text-slate-700 border-slate-200' };
  }
}
