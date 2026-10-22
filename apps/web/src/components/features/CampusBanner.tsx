'use client';

import React from 'react';
import { BarChart2 } from 'lucide-react';

interface CampusBannerProps {
  title?: string;
  subtitle?: string;
  eyebrow?: string;
  isDbConnected?: boolean;
}

export function CampusBanner({
  title = 'Campus Issue Management',
  subtitle = 'Review, assign, and resolve student environmental reports in real time.',
  eyebrow = 'OPERATIONS PORTAL',
  isDbConnected = true,
}: CampusBannerProps) {
  return (
    <div className="relative rounded-2xl overflow-hidden border border-slate-200/90 bg-white mb-6 shadow-2xs">
      {/* Background Campus Building Image with smooth radial/linear fade */}
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          backgroundImage: `linear-gradient(to right, #ffffff 40%, rgba(255, 255, 255, 0.88) 60%, rgba(255, 255, 255, 0.35) 90%), url('/campus_header_background.png')`,
          backgroundPosition: 'right center',
          backgroundSize: 'cover',
          backgroundRepeat: 'no-repeat',
        }}
      />

      {/* Content Layer */}
      <div className="relative z-10 px-6 py-6 sm:py-7 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        {/* Left Heading */}
        <div className="max-w-2xl">
          <div className="flex items-center gap-1.5 text-[11px] font-bold text-emerald-700 uppercase tracking-widest mb-1">
            <span className="text-[9px] text-emerald-600">◆</span>
            <span>{eyebrow}</span>
          </div>

          <h1 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
            {title}
          </h1>

          <p className="text-xs sm:text-sm text-slate-500 font-normal mt-1 leading-relaxed">
            {subtitle}
          </p>
        </div>

        {/* Right Floating Status Card */}
        <div className="self-start md:self-auto shrink-0 bg-white/95 backdrop-blur-xs border border-slate-200/90 rounded-2xl px-4 py-2.5 shadow-sm flex items-center gap-3.5">
          <div>
            <div className="flex items-center gap-2">
              <span
                className={`w-2 h-2 rounded-full ${
                  isDbConnected ? 'bg-emerald-500 animate-pulse' : 'bg-rose-500'
                }`}
              />
              <span className="text-xs font-bold text-slate-800">
                {isDbConnected ? 'Database Live Connection' : 'Database Offline'}
              </span>
            </div>
            <p className="text-[10px] text-slate-400 font-medium pl-4 mt-0.5">
              {isDbConnected ? 'All systems operational' : 'Attempting reconnection...'}
            </p>
          </div>

          {/* Activity Icon Box */}
          <div className="w-8 h-8 rounded-xl bg-emerald-50 border border-emerald-200/80 flex items-center justify-center text-emerald-700 shadow-2xs">
            <BarChart2 className="w-4 h-4" />
          </div>
        </div>
      </div>
    </div>
  );
}
