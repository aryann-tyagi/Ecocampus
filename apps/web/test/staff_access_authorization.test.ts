import test from 'node:test';
import assert from 'node:assert/strict';
import type { UserRole, Department } from '../src/types/database';
import type { PortalSection } from '../src/components/features/AdminSidebar';

// 1. Authorized Staff Allowlist Logic Verification
interface StaffAllowlistEntry {
  email: string;
  departmentSlug: string;
  active: boolean;
}

const AUTHORIZED_ALLOWLIST: StaffAllowlistEntry[] = [
  {
    email: 'staff@university.edu',
    departmentSlug: 'housekeeping-waste',
    active: true,
  },
];

function isEmailAuthorizedForStaff(email: string): StaffAllowlistEntry | null {
  const normalized = email.trim().toLowerCase();
  const found = AUTHORIZED_ALLOWLIST.find(
    (e) => e.email.toLowerCase() === normalized && e.active
  );
  return found || null;
}

test('1. Allowlist authorizes ONLY the specific staff email', () => {
  assert.ok(isEmailAuthorizedForStaff('staff@university.edu'));
  assert.ok(isEmailAuthorizedForStaff('STAFF@UNIVERSITY.EDU'));
  assert.ok(isEmailAuthorizedForStaff('  staff@university.edu  '));

  // Unauthorized emails
  assert.equal(isEmailAuthorizedForStaff('student@university.edu'), null);
  assert.equal(isEmailAuthorizedForStaff('admin@university.edu'), null);
  assert.equal(isEmailAuthorizedForStaff('attacker@gmail.com'), null);
  assert.equal(isEmailAuthorizedForStaff('staff2@university.edu'), null);
  assert.equal(isEmailAuthorizedForStaff(''), null);
});

// 2. Provisioning & Role Association
test('2. Automatic role provisioning assigns staff role and correct department to authorized email', () => {
  function provisionRoleForNewUser(email: string): { role: UserRole; departmentSlug: string | null } {
    const allowlistEntry = isEmailAuthorizedForStaff(email);
    if (allowlistEntry) {
      return {
        role: 'staff',
        departmentSlug: allowlistEntry.departmentSlug,
      };
    }
    return {
      role: 'student',
      departmentSlug: null,
    };
  }

  const staffResult = provisionRoleForNewUser('staff@university.edu');
  assert.equal(staffResult.role, 'staff');
  assert.equal(staffResult.departmentSlug, 'housekeeping-waste');

  const studentResult = provisionRoleForNewUser('student@university.edu');
  assert.equal(studentResult.role, 'student');
  assert.equal(studentResult.departmentSlug, null);
});

// 3. Prevention of Privilege Escalation
test('3. Non-allowlisted users cannot acquire staff role via role assignment triggers', () => {
  function validateStaffRoleAssignment(userEmail: string, targetRole: UserRole): { success: boolean; error?: string } {
    if (targetRole === 'staff') {
      const allowed = isEmailAuthorizedForStaff(userEmail);
      if (!allowed) {
        return {
          success: false,
          error: `Access denied. Email ${userEmail} is not authorized for EcoCampus staff access.`,
        };
      }
    }
    return { success: true };
  }

  const authorized = validateStaffRoleAssignment('staff@university.edu', 'staff');
  assert.equal(authorized.success, true);

  const unauthorizedStudent = validateStaffRoleAssignment('student@university.edu', 'staff');
  assert.equal(unauthorizedStudent.success, false);
  assert.match(unauthorizedStudent.error!, /Access denied.*not authorized/);

  const randomUser = validateStaffRoleAssignment('john.doe@gmail.com', 'staff');
  assert.equal(randomUser.success, false);
});

// 4. Portal Route Guards
test('4. Route guard permits only Admin and Authorized Staff into operations portal', () => {
  function canAccessOperationsPortal(role: UserRole): boolean {
    return role === 'admin' || role === 'staff';
  }

  assert.equal(canAccessOperationsPortal('admin'), true, 'Admins can access portal');
  assert.equal(canAccessOperationsPortal('staff'), true, 'Staff can access portal');
  assert.equal(canAccessOperationsPortal('student'), false, 'Students are denied portal access');
});

// 5. Department-Level RLS & Action Isolation
test('5. Department staff is restricted to their assigned department reports and actions', () => {
  const housekeepingDeptId = 'dept-uuid-housekeeping-waste';
  const plumbingDeptId = 'dept-uuid-plumbing-facilities';

  const staffUser = {
    id: 'staff-uuid-1',
    role: 'staff' as UserRole,
    departmentId: housekeepingDeptId,
  };

  const housekeepingReport = {
    id: 'rep-001',
    assignedDepartmentId: housekeepingDeptId,
    status: 'ASSIGNED',
  };

  const plumbingReport = {
    id: 'rep-002',
    assignedDepartmentId: plumbingDeptId,
    status: 'ASSIGNED',
  };

  // 5a. Read Access (RLS Simulation)
  function canStaffReadReport(user: typeof staffUser, report: typeof housekeepingReport): boolean {
    if (user.role === 'admin') return true;
    if (user.role === 'staff' && report.assignedDepartmentId === user.departmentId) return true;
    return false;
  }

  assert.equal(canStaffReadReport(staffUser, housekeepingReport), true, 'Staff can read own department reports');
  assert.equal(canStaffReadReport(staffUser, plumbingReport), false, 'Staff cannot read other department reports');

  // 5b. Transition Mutation Access (RPC Simulation)
  function canStaffTransitionReport(
    user: typeof staffUser,
    report: typeof housekeepingReport,
    newStatus: string
  ): { allowed: boolean; reason?: string } {
    if (report.assignedDepartmentId !== user.departmentId) {
      return { allowed: false, reason: 'Access denied. You can only manage issues assigned to your department.' };
    }
    // Allowed staff transitions: ASSIGNED -> IN_PROGRESS, IN_PROGRESS -> RESOLVED
    if (
      (report.status === 'ASSIGNED' && newStatus === 'IN_PROGRESS') ||
      (report.status === 'IN_PROGRESS' && newStatus === 'RESOLVED')
    ) {
      return { allowed: true };
    }
    return { allowed: false, reason: `Invalid status transition for staff: ${report.status} to ${newStatus}` };
  }

  const validWork = canStaffTransitionReport(staffUser, housekeepingReport, 'IN_PROGRESS');
  assert.equal(validWork.allowed, true);

  const crossDeptAttempt = canStaffTransitionReport(staffUser, plumbingReport, 'IN_PROGRESS');
  assert.equal(crossDeptAttempt.allowed, false);
  assert.match(crossDeptAttempt.reason!, /only manage issues assigned to your department/);

  // 5c. Admin-only actions denied to Staff
  function canAssignDepartment(userRole: UserRole): boolean {
    return userRole === 'admin';
  }
  function canSoftDeleteReport(userRole: UserRole): boolean {
    return userRole === 'admin';
  }

  assert.equal(canAssignDepartment(staffUser.role), false, 'Staff cannot reassign departments');
  assert.equal(canSoftDeleteReport(staffUser.role), false, 'Staff cannot delete reports');
  assert.equal(canAssignDepartment('admin'), true, 'Admin can reassign departments');
  assert.equal(canSoftDeleteReport('admin'), true, 'Admin can delete reports');
});

// 6. Navigation Boundaries
test('6. Staff navigation excludes admin management modules', () => {
  function getSidebarSectionsForRole(role: UserRole): PortalSection[] {
    if (role === 'staff') {
      return ['dashboard', 'issues', 'analytics', 'settings'];
    }
    return [
      'dashboard', 'issues', 'notices', 'challenges', 'analytics',
      'users', 'departments', 'categories', 'locations', 'settings', 'logs'
    ];
  }

  const staffSections = getSidebarSectionsForRole('staff');
  assert.ok(staffSections.includes('dashboard'));
  assert.ok(staffSections.includes('issues'));
  assert.ok(staffSections.includes('analytics'));
  assert.ok(staffSections.includes('settings'));

  // Admin-only sections must NOT be in staff sections
  assert.ok(!staffSections.includes('users'), 'Users management is admin-only');
  assert.ok(!staffSections.includes('departments'), 'Departments management is admin-only');
  assert.ok(!staffSections.includes('categories'), 'Categories management is admin-only');
  assert.ok(!staffSections.includes('locations'), 'Locations management is admin-only');
  assert.ok(!staffSections.includes('logs'), 'Audit logs are admin-only');
  assert.ok(!staffSections.includes('challenges'), 'Challenge creation is admin-only');
  assert.ok(!staffSections.includes('notices'), 'Campus notice broadcast is admin-only');
});
