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
import { AdminSidebar, PortalSection } from '@/components/features/AdminSidebar';
import { CampusBanner } from '@/components/features/CampusBanner';
import { MetricsOverview } from '@/components/features/MetricsOverview';
import { IssueQueue } from '@/components/features/IssueQueue';
import { IssueDetailModal } from '@/components/features/IssueDetailModal';
import { DashboardView } from '@/components/features/DashboardView';
import { NoticeManagement } from '@/components/features/NoticeManagement';
import { ChallengeManagement } from '@/components/features/ChallengeManagement';
import { AnalyticsView } from '@/components/features/AnalyticsView';
import { UsersView } from '@/components/features/UsersView';
import { DepartmentsView } from '@/components/features/DepartmentsView';
import { CategoriesView } from '@/components/features/CategoriesView';
import { LocationsView } from '@/components/features/LocationsView';
import { SettingsView } from '@/components/features/SettingsView';
import { LogsView } from '@/components/features/LogsView';
import { resolveReportTitle } from '@/lib/utils';

export default function AdminDashboardPage() {
  const router = useRouter();
  const supabase = createClient();

  // Navigation tab state (default to 'issues' matching reference screenshot)
  const [activeSection, setActiveSection] = useState<PortalSection>('issues');
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);

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

        setUserEmail(session.user.email || 'aryantyagi556@gmail.com');

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
  const loadMasterData = useCallback(async () => {
    try {
      const [deptRes, buildRes] = await Promise.all([
        supabase.from('departments').select('*').order('name'),
        supabase.from('buildings').select('*').order('name'),
      ]);

      if (deptRes.data) setDepartments(deptRes.data as Department[]);
      if (buildRes.data) setBuildings(buildRes.data as Building[]);
    } catch (err) {
      console.error('Failed to load master data:', err);
    }
  }, [supabase]);

  useEffect(() => {
    if (!isAuthChecking) {
      loadMasterData();
    }
  }, [isAuthChecking, loadMasterData]);

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

      // Apply Search filter on issue_label, description, and location_details
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

  // Handle Section selection with staff role boundaries
  const handleSelectSection = useCallback((section: PortalSection) => {
    if (userRole === 'staff') {
      const allowedForStaff: PortalSection[] = ['dashboard', 'issues', 'analytics', 'settings'];
      if (!allowedForStaff.includes(section)) {
        setActiveSection('issues');
        return;
      }
    }
    setActiveSection(section);
  }, [userRole]);

  // Determine Banner Title & Subtitle based on active module & role
  const bannerInfo = React.useMemo(() => {
    const isStaff = userRole === 'staff';
    const deptName = userDepartment?.name || 'Assigned Department';

    switch (activeSection) {
      case 'dashboard':
        return {
          title: isStaff ? `${deptName} Operations Overview` : 'Campus Operations Overview',
          subtitle: isStaff
            ? `Real-time issue queue and resolution status for ${deptName}.`
            : 'Real-time performance indicators, active queues, and campus sustainability pulse.',
        };
      case 'issues':
        return {
          title: isStaff ? `${deptName} Issue Queue` : 'Campus Issue Management',
          subtitle: isStaff
            ? `Review assigned environmental reports, update progress, and log verified resolutions.`
            : 'Review, assign, and resolve student environmental reports in real time.',
        };
      case 'notices':
        return {
          title: 'Campus Notice & Alert Management',
          subtitle: 'Broadcast alerts, maintenance bulletins, and sustainability notices to student devices.',
        };
      case 'challenges':
        return {
          title: 'Custom Challenge & EcoPoints Management',
          subtitle: 'Define verifiable sustainability goals, repeat rules, and configure student EcoPoints rewards.',
        };
      case 'analytics':
        return {
          title: isStaff ? `${deptName} Analytics` : 'Campus Operational Analytics',
          subtitle: isStaff
            ? `Operational performance and resolution metrics for ${deptName}.`
            : 'Explore category distributions, building hotspots, and resolution trends.',
        };
      case 'users':
        return {
          title: 'Campus Member & Access Management',
          subtitle: 'View registered profiles, assign staff department duties, and configure access levels.',
        };
      case 'departments':
        return {
          title: 'Campus Service Departments',
          subtitle: 'Manage administrative departments and service teams assigned to campus issues.',
        };
      case 'categories':
        return {
          title: 'Issue Category Taxonomies',
          subtitle: 'Core issue classification standards matching EcoCampus PRD taxonomies.',
        };
      case 'locations':
        return {
          title: 'Campus Buildings & Floor Facilities',
          subtitle: 'Manage SRM University Sonepat academic blocks, residential towers, and floor plans.',
        };
      case 'settings':
        return {
          title: isStaff ? 'Staff Account Settings' : 'Operations Portal Configuration',
          subtitle: isStaff
            ? `Account credentials and department details for ${deptName}.`
            : 'System parameters, database connectivity, and administrative settings.',
        };
      case 'logs':
        return {
          title: 'Operational Audit Log',
          subtitle: 'Immutable record of issue status transitions, department assignments, and administrator notes.',
        };
    }
  }, [activeSection, userRole, userDepartment]);

  if (isAuthChecking) {
    return (
      <div className="min-h-screen bg-[#F8FAF8] flex items-center justify-center p-4">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 border-3 border-[#144D37] border-t-transparent rounded-full animate-spin" />
          <p className="text-xs font-bold text-slate-500 uppercase tracking-wider">
            Verifying EcoCampus Access...
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#F8FAF8] flex flex-col font-sans">
      {/* 1. Full-Width Dark Green Header matching screenshot */}
      <AdminHeader
        userEmail={userEmail}
        userRole={userRole}
        userDepartment={userDepartment}
        onSignOut={handleSignOut}
        onSelectReportId={handleSelectReportById}
        onToggleMobileSidebar={() => setIsMobileSidebarOpen(!isMobileSidebarOpen)}
      />

      {/* 2. Main Portal Container with Persistent Left Sidebar */}
      <div className="flex-1 flex w-full">
        {/* Left Sidebar */}
        <AdminSidebar
          activeSection={activeSection}
          onSelectSection={handleSelectSection}
          isOpenMobile={isMobileSidebarOpen}
          onCloseMobile={() => setIsMobileSidebarOpen(false)}
          userRole={userRole}
        />

        {/* Center / Right Content View */}
        <main className="flex-1 min-w-0 p-4 sm:p-6 lg:p-7 max-w-7xl mx-auto w-full">
          {/* Wide Campus Building Banner */}
          <CampusBanner
            title={bannerInfo.title}
            subtitle={bannerInfo.subtitle}
            eyebrow="OPERATIONS PORTAL"
            isDbConnected={true}
          />

          {/* SECTION: ISSUES (Primary Redesigned Page) */}
          {activeSection === 'issues' && (
            <>
              {/* 7 Metric Cards & Status Distribution Visualizer */}
              <MetricsOverview
                metrics={metrics}
                selectedStatus={statusFilter}
                onSelectStatus={(status) => setStatusFilter(status)}
                onViewAnalytics={() => setActiveSection('analytics')}
                isLoading={isLoadingMetrics}
              />

              {/* Search, Filter Toolbar, Table with Thumbnails & Actions */}
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

          {/* SECTION: DASHBOARD */}
          {activeSection === 'dashboard' && (
            <DashboardView
              metrics={metrics}
              reports={reports}
              departments={departments}
              onNavigateToIssues={(filter) => {
                setStatusFilter(filter || '');
                setActiveSection('issues');
              }}
              onNavigateToNotices={() => setActiveSection('notices')}
              onNavigateToAnalytics={() => setActiveSection('analytics')}
            />
          )}

          {/* SECTION: NOTICES */}
          {activeSection === 'notices' && <NoticeManagement buildings={buildings} />}

          {/* SECTION: CHALLENGES */}
          {activeSection === 'challenges' && <ChallengeManagement buildings={buildings} />}

          {/* SECTION: ANALYTICS */}
          {activeSection === 'analytics' && (
            <AnalyticsView reports={reports} buildings={buildings} metrics={metrics} />
          )}

          {/* SECTION: USERS */}
          {activeSection === 'users' && (
            <UsersView departments={departments} currentUserRole={userRole} />
          )}

          {/* SECTION: DEPARTMENTS */}
          {activeSection === 'departments' && (
            <DepartmentsView
              departments={departments}
              reports={reports}
              userRole={userRole}
              onRefresh={() => {
                loadMasterData();
                loadReports();
              }}
            />
          )}

          {/* SECTION: CATEGORIES */}
          {activeSection === 'categories' && (
            <CategoriesView
              reports={reports}
              onSelectCategoryFilter={(cat) => {
                setCategoryFilter(cat);
                setActiveSection('issues');
              }}
            />
          )}

          {/* SECTION: LOCATIONS */}
          {activeSection === 'locations' && (
            <LocationsView
              buildings={buildings}
              reports={reports}
              userRole={userRole}
              onRefresh={() => {
                loadMasterData();
                loadReports();
              }}
            />
          )}

          {/* SECTION: SETTINGS */}
          {activeSection === 'settings' && (
            <SettingsView
              userEmail={userEmail}
              userRole={userRole}
              userDepartment={userDepartment}
            />
          )}

          {/* SECTION: LOGS */}
          {activeSection === 'logs' && (
            <LogsView
              onSelectReportId={(repId) => {
                handleSelectReportById(repId);
                setActiveSection('issues');
              }}
            />
          )}
        </main>
      </div>

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
