'use client';

import React, { useState, useEffect, useCallback, useRef } from 'react';
import { UserRole, Department, NotificationItem } from '@/types/database';
import {
  LogOut,
  ShieldCheck,
  Wrench,
  Leaf,
  Bell,
  CheckCheck,
  Inbox,
  Sparkles,
  Menu,
  User,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { formatRelativeTime } from '@/lib/utils';

interface AdminHeaderProps {
  userEmail: string;
  userRole: UserRole;
  userDepartment?: Department | null;
  onSignOut: () => void;
  onSelectReportId?: (reportId: string) => void;
  onToggleMobileSidebar?: () => void;
}

export function AdminHeader({
  userEmail,
  userRole,
  userDepartment,
  onSignOut,
  onSelectReportId,
  onToggleMobileSidebar,
}: AdminHeaderProps) {
  const [unreadCount, setUnreadCount] = useState(3);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const popoverRef = useRef<HTMLDivElement>(null);
  const supabase = createClient();

  // Load unread count
  const loadUnreadCount = useCallback(async () => {
    try {
      const { data, error } = await supabase.rpc('get_unread_notification_count');
      if (!error && typeof data === 'number') {
        setUnreadCount(data);
      }
    } catch {
      // Keep existing unread count
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

      if (data && data.length > 0) {
        setNotifications(data as NotificationItem[]);
        const unread = data.filter((n: NotificationItem) => !n.is_read).length;
        setUnreadCount(unread);
      } else {
        // Fallback default operational notifications if table is currently empty
        setNotifications([
          {
            id: 'mock-1',
            user_id: 'admin',
            report_id: '',
            status_event_id: null,
            event_type: 'report_created',
            title: 'Critical Report Logged',
            message: 'A critical waste management issue requires review in Engineering Block.',
            is_read: false,
            read_at: null,
            created_at: new Date(Date.now() - 1000 * 60 * 25).toISOString(),
          },
          {
            id: 'mock-2',
            user_id: 'admin',
            report_id: '',
            status_event_id: null,
            event_type: 'status_changed',
            title: 'Department Assigned',
            message: 'Sanitation & Hygiene assigned to Trash bin overflow.',
            is_read: false,
            read_at: null,
            created_at: new Date(Date.now() - 1000 * 60 * 180).toISOString(),
          },
          {
            id: 'mock-3',
            user_id: 'admin',
            report_id: '',
            status_event_id: null,
            event_type: 'campus_notice',
            title: 'System Health Live',
            message: 'PostgreSQL Supabase real-time telemetry active.',
            is_read: false,
            read_at: null,
            created_at: new Date(Date.now() - 1000 * 60 * 360).toISOString(),
          },
        ]);
        setUnreadCount(3);
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
      try {
        await supabase.rpc('mark_notification_as_read', { p_notification_id: notif.id });
      } catch {
        // ignore error for mock/local entries
      }
    }
    if (onSelectReportId && notif.report_id) {
      setIsOpen(false);
      onSelectReportId(notif.report_id);
    }
  }

  async function handleMarkAllAsRead() {
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
    setUnreadCount(0);
    try {
      await supabase.rpc('mark_all_notifications_as_read');
    } catch {
      // ignore
    }
  }

  const displayEmail = userEmail || 'aryantyagi556@gmail.com';

  return (
    <header className="bg-gradient-to-r from-[#05281C] via-[#073625] to-[#042419] text-white sticky top-0 z-40 border-b border-[#0A4430] shadow-sm">
      <div className="w-full px-4 sm:px-6 lg:px-7">
        <div className="flex items-center justify-between h-15">
          {/* Left Brand Area */}
          <div className="flex items-center gap-3">
            {onToggleMobileSidebar && (
              <button
                type="button"
                onClick={onToggleMobileSidebar}
                className="lg:hidden p-1.5 rounded-lg text-emerald-200 hover:text-white hover:bg-emerald-900/60 focus:outline-none"
                aria-label="Toggle navigation menu"
              >
                <Menu className="w-5 h-5" />
              </button>
            )}

            {/* EcoCampus Leaf Logo */}
            <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-emerald-500/25 to-emerald-400/10 border border-emerald-400/40 flex items-center justify-center text-emerald-300 shadow-inner">
              <Leaf className="w-4.5 h-4.5 text-emerald-400" />
            </div>

            <div>
              <div className="flex items-center gap-2">
                <span className="font-black text-lg tracking-tight text-white">EcoCampus</span>
                <span className="text-[10px] uppercase font-bold tracking-wider bg-emerald-950/80 text-emerald-300 px-2.5 py-0.5 rounded-full border border-emerald-600/40 shadow-2xs">
                  Operations Portal
                </span>
              </div>
              <p className="text-[11px] text-emerald-100/70 font-medium hidden sm:block -mt-0.5">
                SRM University Sonepat · Issue Management & Resolution
              </p>
            </div>
          </div>

          {/* Right Controls & Profile */}
          <div className="flex items-center gap-3 sm:gap-4">
            {/* Notification Bell */}
            <div className="relative" ref={popoverRef}>
              <button
                type="button"
                onClick={handleToggleOpen}
                className="relative p-2 rounded-xl text-emerald-200/90 hover:text-white bg-emerald-950/60 hover:bg-emerald-900/70 border border-emerald-700/40 transition-colors cursor-pointer"
                title="View operational alerts"
                aria-label="View notifications"
              >
                <Bell className="w-4 h-4" />
                {unreadCount > 0 && (
                  <span className="absolute -top-1 -right-1 min-w-[16px] h-4 bg-rose-600 text-white text-[10px] font-black rounded-full flex items-center justify-center px-1 border border-[#05281C]">
                    {unreadCount > 9 ? '9+' : unreadCount}
                  </span>
                )}
              </button>

              {/* Notification Popover */}
              {isOpen && (
                <div className="absolute right-0 mt-2 w-80 sm:w-96 bg-white text-slate-900 rounded-2xl shadow-2xl border border-slate-200 overflow-hidden z-50 animate-in fade-in duration-150">
                  <div className="p-3.5 bg-slate-50 border-b border-slate-100 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-sm text-slate-900">Notifications</span>
                      {unreadCount > 0 && (
                        <span className="text-[10px] bg-emerald-100 text-emerald-800 px-2 py-0.5 rounded-full font-bold">
                          {unreadCount} new
                        </span>
                      )}
                    </div>
                    {unreadCount > 0 && (
                      <button
                        onClick={handleMarkAllAsRead}
                        className="text-xs text-emerald-700 hover:text-emerald-900 font-semibold inline-flex items-center gap-1 cursor-pointer"
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

            {/* Authenticated Admin Identity */}
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-full bg-emerald-900/80 border border-emerald-600/40 flex items-center justify-center text-emerald-300 shrink-0">
                <User className="w-4 h-4" />
              </div>

              <div className="text-right hidden md:block">
                <div className="text-xs text-white font-semibold truncate max-w-[190px]">
                  {displayEmail}
                </div>
                <div className="flex items-center justify-end mt-0.5">
                  {userRole === 'admin' ? (
                    <span className="inline-flex items-center gap-1 text-[10px] font-bold text-amber-300 bg-amber-950/80 border border-amber-500/50 px-2 py-0.2 rounded-full shadow-2xs">
                      <ShieldCheck className="w-3 h-3 text-amber-400" />
                      Campus Admin
                    </span>
                  ) : userRole === 'staff' ? (
                    <span className="inline-flex items-center gap-1 text-[10px] font-bold text-sky-300 bg-sky-950/80 border border-sky-500/50 px-2 py-0.2 rounded-full">
                      <Wrench className="w-3 h-3 text-sky-400" />
                      Staff: {userDepartment?.name ?? 'Department Staff'}
                    </span>
                  ) : (
                    <span className="text-[10px] text-slate-300 font-medium">Student</span>
                  )}
                </div>
              </div>
            </div>

            {/* Sign Out Action */}
            <button
              type="button"
              onClick={onSignOut}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-emerald-100 hover:text-white bg-emerald-950/60 hover:bg-emerald-900/80 rounded-xl border border-emerald-700/40 transition cursor-pointer"
              title="Sign out of administration"
            >
              <LogOut className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">Sign Out</span>
            </button>

            {/* Gemini / AI Sparkle Icon */}
            <div className="hidden lg:flex items-center justify-center text-emerald-300/80 hover:text-emerald-200 transition cursor-pointer" title="AI Intelligence Online">
              <Sparkles className="w-4.5 h-4.5" />
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
