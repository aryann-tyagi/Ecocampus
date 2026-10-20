'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import {
  ReportItem,
  Department,
  Building,
  DashboardMetrics,
  UserRole,
} from '@/types/database';
import { AdminHeader } from '@/components/features/AdminHeader';
import { MetricsOverview } from '@/components/features/MetricsOverview';
import { IssueQueue } from '@/components/features/IssueQueue';
import { IssueDetailModal } from '@/components/features/IssueDetailModal';
import { NoticeManagement } from '@/components/features/NoticeManagement';
import { ChallengeManagement } from '@/components/features/ChallengeManagement';
import { resolveReportTitle, cn } from '@/lib/utils';
import { Layers, Megaphone, Trophy } from 'lucide-react';

export default function AdminDashboardPage() {
  const router = useRouter();
  const supabase = createClient();

  // Navigation tab state
  const [activeSection, setActiveSection] = useState<'issues' | 'notices' | 'challenges'>('issues');

  // Auth & Session state
  const [isAuthChecking, setIsAuthChecking] = useState(true);
  const [userEmail, setUserEmail] = useState('');
  const [userRole, setUserRole] = useState<UserRole>('student');
  const [userDepartment, setUserDepartment] = useState<Department | null>(null);

  // Data state
  const [reports, setReports] = useState<ReportItem[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [buildings, setBuildings] = useState<Building[]>([]);
  const [metrics, setMetrics] = useState<DashboardMetrics>({
    total: 0,
    newReported: 0,
    assigned: 0,
    inProgress: 0,
    resolved: 0,
    critical: 0,
    deleted: 0,
  });

  const [isLoadingReports, setIsLoadingReports] = useState(true);
  const [isLoadingMetrics, setIsLoadingMetrics] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Selected report for modal
  const [selectedReport, setSelectedReport] = useState<ReportItem | null>(null);

  // Filters state
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [severityFilter, setSeverityFilter] = useState('');
  const [buildingFilter, setBuildingFilter] = useState('');
  const [departmentFilter, setDepartmentFilter] = useState('');

  // 1. Authenticate and verify role
  useEffect(() => {
    async function checkAuth() {
      try {
        const {
          data: { session },
        } = await supabase.auth.getSession();

        if (!session?.user) {
          router.replace('/login');
          return;
        }

        setUserEmail(session.user.email || 'Authenticated User');

        // Query role from user_roles
        const { data: roleRow } = await supabase
          .from('user_roles')
          .select('role, department_id, departments(*)')
          .eq('user_id', session.user.id)
          .maybeSingle();

        const role = (roleRow?.role as UserRole) || 'student';

        if (role !== 'admin' && role !== 'staff') {
          router.replace('/unauthorized');
          return;
        }

        setUserRole(role);
        if (roleRow?.departments) {
          setUserDepartment(roleRow.departments as unknown as Department);
        }

        setIsAuthChecking(false);
      } catch (err) {
        console.error('Auth verification error:', err);
        router.replace('/login');
      }
    }

    checkAuth();
  }, [router, supabase]);

  // 2. Load static reference data (departments & buildings)
  useEffect(() => {
    if (isAuthChecking) return;

    async function loadMasterData() {
      try {
        const [deptRes, buildRes] = await Promise.all([
          supabase.from('departments').select('*').eq('active', true).order('name'),
          supabase.from('buildings').select('*').eq('active', true).order('name'),
        ]);

        if (deptRes.data) setDepartments(deptRes.data as Department[]);
        if (buildRes.data) setBuildings(buildRes.data as Building[]);
      } catch (err) {
        console.error('Failed to load master data:', err);
      }
    }

    loadMasterData();
  }, [isAuthChecking, supabase]);

  // 3. Fetch summary metrics derived from real database data
  const loadMetrics = useCallback(async () => {
    if (isAuthChecking) return;
    setIsLoadingMetrics(true);

    try {
      // Query counts per status, differentiating active from soft-deleted
      const [
        totalRes,
        reportedRes,
        assignedRes,
        progressRes,
        resolvedRes,
        criticalRes,
        deletedRes,
      ] = await Promise.all([
        supabase.from('reports').select('id', { count: 'exact', head: true }).is('deleted_at', null),
        supabase.from('reports').select('id', { count: 'exact', head: true }).is('deleted_at', null).eq('status', 'REPORTED'),
        supabase.from('reports').select('id', { count: 'exact', head: true }).is('deleted_at', null).eq('status', 'ASSIGNED'),
        supabase.from('reports').select('id', { count: 'exact', head: true }).is('deleted_at', null).eq('status', 'IN_PROGRESS'),
        supabase.from('reports').select('id', { count: 'exact', head: true }).is('deleted_at', null).eq('status', 'RESOLVED'),
        supabase
          .from('reports')
          .select('id', { count: 'exact', head: true })
          .is('deleted_at', null)
          .eq('severity', 'critical')
          .neq('status', 'RESOLVED'),
        supabase.from('reports').select('id', { count: 'exact', head: true }).not('deleted_at', 'is', null),
      ]);

      setMetrics({
        total: totalRes.count || 0,
        newReported: reportedRes.count || 0,
        assigned: assignedRes.count || 0,
        inProgress: progressRes.count || 0,
        resolved: resolvedRes.count || 0,
        critical: criticalRes.count || 0,
        deleted: deletedRes.count || 0,
      });
    } catch (err) {
      console.error('Failed to load metrics:', err);
    } finally {
      setIsLoadingMetrics(false);
    }
  }, [isAuthChecking, supabase]);

  // 4. Fetch filtered queue reports
  const loadReports = useCallback(async () => {
    if (isAuthChecking) return;
    setIsLoadingReports(true);
    setError(null);

    try {
      let query = supabase
        .from('reports')
        .select(`
          *,
          title:issue_label,
          buildings(id, name, slug),
          floors(id, label),
          assigned_department:departments!reports_assigned_department_id_fkey(id, name, slug),
          suggested_department:departments!reports_suggested_department_id_fkey(id, name, slug),
          report_media(id, storage_path, mime_type, position)
        `)
        .order('created_at', { ascending: false })
        .limit(100);

      // Apply Soft-Deletion filter vs Active Queue
      if (statusFilter === 'REMOVED') {
        query = query.not('deleted_at', 'is', null);
      } else if (statusFilter === 'ALL_WITH_REMOVED') {
        // Do not filter on deleted_at
      } else {
        // Standard admin queue shows active non-deleted issues
        query = query.is('deleted_at', null);

        // Apply Status filter (or custom critical shortcut)
        if (statusFilter === 'CRITICAL') {
          query = query.eq('severity', 'critical').neq('status', 'RESOLVED');
        } else if (statusFilter) {
          query = query.eq('status', statusFilter);
        }
      }

      // Apply Category filter
      if (categoryFilter) {
        query = query.eq('category', categoryFilter);
      }

      // Apply Severity filter
      if (severityFilter && statusFilter !== 'CRITICAL') {
        query = query.eq('severity', severityFilter);
      }

      // Apply Building filter
      if (buildingFilter) {
        query = query.eq('building_id', buildingFilter);
      }

      // Apply Department filter
      if (departmentFilter) {
        query = query.eq('assigned_department_id', departmentFilter);
      }

      // Apply Search filter on issue_label (the database column), description, and location_details
      if (searchQuery.trim()) {
        const q = searchQuery.trim();
        query = query.or(`issue_label.ilike.%${q}%,description.ilike.%${q}%,location_details.ilike.%${q}%`);
      }

      const { data, error: queryError } = await query;

      if (queryError) {
        setError(queryError.message || 'Failed to fetch reports.');
        return;
      }

      const mappedReports = ((data as unknown as ReportItem[]) || []).map((row) => ({
        ...row,
        title: resolveReportTitle(row),
      }));

      setReports(mappedReports);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'An error occurred while loading reports.');
    } finally {
      setIsLoadingReports(false);
    }
  }, [
    isAuthChecking,
    supabase,
    statusFilter,
    categoryFilter,
    severityFilter,
    buildingFilter,
    departmentFilter,
    searchQuery,
  ]);

  useEffect(() => {
    let cancelled = false;
    async function initMetrics() {
      await Promise.resolve();
      if (!cancelled) {
        await loadMetrics();
      }
    }
    void initMetrics();
    return () => {
      cancelled = true;
    };
  }, [loadMetrics]);

  useEffect(() => {
    let cancelled = false;
    async function initReports() {
      await Promise.resolve();
      if (!cancelled) {
        await loadReports();
      }
    }
    void initReports();
    return () => {
      cancelled = true;
    };
  }, [loadReports]);

  function handleResetFilters() {
    setSearchQuery('');
    setStatusFilter('');
    setCategoryFilter('');
    setSeverityFilter('');
    setBuildingFilter('');
    setDepartmentFilter('');
  }

  async function handleSignOut() {
    await supabase.auth.signOut();
    router.replace('/login');
  }

  // Refreshes both queue and metrics when an issue is updated
  const handleReportUpdated = useCallback(
    async (updatedReportId: string) => {
      await Promise.all([loadMetrics(), loadReports()]);

      // Refresh currently open modal item if open
      if (selectedReport && selectedReport.id === updatedReportId) {
        const { data } = await supabase
          .from('reports')
          .select(`
            *,
            title:issue_label,
            buildings(id, name, slug),
            floors(id, label),
            assigned_department:departments!reports_assigned_department_id_fkey(id, name, slug),
            suggested_department:departments!reports_suggested_department_id_fkey(id, name, slug),
            report_media(id, storage_path, mime_type, position)
          `)
          .eq('id', updatedReportId)
          .single();

        if (data) {
          const row = data as unknown as ReportItem;
          setSelectedReport({
            ...row,
            title: resolveReportTitle(row),
          });
        }
      }
    },
    [loadMetrics, loadReports, selectedReport, supabase]
  );

  const handleSelectReportById = useCallback(
    async (reportId: string) => {
      const existing = reports.find((r) => r.id === reportId);
      if (existing) {
        setSelectedReport(existing);
        return;
      }
      const { data } = await supabase
        .from('reports')
        .select(`
          *,
          title:issue_label,
          buildings(id, name, slug),
          floors(id, label),
          assigned_department:departments!reports_assigned_department_id_fkey(id, name, slug),
          suggested_department:departments!reports_suggested_department_id_fkey(id, name, slug),
          report_media(id, report_id, storage_path, mime_type, position, created_at),
          report_status_events(id, report_id, from_status, to_status, actor_id, note, occurred_at)
        `)
        .eq('id', reportId)
        .maybeSingle();

      if (data) {
        const row = data as unknown as ReportItem;
        setSelectedReport({
          ...row,
          title: resolveReportTitle(row),
        });
      }
    },
    [reports, supabase]
  );

  if (isAuthChecking) {
    return (
      <div className="min-h-screen bg-[#F8FAF8] flex items-center justify-center p-4">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 border-3 border-[#144D37] border-t-transparent rounded-full animate-spin" />
          <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Verifying EcoCampus Access...
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#F8FAF8] flex flex-col">
      {/* Top Navbar */}
      <AdminHeader
        userEmail={userEmail}
        userRole={userRole}
        userDepartment={userDepartment}
        activeSection={activeSection}
        onSectionChange={setActiveSection}
        onSignOut={handleSignOut}
        onSelectReportId={handleSelectReportById}
      />

      {/* Main Container */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6 lg:p-8">
        {/* Mobile Sub-Navigation Bar */}
        <div className="flex md:hidden items-center gap-1 bg-white p-1.5 rounded-2xl border border-slate-200 mb-5 shadow-sm">
          <button
            onClick={() => setActiveSection('issues')}
            className={cn(
              'flex-1 flex items-center justify-center gap-1.5 py-2 rounded-xl text-xs font-bold transition-all',
              activeSection === 'issues'
                ? 'bg-emerald-700 text-white shadow-sm'
                : 'text-slate-600 hover:bg-slate-100'
            )}
          >
            <Layers className="w-3.5 h-3.5" />
            Issues
          </button>

          {userRole === 'admin' && (
            <>
              <button
                onClick={() => setActiveSection('notices')}
                className={cn(
                  'flex-1 flex items-center justify-center gap-1.5 py-2 rounded-xl text-xs font-bold transition-all',
                  activeSection === 'notices'
                    ? 'bg-emerald-700 text-white shadow-sm'
                    : 'text-slate-600 hover:bg-slate-100'
                )}
              >
                <Megaphone className="w-3.5 h-3.5" />
                Notices
              </button>

              <button
                onClick={() => setActiveSection('challenges')}
                className={cn(
                  'flex-1 flex items-center justify-center gap-1.5 py-2 rounded-xl text-xs font-bold transition-all',
                  activeSection === 'challenges'
                    ? 'bg-emerald-700 text-white shadow-sm'
                    : 'text-slate-600 hover:bg-slate-100'
                )}
              >
                <Trophy className="w-3.5 h-3.5" />
                Challenges
              </button>
            </>
          )}
        </div>

        {/* Section Header */}
        <div className="mb-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
          <div>
            <h1 className="text-2xl font-black text-slate-900 tracking-tight">
              {activeSection === 'issues'
                ? 'Campus Issue Management'
                : activeSection === 'notices'
                ? 'Campus Notice & Announcement Management'
                : 'Custom Challenge & EcoPoints Management'}
            </h1>
            <p className="text-xs text-slate-500 mt-0.5">
              {activeSection === 'issues'
                ? 'Review, assign, and resolve student environmental reports in real time.'
                : activeSection === 'notices'
                ? 'Create, edit, draft, preview, and broadcast campus notices and alerts to student devices.'
                : 'Define verifiable sustainability goals, repeat rules, and configure exact student EcoPoints rewards.'}
            </p>
          </div>

          <div className="flex items-center gap-2 text-xs font-medium text-slate-500 self-start sm:self-auto bg-white px-3 py-1.5 rounded-xl border border-slate-200">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Database Live Connection</span>
          </div>
        </div>

        {/* SECTION 1: ISSUES QUEUE */}
        {activeSection === 'issues' && (
          <>
            {/* Real-time Summary Metrics */}
            <MetricsOverview
              metrics={metrics}
              selectedStatus={statusFilter}
              onSelectStatus={(status) => setStatusFilter(status)}
              isLoading={isLoadingMetrics}
            />

            {/* Issue Management Queue */}
            <IssueQueue
              reports={reports}
              departments={departments}
              buildings={buildings}
              selectedReportId={selectedReport?.id || null}
              onSelectReport={(report) => setSelectedReport(report)}
              isLoading={isLoadingReports}
              error={error}
              userRole={userRole}
              onRefresh={() => {
                loadMetrics();
                loadReports();
              }}
              searchQuery={searchQuery}
              onSearchChange={setSearchQuery}
              statusFilter={statusFilter}
              onStatusFilterChange={setStatusFilter}
              categoryFilter={categoryFilter}
              onCategoryFilterChange={setCategoryFilter}
              severityFilter={severityFilter}
              onSeverityFilterChange={setSeverityFilter}
              buildingFilter={buildingFilter}
              onBuildingFilterChange={setBuildingFilter}
              departmentFilter={departmentFilter}
              onDepartmentFilterChange={setDepartmentFilter}
              onResetFilters={handleResetFilters}
            />
          </>
        )}

        {/* SECTION 2: CAMPUS NOTICES */}
        {activeSection === 'notices' && (
          <NoticeManagement buildings={buildings} />
        )}

        {/* SECTION 3: CUSTOM CHALLENGES */}
        {activeSection === 'challenges' && (
          <ChallengeManagement buildings={buildings} />
        )}
      </main>

      {/* Detail / Action Modal Drawer */}
      {selectedReport && (
        <IssueDetailModal
          report={selectedReport}
          departments={departments}
          userRole={userRole}
          userDepartmentId={userDepartment?.id || null}
          onClose={() => setSelectedReport(null)}
          onReportUpdated={handleReportUpdated}
        />
      )}
    </div>
  );
}
