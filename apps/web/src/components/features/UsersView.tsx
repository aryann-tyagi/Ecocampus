'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { Department, UserRole } from '@/types/database';
import { createClient } from '@/lib/supabase/client';
import {
  Users,
  Search,
  ShieldCheck,
  Wrench,
  User,
  RotateCcw,
  Edit2,
  Check,
  X,
  AlertCircle,
} from 'lucide-react';
import { formatDate } from '@/lib/utils';

interface UserRecord {
  id: string;
  display_name: string | null;
  companion_name?: string | null;
  created_at: string;
  role: UserRole;
  department_id?: string | null;
  department_name?: string | null;
}

interface UsersViewProps {
  departments: Department[];
  currentUserRole: UserRole;
}

export function UsersView({ departments, currentUserRole }: UsersViewProps) {
  const supabase = createClient();
  const [users, setUsers] = useState<UserRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('');

  // Role edit modal
  const [editingUser, setEditingUser] = useState<UserRecord | null>(null);
  const [newRole, setNewRole] = useState<UserRole>('student');
  const [newDeptId, setNewDeptId] = useState<string>('');
  const [isSavingRole, setIsSavingRole] = useState(false);
  const [roleSaveError, setRoleSaveError] = useState<string | null>(null);

  const loadUsers = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      // 1. Fetch profiles
      const { data: profiles, error: pErr } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false });

      if (pErr) throw pErr;

      // 2. Fetch user_roles
      const { data: rolesData, error: rErr } = await supabase
        .from('user_roles')
        .select('user_id, role, department_id, departments(id, name)');

      const roleMap = new Map<string, { role: UserRole; deptId?: string; deptName?: string }>();
      if (!rErr && rolesData) {
        rolesData.forEach((r: any) => {
          roleMap.set(r.user_id, {
            role: r.role as UserRole,
            deptId: r.department_id,
            deptName: r.departments?.name,
          });
        });
      }

      const mapped: UserRecord[] = (profiles || []).map((p) => {
        const rInfo = roleMap.get(p.id);
        return {
          id: p.id,
          display_name: p.display_name || 'Campus Student',
          companion_name: p.companion_name,
          created_at: p.created_at,
          role: rInfo?.role || 'student',
          department_id: rInfo?.deptId,
          department_name: rInfo?.deptName,
        };
      });

      setUsers(mapped);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to load user directory.');
    } finally {
      setIsLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  const filteredUsers = users.filter((u) => {
    if (roleFilter && u.role !== roleFilter) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const name = (u.display_name || '').toLowerCase();
      const id = u.id.toLowerCase();
      return name.includes(q) || id.includes(q);
    }
    return true;
  });

  async function handleSaveRole(e: React.FormEvent) {
    e.preventDefault();
    if (!editingUser) return;
    setIsSavingRole(true);
    setRoleSaveError(null);

    try {
      const { error: upsertErr } = await supabase.from('user_roles').upsert({
        user_id: editingUser.id,
        role: newRole,
        department_id: newRole === 'staff' ? newDeptId || null : null,
        updated_at: new Date().toISOString(),
      });

      if (upsertErr) throw upsertErr;

      setEditingUser(null);
      await loadUsers();
    } catch (err: unknown) {
      setRoleSaveError(err instanceof Error ? err.message : 'Failed to update user role.');
    } finally {
      setIsSavingRole(false);
    }
  }

  return (
    <div className="space-y-4 animate-in fade-in duration-150">
      {/* Top Controls */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-4 shadow-2xs flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search campus members by name or ID..."
            className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs sm:text-sm text-slate-800 focus:bg-white focus:outline-none focus:ring-1 focus:ring-[#144D37]"
          />
        </div>

        <div className="flex items-center gap-2">
          <select
            value={roleFilter}
            onChange={(e) => setRoleFilter(e.target.value)}
            className="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-semibold text-slate-700 focus:outline-none cursor-pointer"
          >
            <option value="">All Roles</option>
            <option value="admin">Campus Admin</option>
            <option value="staff">Department Staff</option>
            <option value="student">Student</option>
          </select>

          <button
            type="button"
            onClick={loadUsers}
            disabled={isLoading}
            className="p-2.5 bg-white hover:bg-slate-50 border border-slate-200 rounded-xl text-slate-600 shadow-2xs transition disabled:opacity-50 cursor-pointer"
            title="Refresh users"
          >
            <RotateCcw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-2xl border border-slate-200/90 shadow-2xs overflow-hidden">
        {error ? (
          <div className="p-8 text-center text-xs text-rose-600">{error}</div>
        ) : isLoading ? (
          <div className="p-8 text-center text-xs text-slate-400">Loading campus directory...</div>
        ) : filteredUsers.length === 0 ? (
          <div className="p-12 text-center text-xs text-slate-400">No campus members found.</div>
        ) : (
          <table className="w-full text-left text-xs border-collapse">
            <thead className="bg-[#FAFBFB] text-slate-400 font-bold uppercase tracking-wider text-[11px] border-b border-slate-200/80">
              <tr>
                <th className="py-3 px-4">Member</th>
                <th className="py-3 px-3">Role</th>
                <th className="py-3 px-3">Assigned Department</th>
                <th className="py-3 px-3">Registered</th>
                {currentUserRole === 'admin' && <th className="py-3 px-3 text-right">Actions</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700">
              {filteredUsers.map((user) => (
                <tr key={user.id} className="hover:bg-slate-50/70 transition">
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-2.5">
                      <div className="w-8 h-8 rounded-full bg-emerald-50 border border-emerald-200/80 flex items-center justify-center text-emerald-700 shrink-0">
                        <User className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="font-bold text-slate-900">{user.display_name}</div>
                        <div className="text-[10px] text-slate-400 font-mono">
                          ID: {user.id.slice(0, 8)}...
                        </div>
                      </div>
                    </div>
                  </td>

                  <td className="py-3 px-3">
                    {user.role === 'admin' ? (
                      <span className="inline-flex items-center gap-1 text-[11px] font-bold text-amber-800 bg-amber-50 border border-amber-200 px-2 py-0.5 rounded-full">
                        <ShieldCheck className="w-3 h-3 text-amber-600" />
                        Campus Admin
                      </span>
                    ) : user.role === 'staff' ? (
                      <span className="inline-flex items-center gap-1 text-[11px] font-bold text-sky-800 bg-sky-50 border border-sky-200 px-2 py-0.5 rounded-full">
                        <Wrench className="w-3 h-3 text-sky-600" />
                        Staff
                      </span>
                    ) : (
                      <span className="text-[11px] font-medium text-slate-500 bg-slate-100 px-2 py-0.5 rounded-full">
                        Student
                      </span>
                    )}
                  </td>

                  <td className="py-3 px-3 text-slate-600">
                    {user.department_name ? (
                      <span className="font-semibold text-slate-800 bg-slate-100 px-2 py-0.5 rounded-md">
                        {user.department_name}
                      </span>
                    ) : (
                      <span className="text-slate-400">—</span>
                    )}
                  </td>

                  <td className="py-3 px-3 text-slate-500 text-[11px]">
                    {formatDate(user.created_at)}
                  </td>

                  {currentUserRole === 'admin' && (
                    <td className="py-3 px-3 text-right">
                      <button
                        type="button"
                        onClick={() => {
                          setEditingUser(user);
                          setNewRole(user.role);
                          setNewDeptId(user.department_id || '');
                        }}
                        className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-[#144D37] hover:bg-emerald-50 rounded-lg border border-slate-200 shadow-2xs transition cursor-pointer"
                      >
                        <Edit2 className="w-3 h-3" />
                        <span>Manage Role</span>
                      </button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Role Editor Modal */}
      {editingUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-md w-full p-6 shadow-2xl border border-slate-200 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h3 className="font-bold text-slate-900 text-sm">Assign Member Role</h3>
                <p className="text-xs text-slate-400">{editingUser.display_name}</p>
              </div>
              <button
                onClick={() => setEditingUser(null)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-700"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {roleSaveError && (
              <div className="p-3 bg-rose-50 border border-rose-200 text-rose-800 rounded-xl text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
                <span>{roleSaveError}</span>
              </div>
            )}

            <form onSubmit={handleSaveRole} className="space-y-3 text-xs">
              <div>
                <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Access Role
                </label>
                <select
                  value={newRole}
                  onChange={(e) => setNewRole(e.target.value as UserRole)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:outline-none"
                >
                  <option value="student">Student (Standard access)</option>
                  <option value="staff">Department Staff (Issue management)</option>
                  <option value="admin">Campus Administrator (Full access)</option>
                </select>
              </div>

              {newRole === 'staff' && (
                <div>
                  <label className="block font-bold text-slate-700 uppercase tracking-wider mb-1">
                    Department Assignment *
                  </label>
                  <select
                    required
                    value={newDeptId}
                    onChange={(e) => setNewDeptId(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-slate-800 font-medium focus:outline-none"
                  >
                    <option value="">Select department...</option>
                    {departments.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <div className="pt-2 flex justify-end gap-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setEditingUser(null)}
                  className="px-3.5 py-1.5 text-slate-600 hover:bg-slate-100 rounded-xl font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSavingRole}
                  className="px-4 py-1.5 bg-[#144D37] text-white font-bold rounded-xl shadow-sm hover:bg-[#0f3a29] transition disabled:opacity-60 cursor-pointer"
                >
                  {isSavingRole ? 'Saving...' : 'Update Role'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
