'use client';

import React from 'react';
import {
  LayoutDashboard,
  Layers,
  Megaphone,
  Trophy,
  BarChart3,
  Users,
  Building2,
  Tag,
  MapPin,
  Settings,
  FileText,
  X,
} from 'lucide-react';
import { cn } from '@/lib/utils';

import { UserRole } from '@/types/database';

export type PortalSection =
  | 'dashboard'
  | 'issues'
  | 'notices'
  | 'challenges'
  | 'analytics'
  | 'users'
  | 'departments'
  | 'categories'
  | 'locations'
  | 'settings'
  | 'logs';

interface AdminSidebarProps {
  activeSection: PortalSection;
  onSelectSection: (section: PortalSection) => void;
  isOpenMobile?: boolean;
  onCloseMobile?: () => void;
  userRole?: UserRole;
}

export function AdminSidebar({
  activeSection,
  onSelectSection,
  isOpenMobile = false,
  onCloseMobile,
  userRole = 'admin',
}: AdminSidebarProps) {
  const isStaff = userRole === 'staff';

  const primaryNav: { id: PortalSection; label: string; icon: React.ComponentType<{ className?: string }> }[] = isStaff
    ? [
        { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
        { id: 'issues', label: 'Department Issues', icon: Layers },
        { id: 'analytics', label: 'Analytics', icon: BarChart3 },
      ]
    : [
        { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
        { id: 'issues', label: 'Issues', icon: Layers },
        { id: 'notices', label: 'Notices', icon: Megaphone },
        { id: 'challenges', label: 'Challenges', icon: Trophy },
        { id: 'analytics', label: 'Analytics', icon: BarChart3 },
      ];

  const manageNav: { id: PortalSection; label: string; icon: React.ComponentType<{ className?: string }> }[] = isStaff
    ? []
    : [
        { id: 'users', label: 'Users', icon: Users },
        { id: 'departments', label: 'Departments', icon: Building2 },
        { id: 'categories', label: 'Categories', icon: Tag },
        { id: 'locations', label: 'Locations', icon: MapPin },
      ];

  const systemNav: { id: PortalSection; label: string; icon: React.ComponentType<{ className?: string }> }[] = isStaff
    ? [{ id: 'settings', label: 'Settings', icon: Settings }]
    : [
        { id: 'settings', label: 'Settings', icon: Settings },
        { id: 'logs', label: 'Logs', icon: FileText },
      ];

  function renderNavItem(item: { id: PortalSection; label: string; icon: React.ComponentType<{ className?: string }> }) {
    const Icon = item.icon;
    const isActive = activeSection === item.id;

    return (
      <button
        key={item.id}
        type="button"
        onClick={() => {
          onSelectSection(item.id);
          if (onCloseMobile) onCloseMobile();
        }}
        className={cn(
          'w-full flex items-center gap-3 px-3 py-2 rounded-xl text-xs font-semibold transition-all duration-150 cursor-pointer text-left',
          isActive
            ? 'bg-[#EAF5EF] text-[#144D37] font-bold shadow-2xs'
            : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100/70'
        )}
      >
        <Icon className={cn('w-4 h-4 shrink-0', isActive ? 'text-[#144D37]' : 'text-slate-400')} />
        <span className="truncate">{item.label}</span>
      </button>
    );
  }

  const content = (
    <div className="flex flex-col h-full bg-white select-none">
      {/* Top Mobile Close */}
      <div className="lg:hidden p-3 border-b border-slate-100 flex items-center justify-between">
        <span className="text-xs font-bold text-slate-700 uppercase tracking-wider">Navigation</span>
        <button
          type="button"
          onClick={onCloseMobile}
          className="p-1 rounded-lg text-slate-400 hover:text-slate-700"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      {/* Nav List */}
      <div className="flex-1 overflow-y-auto px-3 py-4 space-y-6">
        {/* Operations (Primary) */}
        <div className="space-y-1">
          {primaryNav.map(renderNavItem)}
        </div>

        {/* MANAGE Group */}
        {manageNav.length > 0 && (
          <div>
            <div className="px-3 pb-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              Manage
            </div>
            <div className="space-y-1">
              {manageNav.map(renderNavItem)}
            </div>
          </div>
        )}

        {/* SYSTEM Group */}
        <div>
          <div className="px-3 pb-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-wider">
            System
          </div>
          <div className="space-y-1">
            {systemNav.map(renderNavItem)}
          </div>
        </div>
      </div>

      {/* Sidebar Footer with SRM Campus Watermark */}
      <div className="p-4 border-t border-slate-100/80 bg-gradient-to-t from-slate-50 to-white relative overflow-hidden">
        {/* Subtle architectural background silhouette */}
        <div className="absolute right-0 bottom-0 opacity-10 pointer-events-none translate-x-2 translate-y-1">
          <svg width="120" height="70" viewBox="0 0 120 70" fill="currentColor" className="text-[#144D37]">
            <path d="M10,70 L10,35 L20,35 L20,20 L30,20 L30,15 L35,5 L40,15 L40,20 L50,20 L50,35 L60,35 L60,10 L70,10 L75,2 L80,10 L90,10 L90,35 L100,35 L100,25 L110,25 L110,70 Z" />
          </svg>
        </div>

        <div className="relative z-10">
          <div className="font-bold text-slate-800 text-xs">SRM University</div>
          <div className="text-[11px] text-slate-500 font-medium">Sonepat</div>
          <div className="flex items-center justify-between text-[10px] text-slate-400 mt-1.5 pt-1.5 border-t border-slate-200/50">
            <span>Operations Portal</span>
            <span className="flex items-center gap-1 font-semibold text-emerald-700">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
              v1.0.0
            </span>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <>
      {/* Desktop Persistent Sidebar */}
      <aside className="hidden lg:block w-56 shrink-0 border-r border-slate-200 bg-white min-h-[calc(100vh-3.75rem)] sticky top-15">
        {content}
      </aside>

      {/* Mobile Drawer Overlay */}
      {isOpenMobile && (
        <div className="lg:hidden fixed inset-0 z-50 flex">
          <div
            className="fixed inset-0 bg-slate-900/40 backdrop-blur-xs transition-opacity"
            onClick={onCloseMobile}
          />
          <div className="relative w-64 max-w-[80%] bg-white h-full shadow-2xl z-10">
            {content}
          </div>
        </div>
      )}
    </>
  );
}
