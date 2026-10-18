'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { ChallengeItem, Building } from '@/types/database';
import { createClient } from '@/lib/supabase/client';
import {
  Trophy,
  Plus,
  Search,
  Filter,
  RefreshCw,
  Coins,
  Repeat,
  Target,
  Edit3,
  Archive,
  CheckCircle,
  Clock,
  AlertCircle,
  Building2,
  Calendar,
  Users,
  Pin,
} from 'lucide-react';
import {
  getChallengeTypeBadge,
  getChallengeRecurrenceBadge,
  formatDate,
  cn,
} from '@/lib/utils';
import { ChallengeEditorModal } from './ChallengeEditorModal';

interface ChallengeManagementProps {
  buildings: Building[];
}

export function ChallengeManagement({ buildings }: ChallengeManagementProps) {
  const supabase = createClient();

  const [challenges, setChallenges] = useState<ChallengeItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [recurrenceFilter, setRecurrenceFilter] = useState('all');
  const [typeFilter, setTypeFilter] = useState('all');

  // Modal State
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [editingChallenge, setEditingChallenge] = useState<ChallengeItem | null>(null);

  // Load challenges with completion counts
  const loadChallenges = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      // Query challenges
      const { data: challengesData, error: fetchErr } = await supabase
        .from('challenges')
        .select(`
          *,
          buildings(id, name)
        `)
        .order('is_pinned', { ascending: false })
        .order('created_at', { ascending: false });

      if (fetchErr) throw fetchErr;

      // Query total completions count per challenge
      const { data: completionsData } = await supabase
        .from('user_challenge_completions')
        .select('challenge_id')
        .eq('is_completed', true);

      const countsMap: Record<string, number> = {};
      if (completionsData) {
        for (const row of completionsData) {
          countsMap[row.challenge_id] = (countsMap[row.challenge_id] || 0) + 1;
        }
      }

      const enriched = (challengesData || []).map((ch: ChallengeItem) => ({
        ...ch,
        completions_count: countsMap[ch.id] || 0,
      }));

      setChallenges(enriched);
    } catch (err: unknown) {
      console.error('Failed to load challenges:', err);
      setError(err instanceof Error ? err.message : 'Failed to load challenges.');
    } finally {
      setIsLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadChallenges();
  }, [loadChallenges]);

  // Quick action: Toggle publish/archive status
  async function handleToggleStatus(challenge: ChallengeItem, nextStatus: 'published' | 'archived' | 'draft') {
    try {
      const { error: updateErr } = await supabase
        .from('challenges')
        .update({
          status: nextStatus,
          updated_at: new Date().toISOString(),
        })
        .eq('id', challenge.id);

      if (updateErr) throw updateErr;
      await loadChallenges();
    } catch (err: unknown) {
      console.error('Failed to update challenge status:', err);
      alert(err instanceof Error ? err.message : 'Failed to update challenge status');
    }
  }

  // Filter challenges
  const filteredChallenges = challenges.filter((c) => {
    if (statusFilter !== 'all' && c.status !== statusFilter) return false;
    if (recurrenceFilter !== 'all' && c.recurrence_type !== recurrenceFilter) return false;
    if (typeFilter !== 'all' && c.challenge_type !== typeFilter) return false;

    if (searchQuery.trim().length > 0) {
      const q = searchQuery.toLowerCase();
      const matchTitle = c.title.toLowerCase().includes(q);
      const matchDesc = c.description.toLowerCase().includes(q);
      const matchKey = c.challenge_key.toLowerCase().includes(q);
      if (!matchTitle && !matchDesc && !matchKey) return false;
    }
    return true;
  });

  // Calculate overview metrics
  const totalCount = challenges.length;
  const activeCount = challenges.filter((c) => c.status === 'published').length;
  const totalCompletions = challenges.reduce((acc, c) => acc + (c.completions_count || 0), 0);
  const totalPointsConfigured = challenges
    .filter((c) => c.status === 'published')
    .reduce((acc, c) => acc + c.reward_points, 0);

  return (
    <div className="space-y-6">
      {/* Overview Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">Total Challenges</p>
            <p className="text-2xl font-black text-slate-900 mt-1">{totalCount}</p>
          </div>
          <div className="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center text-slate-600">
            <Trophy className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-[11px] font-bold text-emerald-600 uppercase tracking-wider">Active Published</p>
            <p className="text-2xl font-black text-emerald-700 mt-1">{activeCount}</p>
          </div>
          <div className="w-10 h-10 rounded-xl bg-emerald-50 flex items-center justify-center text-emerald-600">
            <CheckCircle className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-[11px] font-bold text-blue-600 uppercase tracking-wider">Student Completions</p>
            <p className="text-2xl font-black text-blue-700 mt-1">{totalCompletions}</p>
          </div>
          <div className="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center text-blue-600">
            <Users className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-[11px] font-bold text-amber-600 uppercase tracking-wider">Total Active Points</p>
            <p className="text-2xl font-black text-amber-700 mt-1">+{totalPointsConfigured}</p>
          </div>
          <div className="w-10 h-10 rounded-xl bg-amber-50 flex items-center justify-center text-amber-600">
            <Coins className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Control Bar: Search, Filters & Create Button */}
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-slate-200 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
          {/* Search Box */}
          <div className="relative w-full sm:w-80">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search challenges by title or keyword..."
              className="w-full pl-9 pr-4 py-2 text-xs font-medium rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 bg-slate-50/50 text-slate-900 placeholder:text-slate-400"
            />
          </div>

          <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
            <button
              onClick={loadChallenges}
              disabled={isLoading}
              className="p-2 rounded-xl border border-slate-200 text-slate-600 hover:text-slate-900 hover:bg-slate-50 transition-colors disabled:opacity-50"
              title="Refresh challenges"
            >
              <RefreshCw className={cn('w-4 h-4', isLoading && 'animate-spin')} />
            </button>

            <button
              onClick={() => {
                setEditingChallenge(null);
                setIsEditorOpen(true);
              }}
              className="px-4 py-2 text-xs font-bold text-white bg-emerald-700 hover:bg-emerald-800 rounded-xl transition-all shadow-md shadow-emerald-900/10 flex items-center gap-1.5"
            >
              <Plus className="w-4 h-4" />
              <span>Create Challenge</span>
            </button>
          </div>
        </div>

        {/* Filters */}
        <div className="flex items-center gap-3 flex-wrap pt-2 border-t border-slate-100 text-xs">
          <div className="flex items-center gap-1 text-slate-500 font-semibold">
            <Filter className="w-3.5 h-3.5" />
            <span>Filters:</span>
          </div>

          {/* Status Filter */}
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-2.5 py-1 text-xs font-medium rounded-lg border border-slate-200 bg-white text-slate-700 focus:outline-none focus:ring-1 focus:ring-emerald-600"
          >
            <option value="all">All Statuses</option>
            <option value="published">Published</option>
            <option value="draft">Draft</option>
            <option value="archived">Archived</option>
          </select>

          {/* Recurrence Filter */}
          <select
            value={recurrenceFilter}
            onChange={(e) => setRecurrenceFilter(e.target.value)}
            className="px-2.5 py-1 text-xs font-medium rounded-lg border border-slate-200 bg-white text-slate-700 focus:outline-none focus:ring-1 focus:ring-emerald-600"
          >
            <option value="all">All Recurrences</option>
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
            <option value="one_time">One-Time</option>
          </select>

          {/* Type Filter */}
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
            className="px-2.5 py-1 text-xs font-medium rounded-lg border border-slate-200 bg-white text-slate-700 focus:outline-none focus:ring-1 focus:ring-emerald-600"
          >
            <option value="all">All Types</option>
            <option value="report_issue">Report Issue</option>
            <option value="category_reporting">Category Target</option>
            <option value="building_reporting">Building Target</option>
            <option value="multiple_reports">Multiple Reports</option>
          </select>

          {(statusFilter !== 'all' || recurrenceFilter !== 'all' || typeFilter !== 'all' || searchQuery) && (
            <button
              onClick={() => {
                setStatusFilter('all');
                setRecurrenceFilter('all');
                setTypeFilter('all');
                setSearchQuery('');
              }}
              className="text-[11px] font-semibold text-emerald-700 hover:underline ml-auto"
            >
              Reset Filters
            </button>
          )}
        </div>
      </div>

      {/* Challenges List */}
      {isLoading ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center shadow-sm">
          <div className="w-8 h-8 border-2 border-emerald-600 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          <p className="text-xs font-semibold text-slate-600">Loading custom challenges...</p>
        </div>
      ) : error ? (
        <div className="bg-rose-50 rounded-2xl border border-rose-200 p-6 text-center text-rose-800">
          <AlertCircle className="w-8 h-8 text-rose-600 mx-auto mb-2" />
          <p className="text-xs font-bold">{error}</p>
          <button
            onClick={loadChallenges}
            className="mt-3 px-3 py-1 bg-white border border-rose-300 rounded-lg text-xs font-semibold hover:bg-rose-100"
          >
            Retry
          </button>
        </div>
      ) : filteredChallenges.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center shadow-sm">
          <Trophy className="w-10 h-10 text-slate-300 mx-auto mb-3" />
          <h3 className="text-sm font-bold text-slate-800">No challenges found</h3>
          <p className="text-xs text-slate-400 mt-1 max-w-sm mx-auto">
            {searchQuery || statusFilter !== 'all'
              ? 'Try adjusting your search criteria or filters.'
              : 'Create a custom challenge to incentivize sustainable student habits with EcoPoints.'}
          </p>
          <button
            onClick={() => {
              setEditingChallenge(null);
              setIsEditorOpen(true);
            }}
            className="mt-4 px-4 py-2 bg-emerald-700 text-white rounded-xl text-xs font-bold hover:bg-emerald-800 transition-colors inline-flex items-center gap-1.5"
          >
            <Plus className="w-3.5 h-3.5" />
            Create Challenge
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filteredChallenges.map((challenge) => {
            const typeBadge = getChallengeTypeBadge(challenge.challenge_type);
            const recurrenceBadge = getChallengeRecurrenceBadge(challenge.recurrence_type);

            return (
              <div
                key={challenge.id}
                className={cn(
                  'bg-white rounded-2xl border transition-all p-5 shadow-sm hover:shadow-md flex flex-col justify-between gap-4',
                  challenge.is_pinned
                    ? 'border-emerald-300 bg-emerald-50/10'
                    : 'border-slate-200'
                )}
              >
                {/* Top Section */}
                <div className="space-y-3">
                  {/* Badges & Points */}
                  <div className="flex items-center justify-between gap-2 flex-wrap">
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <span
                        className={cn(
                          'text-[10px] font-bold px-2 py-0.5 rounded-full border',
                          recurrenceBadge.bg
                        )}
                      >
                        {recurrenceBadge.label}
                      </span>

                      <span
                        className={cn(
                          'text-[10px] font-bold px-2 py-0.5 rounded-full border',
                          typeBadge.bg
                        )}
                      >
                        {typeBadge.label}
                      </span>

                      {challenge.status === 'published' ? (
                        <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-800 border border-emerald-200">
                          Active
                        </span>
                      ) : challenge.status === 'draft' ? (
                        <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-50 text-amber-800 border border-amber-200">
                          Draft
                        </span>
                      ) : (
                        <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 border border-slate-200">
                          Archived
                        </span>
                      )}

                      {challenge.is_pinned && (
                        <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-emerald-100 text-emerald-800 flex items-center gap-0.5">
                          <Pin className="w-2.5 h-2.5" /> Featured
                        </span>
                      )}
                    </div>

                    {/* REWARD POINTS PILL */}
                    <span className="px-2.5 py-1 rounded-full bg-amber-50 text-amber-900 border border-amber-200 text-xs font-black flex items-center gap-1 shadow-sm">
                      <Coins className="w-3.5 h-3.5 text-amber-600" />
                      +{challenge.reward_points} EcoPoints
                    </span>
                  </div>

                  {/* Title & Description */}
                  <div>
                    <h3 className="text-base font-bold text-slate-900 tracking-tight">
                      {challenge.title}
                    </h3>
                    <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                      {challenge.description}
                    </p>
                  </div>

                  {/* Requirements & Criteria Box */}
                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-200/80 text-xs space-y-1.5">
                    <div className="flex items-center justify-between text-slate-700">
                      <span className="text-slate-500 font-medium">Goal Target:</span>
                      <span className="font-bold text-slate-900">
                        {challenge.target_count} qualifying {challenge.target_count === 1 ? 'report' : 'reports'}
                      </span>
                    </div>

                    {challenge.category && (
                      <div className="flex items-center justify-between text-slate-700">
                        <span className="text-slate-500 font-medium">Category:</span>
                        <span className="font-bold text-emerald-700 capitalize">
                          {challenge.category}
                        </span>
                      </div>
                    )}

                    {challenge.buildings && (
                      <div className="flex items-center justify-between text-slate-700">
                        <span className="text-slate-500 font-medium">Building:</span>
                        <span className="font-bold text-slate-900 flex items-center gap-1">
                          <Building2 className="w-3 h-3 text-emerald-600" />
                          {challenge.buildings.name}
                        </span>
                      </div>
                    )}
                  </div>
                </div>

                {/* Bottom Meta & Actions */}
                <div className="pt-3 border-t border-slate-100 flex items-center justify-between gap-2">
                  <div className="flex items-center gap-1.5 text-[11px] text-slate-500 font-medium">
                    <Users className="w-3.5 h-3.5 text-blue-600" />
                    <span>
                      <strong>{challenge.completions_count || 0}</strong> students completed
                    </span>
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => {
                        setEditingChallenge(challenge);
                        setIsEditorOpen(true);
                      }}
                      className="px-2.5 py-1.5 rounded-xl border border-slate-200 text-slate-700 hover:text-slate-900 hover:bg-slate-50 transition-colors text-xs font-semibold flex items-center gap-1"
                      title="Edit Challenge"
                    >
                      <Edit3 className="w-3.5 h-3.5" />
                      <span>Edit</span>
                    </button>

                    {challenge.status !== 'published' ? (
                      <button
                        onClick={() => handleToggleStatus(challenge, 'published')}
                        className="px-3 py-1.5 rounded-xl bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors text-xs font-bold flex items-center gap-1"
                      >
                        <CheckCircle className="w-3.5 h-3.5" />
                        Publish
                      </button>
                    ) : (
                      <button
                        onClick={() => handleToggleStatus(challenge, 'archived')}
                        className="px-2.5 py-1.5 rounded-xl bg-slate-100 text-slate-600 border border-slate-200 hover:bg-slate-200 transition-colors text-xs font-medium flex items-center gap-1"
                        title="Archive Challenge"
                      >
                        <Archive className="w-3.5 h-3.5" />
                        Archive
                      </button>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Editor & Preview Modal */}
      <ChallengeEditorModal
        challenge={editingChallenge}
        buildings={buildings}
        isOpen={isEditorOpen}
        onClose={() => {
          setIsEditorOpen(false);
          setEditingChallenge(null);
        }}
        onSaved={loadChallenges}
      />
    </div>
  );
}
