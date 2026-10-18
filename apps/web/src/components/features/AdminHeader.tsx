'use client';

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { UserRole, Department, NotificationItem } from '@/types/database';
import { LogOut, ShieldCheck, Wrench, Leaf, Bell, CheckCheck, Inbox, Megaphone, Trophy, Layers } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { formatRelativeTime, cn } from '@/lib/utils';

interface AdminHeaderProps {
  userEmail: string;
  userRole: UserRole;
  userDepartment?: Department | null;
  activeSection?: 'issues' | 'notices' | 'challenges';
  onSectionChange?: (section: 'issues' | 'notices' | 'challenges') => void;
  onSignOut: () => void;
  onSelectReportId?: (reportId: string) => void;
}

export function AdminHeader({
  userEmail,
  userRole,
  userDepartment,
  activeSection = 'issues',
  onSectionChange,
  onSignOut,
  onSelectReportId,
}: AdminHeaderProps) {
  const [unreadCount, setUnreadCount] = useState(0);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const popoverRef = useRef<HTMLDivElement>(null);
  const supabase = createClient();

  // Load unread count
  const loadUnreadCount = useCallback(async () => {
    try {
      const { data } = await supabase.rpc('get_unread_notification_count');
      if (typeof data === 'number') {
        setUnreadCount(data);
      }
    } catch (e) {
      console.error('Failed to load unread count:', e);
    }
  }, [supabase]);

  // Load notifications list
  const loadNotifications = useCallback(async () => {
    setIsLoading(true);
    try {
      const { data } = await supabase
        .from('notifications')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(20);

      if (data) {
        setNotifications(data as NotificationItem[]);
        const unread = data.filter((n: NotificationItem) => !n.is_read).length;
        setUnreadCount(unread);
      }
    } catch (e) {
      console.error('Failed to load notifications:', e);
    } finally {
      setIsLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    let cancelled = false;
    async function init() {
      await Promise.resolve();
      if (!cancelled) {
        await loadUnreadCount();
      }
    }
    void init();
    return () => {
      cancelled = true;
    };
  }, [loadUnreadCount]);

  // Handle click outside to close popover
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (popoverRef.current && !popoverRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isOpen]);

  async function handleToggleOpen() {
    const nextState = !isOpen;
    setIsOpen(nextState);
    if (nextState) {
      await loadNotifications();
    }
  }

  async function handleMarkAsRead(notif: NotificationItem) {
    if (!notif.is_read) {
      setNotifications((prev) =>
        prev.map((n) => (n.id === notif.id ? { ...n, is_read: true } : n))
      );
      setUnreadCount((c) => Math.max(0, c - 1));
      await supabase.rpc('mark_notification_as_read', { p_notification_id: notif.id });
    }
    if (onSelectReportId && notif.report_id) {
      setIsOpen(false);
      onSelectReportId(notif.report_id);
    }
  }

  async function handleMarkAllAsRead() {
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
    setUnreadCount(0);
    await supabase.rpc('mark_all_notifications_as_read');
  }

  return (
    <header className="bg-[#144D37] text-white sticky top-0 z-30 shadow-md">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo & Title */}
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-emerald-500/20 border border-emerald-400/30 flex items-center justify-center text-emerald-300">
              <Leaf className="w-5 h-5 text-emerald-400" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="font-bold text-lg tracking-tight text-white">EcoCampus</span>
                <span className="text-xs bg-emerald-800/80 text-emerald-200 px-2 py-0.5 rounded font-medium border border-emerald-700/50">
                  Operations Portal
                </span>
              </div>
              <p className="text-xs text-emerald-200/80 hidden sm:block">
                SRM University Sonepat · Issue Management & Resolution
              </p>
            </div>
          </div>

          {/* Navigation Tabs */}
          {onSectionChange && (
            <nav className="hidden md:flex items-center gap-1 bg-emerald-950/40 p-1 rounded-2xl border border-emerald-800/40">
              <button
                onClick={() => onSectionChange('issues')}
                className={cn(
                  'flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all',
                  activeSection === 'issues'
                    ? 'bg-emerald-600 text-white shadow-sm'
                    : 'text-emerald-200/80 hover:text-white hover:bg-emerald-800/40'
                )}
              >
                <Layers className="w-3.5 h-3.5" />
                Issues
              </button>

              {userRole === 'admin' && (
                <>
                  <button
                    onClick={() => onSectionChange('notices')}
                    className={cn(
                      'flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all',
                      activeSection === 'notices'
                        ? 'bg-emerald-600 text-white shadow-sm'
                        : 'text-emerald-200/80 hover:text-white hover:bg-emerald-800/40'
                    )}
                  >
                    <Megaphone className="w-3.5 h-3.5" />
                    Notices
                  </button>

                  <button
                    onClick={() => onSectionChange('challenges')}
                    className={cn(
                      'flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold transition-all',
                      activeSection === 'challenges'
                        ? 'bg-emerald-600 text-white shadow-sm'
                        : 'text-emerald-200/80 hover:text-white hover:bg-emerald-800/40'
                    )}
                  >
                    <Trophy className="w-3.5 h-3.5" />
                    Challenges
                  </button>
                </>
              )}
            </nav>
          )}

          {/* User Account & Actions */}
          <div className="flex items-center gap-4">
            <div className="text-right hidden sm:block">
              <div className="text-xs text-emerald-200/90 font-medium truncate max-w-[200px]">
                {userEmail}
              </div>
              <div className="flex items-center justify-end gap-1.5 mt-0.5">
                {userRole === 'admin' ? (
                  <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-amber-300 bg-amber-950/60 border border-amber-600/40 px-2 py-0.2 rounded-full">
                    <ShieldCheck className="w-3 h-3" />
                    Campus Admin
                  </span>
                ) : userRole === 'staff' ? (
                  <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-sky-300 bg-sky-950/60 border border-sky-600/40 px-2 py-0.2 rounded-full">
                    <Wrench className="w-3 h-3" />
                    Staff: {userDepartment?.name ?? 'Department Staff'}
                  </span>
                ) : (
                  <span className="text-[11px] text-slate-300 font-medium">Student</span>
                )}
              </div>
            </div>

            {/* Notification Bell with Dropdown */}
            <div className="relative" ref={popoverRef}>
              <button
                onClick={handleToggleOpen}
                className="relative p-2 rounded-xl text-emerald-200 hover:text-white bg-emerald-800/60 hover:bg-emerald-700/80 border border-emerald-600/40 transition-colors"
                title="View notifications"
                aria-label="View notifications"
              >
                <Bell className="w-4 h-4" />
                {unreadCount > 0 && (
                  <span className="absolute -top-1 -right-1 min-w-[18px] h-[18px] bg-red-600 text-white text-[10px] font-bold rounded-full flex items-center justify-center px-1 border-2 border-[#144D37]">
                    {unreadCount > 9 ? '9+' : unreadCount}
                  </span>
                )}
              </button>

              {isOpen && (
                <div className="absolute right-0 mt-2 w-80 sm:w-96 bg-white text-slate-900 rounded-2xl shadow-2xl border border-slate-200 overflow-hidden z-50 animate-in fade-in duration-150">
                  <div className="p-3.5 bg-slate-50 border-b border-slate-100 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-sm text-slate-900">Notifications</span>
                      {unreadCount > 0 && (
                        <span className="text-[11px] bg-emerald-100 text-emerald-800 px-1.5 py-0.5 rounded-full font-bold">
                          {unreadCount} new
                        </span>
                      )}
                    </div>
                    {unreadCount > 0 && (
                      <button
                        onClick={handleMarkAllAsRead}
                        className="text-xs text-emerald-700 hover:text-emerald-900 font-semibold inline-flex items-center gap-1"
                      >
                        <CheckCheck className="w-3.5 h-3.5" />
                        Mark all read
                      </button>
                    )}
                  </div>

                  <div className="max-h-80 overflow-y-auto divide-y divide-slate-100">
                    {isLoading ? (
                      <div className="p-6 text-center text-xs text-slate-400">Loading alerts...</div>
                    ) : notifications.length === 0 ? (
                      <div className="p-8 text-center">
                        <Inbox className="w-8 h-8 text-slate-300 mx-auto mb-2" />
                        <p className="text-xs font-semibold text-slate-700">No notifications yet</p>
                        <p className="text-[11px] text-slate-400 mt-0.5">
                          You will be alerted when issues require attention.
                        </p>
                      </div>
                    ) : (
                      notifications.map((notif) => (
                        <div
                          key={notif.id}
                          onClick={() => handleMarkAsRead(notif)}
                          className={`p-3.5 hover:bg-slate-50 cursor-pointer transition-colors flex items-start gap-3 ${
                            notif.is_read ? 'opacity-70 bg-white' : 'bg-emerald-50/40'
                          }`}
                        >
                          <div
                            className={`w-2 h-2 rounded-full mt-1.5 shrink-0 ${
                              notif.is_read ? 'bg-transparent' : 'bg-emerald-600'
                            }`}
                          />
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center justify-between gap-1 mb-0.5">
                              <span className="text-xs font-bold text-slate-900 truncate">
                                {notif.title}
                              </span>
                              <span className="text-[10px] text-slate-400 shrink-0">
                                {formatRelativeTime(notif.created_at)}
                              </span>
                            </div>
                            <p className="text-xs text-slate-600 line-clamp-2">{notif.message}</p>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              )}
            </div>

            <button
              onClick={onSignOut}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-emerald-100 hover:text-white bg-emerald-800/60 hover:bg-emerald-700/80 rounded-lg border border-emerald-600/40 transition-colors"
              title="Sign out of administration"
            >
              <LogOut className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">Sign Out</span>
            </button>
          </div>
        </div>
      </div>
    </header>
  );
}
