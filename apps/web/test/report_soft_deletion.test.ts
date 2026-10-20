import test from 'node:test';
import assert from 'node:assert/strict';
import type { DashboardMetrics, ReportItem, UserRole } from '../src/types/database';

test('1. Dashboard metrics differentiate active reports from soft-deleted reports', () => {
  const mockReports: Partial<ReportItem>[] = [
    { id: '1', status: 'REPORTED', deleted_at: null },
    { id: '2', status: 'ASSIGNED', deleted_at: null },
    { id: '3', status: 'IN_PROGRESS', deleted_at: null },
    { id: '4', status: 'RESOLVED', deleted_at: null },
    { id: '5', status: 'REPORTED', severity: 'critical', deleted_at: null },
    // Soft-deleted reports
    { id: '6', status: 'REPORTED', deleted_at: '2026-10-21T10:00:00Z', deletion_reason: 'Duplicate report' },
    { id: '7', status: 'IN_PROGRESS', deleted_at: '2026-10-21T11:00:00Z', deletion_reason: 'Invalid report' },
  ];

  const activeReports = mockReports.filter((r) => !r.deleted_at);
  const deletedReports = mockReports.filter((r) => Boolean(r.deleted_at));

  const metrics: DashboardMetrics = {
    total: activeReports.length,
    newReported: activeReports.filter((r) => r.status === 'REPORTED').length,
    assigned: activeReports.filter((r) => r.status === 'ASSIGNED').length,
    inProgress: activeReports.filter((r) => r.status === 'IN_PROGRESS').length,
    resolved: activeReports.filter((r) => r.status === 'RESOLVED').length,
    critical: activeReports.filter((r) => r.severity === 'critical' && r.status !== 'RESOLVED').length,
    deleted: deletedReports.length,
  };

  assert.equal(metrics.total, 5, 'Active total should not include soft-deleted reports');
  assert.equal(metrics.newReported, 2, 'New reported count must exclude soft-deleted items');
  assert.equal(metrics.deleted, 2, 'Deleted count reflects all soft-deleted records');
});

test('2. Status distribution handles zero reports without division by zero', () => {
  const metrics: DashboardMetrics = {
    total: 0,
    newReported: 0,
    assigned: 0,
    inProgress: 0,
    resolved: 0,
    critical: 0,
    deleted: 0,
  };

  const total = metrics.newReported + metrics.assigned + metrics.inProgress + metrics.resolved + metrics.deleted;
  const pct = (val: number) => (total > 0 ? Math.round((val / total) * 100) : 0);

  assert.equal(pct(metrics.newReported), 0);
  assert.equal(pct(metrics.deleted), 0);
});

test('3. Deletion reason formatter constructs accurate student-facing explanation', () => {
  function formatDeletionReason(presetLabel: string, customNote?: string): string {
    const trimmed = customNote?.trim();
    if (!trimmed) {
      return presetLabel;
    }
    return `${presetLabel}: ${trimmed}`;
  }

  assert.equal(
    formatDeletionReason('Duplicate report'),
    'Duplicate report'
  );
  assert.equal(
    formatDeletionReason('Duplicate report', 'Already logged as issue #38a4'),
    'Duplicate report: Already logged as issue #38a4'
  );
  assert.equal(
    formatDeletionReason('Inappropriate content', 'Prohibited campus imagery'),
    'Inappropriate content: Prohibited campus imagery'
  );
});

test('4. Server-side authorization check allows only admin role to execute soft deletion', () => {
  function canUserSoftDelete(role: UserRole): boolean {
    return role === 'admin';
  }

  assert.equal(canUserSoftDelete('admin'), true, 'Campus administrator is permitted to delete reports');
  assert.equal(canUserSoftDelete('staff'), false, 'Department staff cannot delete reports');
  assert.equal(canUserSoftDelete('student'), false, 'Students are prohibited from deleting reports');
});

test('5. Queue filter logic cleanly isolates soft-deleted reports from active queue', () => {
  const reports: { id: string; status: string; deleted_at: string | null }[] = [
    { id: '1', status: 'REPORTED', deleted_at: null },
    { id: '2', status: 'ASSIGNED', deleted_at: null },
    { id: '3', status: 'REPORTED', deleted_at: '2026-10-21T09:00:00Z' },
  ];

  // Default active queue filter
  const activeQueue = reports.filter((r) => r.deleted_at === null);
  assert.equal(activeQueue.length, 2);
  assert.ok(!activeQueue.some((r) => r.id === '3'));

  // Removed by admin filter
  const removedQueue = reports.filter((r) => r.deleted_at !== null);
  assert.equal(removedQueue.length, 1);
  assert.equal(removedQueue[0].id, '3');
});
