import React from 'react';
import { IssueCategory, IssueSeverity, ReportStatus } from '@/types/database';
import { getCategoryBadge, getSeverityBadge, getStatusBadge, cn } from '@/lib/utils';

export function CategoryBadge({ category, className }: { category: IssueCategory; className?: string }) {
  const badge = getCategoryBadge(category);
  return (
    <span
      className={cn(
        'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border',
        badge.bg,
        className
      )}
    >
      {badge.label}
    </span>
  );
}

export function SeverityBadge({ severity, className }: { severity: IssueSeverity; className?: string }) {
  const badge = getSeverityBadge(severity);
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold border',
        badge.bg,
        className
      )}
    >
      <span className={cn('w-1.5 h-1.5 rounded-full', badge.dot)} />
      {badge.label}
    </span>
  );
}

export function StatusBadge({ status, className }: { status: ReportStatus; className?: string }) {
  const badge = getStatusBadge(status);
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold border',
        badge.bg,
        className
      )}
    >
      <span className={cn('w-1.5 h-1.5 rounded-full', badge.dot)} />
      {badge.label}
    </span>
  );
}
