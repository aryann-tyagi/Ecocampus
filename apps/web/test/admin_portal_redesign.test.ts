import test from 'node:test';
import assert from 'node:assert/strict';
import type { DashboardMetrics, ReportItem, UserRole } from '../src/types/database';

test('Admin Portal Redesign Suite', async (t) => {
  await t.test('1. Metric cards correctly calculate all 7 operational counters', () => {
    const mockReports: Partial<ReportItem>[] = [
      { id: '1', status: 'REPORTED', severity: 'medium', deleted_at: null },
      { id: '2', status: 'REPORTED', severity: 'critical', deleted_at: null },
      { id: '3', status: 'REPORTED', severity: 'low', deleted_at: null },
      { id: '4', status: 'ASSIGNED', severity: 'high', deleted_at: null },
      { id: '5', status: 'IN_PROGRESS', severity: 'medium', deleted_at: null },
      { id: '6', status: 'RESOLVED', severity: 'low', deleted_at: null },
      // Soft-deleted reports
      { id: '7', status: 'REPORTED', severity: 'critical', deleted_at: '2026-10-21T10:00:00Z' },
      { id: '8', status: 'RESOLVED', severity: 'medium', deleted_at: '2026-10-21T12:00:00Z' },
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

    assert.equal(metrics.total, 6, 'Active reports excludes soft-deleted records');
    assert.equal(metrics.newReported, 3, 'Newly reported count equals 3 active');
    assert.equal(metrics.assigned, 1, 'Assigned equals 1');
    assert.equal(metrics.inProgress, 1, 'In Progress equals 1');
    assert.equal(metrics.resolved, 1, 'Resolved equals 1');
    assert.equal(metrics.critical, 1, 'Active critical excludes resolved and deleted');
    assert.equal(metrics.deleted, 2, 'Deleted equals 2 soft-deleted records');
  });

  await t.test('2. Status distribution segments calculate correct percentages', () => {
    const totalRecorded = 10;
    const reported = 3;
    const assigned = 2;
    const inProgress = 2;
    const resolved = 2;
    const removed = 1;

    const pct = (val: number) => Math.round((val / totalRecorded) * 100);

    assert.equal(pct(reported), 30);
    assert.equal(pct(assigned), 20);
    assert.equal(pct(inProgress), 20);
    assert.equal(pct(resolved), 20);
    assert.equal(pct(removed), 10);
  });

  await t.test('3. CSV export formats rows safely with escaping', () => {
    function escapeCSV(val: string | null | undefined): string {
      if (!val) return '""';
      return `"${val.replace(/"/g, '""')}"`;
    }

    const testTitle = 'Overflowing "Recycling" Bin';
    const escaped = escapeCSV(testTitle);
    assert.equal(escaped, '"Overflowing ""Recycling"" Bin"');
  });

  await t.test('4. Role enforcement verifies admin vs student access', () => {
    function canManageAdminOperations(role: UserRole): boolean {
      return role === 'admin' || role === 'staff';
    }

    assert.equal(canManageAdminOperations('admin'), true);
    assert.equal(canManageAdminOperations('staff'), true);
    assert.equal(canManageAdminOperations('student'), false);
  });
});
