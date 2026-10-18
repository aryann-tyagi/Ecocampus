'use client';

import React, { useState, useEffect } from 'react';
import {
  ChallengeItem,
  Building,
  IssueCategory,
  ChallengeType,
  ChallengeRecurrence,
  ChallengeStatus,
} from '@/types/database';
import { createClient } from '@/lib/supabase/client';
import {
  X,
  Trophy,
  Eye,
  CheckCircle2,
  Calendar,
  Building2,
  Pin,
  AlertTriangle,
  Coins,
  Repeat,
  Target,
  FileText,
  Sparkles,
  Layers,
} from 'lucide-react';
import {
  getChallengeTypeBadge,
  getChallengeRecurrenceBadge,
  getCategoryBadge,
  formatDate,
  cn,
} from '@/lib/utils';

interface ChallengeEditorModalProps {
  challenge: ChallengeItem | null;
  buildings: Building[];
  isOpen: boolean;
  onClose: () => void;
  onSaved: () => void;
}

export function ChallengeEditorModal({
  challenge,
  buildings,
  isOpen,
  onClose,
  onSaved,
}: ChallengeEditorModalProps) {
  const supabase = createClient();
  const isEditing = !!challenge;

  // Form State
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [instructions, setInstructions] = useState('');
  const [challengeType, setChallengeType] = useState<ChallengeType>('report_issue');
  const [category, setCategory] = useState<IssueCategory | 'any'>('any');
  const [buildingId, setBuildingId] = useState<string>('any');
  const [targetCount, setTargetCount] = useState<number>(1);
  const [rewardPoints, setRewardPoints] = useState<number>(25); // CUSTOMIZABLE POINTS
  const [recurrenceType, setRecurrenceType] = useState<ChallengeRecurrence>('daily');
  const [status, setStatus] = useState<ChallengeStatus>('draft');
  const [isPinned, setIsPinned] = useState(false);
  const [startsAt, setStartsAt] = useState('');
  const [endsAt, setEndsAt] = useState('');

  // UI State
  const [activeTab, setActiveTab] = useState<'edit' | 'preview'>('edit');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Sync form on open
  useEffect(() => {
    if (challenge) {
      setTitle(challenge.title);
      setDescription(challenge.description);
      setInstructions(challenge.instructions);
      setChallengeType(challenge.challenge_type);
      setCategory(challenge.category || 'any');
      setBuildingId(challenge.building_id || 'any');
      setTargetCount(challenge.target_count || 1);
      setRewardPoints(challenge.reward_points || 25);
      setRecurrenceType(challenge.recurrence_type);
      setStatus(challenge.status);
      setIsPinned(challenge.is_pinned);

      const toLocalISO = (isoStr: string) => {
        try {
          const d = new Date(isoStr);
          const offset = d.getTimezoneOffset() * 60000;
          return new Date(d.getTime() - offset).toISOString().slice(0, 16);
        } catch {
          return '';
        }
      };

      setStartsAt(challenge.starts_at ? toLocalISO(challenge.starts_at) : '');
      setEndsAt(challenge.ends_at ? toLocalISO(challenge.ends_at) : '');
    } else {
      // Default new challenge
      setTitle('');
      setDescription('');
      setInstructions('');
      setChallengeType('report_issue');
      setCategory('any');
      setBuildingId('any');
      setTargetCount(1);
      setRewardPoints(25);
      setRecurrenceType('daily');
      setStatus('draft');
      setIsPinned(false);

      const now = new Date();
      const offset = now.getTimezoneOffset() * 60000;
      setStartsAt(new Date(now.getTime() - offset).toISOString().slice(0, 16));
      setEndsAt('');
    }
    setError(null);
    setActiveTab('edit');
  }, [challenge, isOpen]);

  // Adjust defaults when challenge type changes
  function handleChallengeTypeChange(newType: ChallengeType) {
    setChallengeType(newType);
    if (newType === 'category_reporting' && category === 'any') {
      setCategory('water');
    }
    if (newType === 'multiple_reports' && targetCount <= 1) {
      setTargetCount(2);
    }
    if (newType === 'building_reporting' && buildingId === 'any' && buildings.length > 0) {
      setBuildingId(buildings[0].id);
    }
  }

  if (!isOpen) return null;

  async function handleSave(newStatus?: ChallengeStatus) {
    const finalStatus = newStatus || status;
    setError(null);

    // Validation
    const cleanTitle = title.trim();
    const cleanDesc = description.trim();
    const cleanInstructions = instructions.trim();

    if (cleanTitle.length < 2 || cleanTitle.length > 160) {
      setError('Title must be between 2 and 160 characters.');
      return;
    }

    if (cleanDesc.length === 0) {
      setError('Student-facing description cannot be empty.');
      return;
    }

    if (cleanInstructions.length === 0) {
      setError('Instructions for students cannot be empty.');
      return;
    }

    // Points customization validation
    const parsedPoints = Number(rewardPoints);
    if (!Number.isInteger(parsedPoints) || parsedPoints < 1 || parsedPoints > 500) {
      setError('Reward Points must be a positive integer between 1 and 500 EcoPoints.');
      return;
    }

    // Target count validation
    const parsedTarget = Number(targetCount);
    if (!Number.isInteger(parsedTarget) || parsedTarget < 1 || parsedTarget > 50) {
      setError('Target qualifying reports must be between 1 and 50.');
      return;
    }

    // Specific category check
    let finalCategory: IssueCategory | null = null;
    if (challengeType === 'category_reporting' || category !== 'any') {
      if (category === 'any' && challengeType === 'category_reporting') {
        setError('Please select a specific category requirement.');
        return;
      }
      finalCategory = category === 'any' ? null : category;
    }

    // Specific building check
    let finalBuildingId: string | null = null;
    if (challengeType === 'building_reporting' || buildingId !== 'any') {
      if (buildingId === 'any' && challengeType === 'building_reporting') {
        setError('Please select a specific campus building requirement.');
        return;
      }
      finalBuildingId = buildingId === 'any' ? null : buildingId;
    }

    let startIso: string;
    try {
      startIso = startsAt ? new Date(startsAt).toISOString() : new Date().toISOString();
    } catch {
      setError('Invalid start date.');
      return;
    }

    let endIso: string | null = null;
    if (endsAt) {
      try {
        endIso = new Date(endsAt).toISOString();
        if (new Date(endIso) <= new Date(startIso)) {
          setError('End date must be after the start date.');
          return;
        }
      } catch {
        setError('Invalid end date.');
        return;
      }
    }

    setIsSubmitting(true);
    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (!session?.user) {
        throw new Error('Authentication required.');
      }

      // Generate a unique challenge_key if creating new
      const challengeKey = isEditing && challenge
        ? challenge.challenge_key
        : `custom_${cleanTitle.toLowerCase().replace(/[^a-z0-9]/g, '_').slice(0, 30)}_${Date.now().toString(36)}`;

      const payload = {
        title: cleanTitle,
        description: cleanDesc,
        instructions: cleanInstructions,
        challenge_type: challengeType,
        category: finalCategory,
        building_id: finalBuildingId,
        target_count: parsedTarget,
        reward_points: parsedPoints, // Admin-configured EcoPoints reward
        recurrence_type: recurrenceType,
        status: finalStatus,
        is_pinned: isPinned,
        starts_at: startIso,
        ends_at: endIso,
        updated_at: new Date().toISOString(),
      };

      if (isEditing && challenge) {
        const { error: updateErr } = await supabase
          .from('challenges')
          .update(payload)
          .eq('id', challenge.id);

        if (updateErr) throw updateErr;
      } else {
        const { error: insertErr } = await supabase
          .from('challenges')
          .insert({
            ...payload,
            challenge_key: challengeKey,
            created_by: session.user.id,
          });

        if (insertErr) throw insertErr;
      }

      onSaved();
      onClose();
    } catch (err: unknown) {
      console.error('Error saving challenge:', err);
      setError(err instanceof Error ? err.message : 'Failed to save challenge. Please check inputs.');
    } finally {
      setIsSubmitting(false);
    }
  }

  const selectedBuildingName =
    buildingId === 'any'
      ? null
      : buildings.find((b) => b.id === buildingId)?.name;

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 animate-in fade-in duration-200">
      <div className="bg-white rounded-3xl max-w-3xl w-full shadow-2xl border border-slate-200 overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="p-5 sm:p-6 bg-slate-900 text-white flex items-center justify-between shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-amber-500/20 border border-amber-400/30 flex items-center justify-center text-amber-400">
              <Trophy className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold tracking-tight">
                {isEditing ? 'Edit Challenge' : 'Create Custom Challenge'}
              </h2>
              <p className="text-xs text-slate-400">
                Define verifiable rules and choose EcoPoints rewards awarded to students.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <div className="flex rounded-xl bg-slate-800 p-1 border border-slate-700">
              <button
                type="button"
                onClick={() => setActiveTab('edit')}
                className={cn(
                  'px-3 py-1 text-xs font-semibold rounded-lg transition-all',
                  activeTab === 'edit'
                    ? 'bg-emerald-600 text-white shadow-sm'
                    : 'text-slate-400 hover:text-white'
                )}
              >
                Editor
              </button>
              <button
                type="button"
                onClick={() => setActiveTab('preview')}
                className={cn(
                  'px-3 py-1 text-xs font-semibold rounded-lg transition-all flex items-center gap-1.5',
                  activeTab === 'preview'
                    ? 'bg-emerald-600 text-white shadow-sm'
                    : 'text-slate-400 hover:text-white'
                )}
              >
                <Eye className="w-3.5 h-3.5" />
                Preview
              </button>
            </div>

            <button
              onClick={onClose}
              className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Error Alert */}
        {error && (
          <div className="px-6 py-3 bg-rose-50 border-b border-rose-200 text-rose-800 text-xs flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 shrink-0 text-rose-600" />
            <span>{error}</span>
          </div>
        )}

        {/* Body Content */}
        <div className="flex-1 overflow-y-auto p-5 sm:p-6">
          {activeTab === 'edit' ? (
            <div className="space-y-5">
              {/* Title */}
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                  Challenge Title <span className="text-rose-500">*</span>
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="e.g. Hostel Energy Conservation Hero"
                  maxLength={160}
                  className="w-full text-sm font-semibold px-4 py-2.5 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 text-slate-900 placeholder:text-slate-400"
                />
              </div>

              {/* Description */}
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                  Student-Facing Description <span className="text-rose-500">*</span>
                </label>
                <input
                  type="text"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="e.g. Spot electricity leaks or burning lights in academic halls."
                  className="w-full text-xs px-3 py-2.5 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 text-slate-900 placeholder:text-slate-400"
                />
              </div>

              {/* Instructions */}
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                  Action Instructions for Students <span className="text-rose-500">*</span>
                </label>
                <textarea
                  value={instructions}
                  onChange={(e) => setInstructions(e.target.value)}
                  rows={2}
                  placeholder="e.g. Take a photo of an unneeded light or AC left on, submit an electricity report, and preserve campus energy."
                  className="w-full text-xs px-3 py-2 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-600 text-slate-900 placeholder:text-slate-400"
                />
              </div>

              {/* HIGHLIGHT: CUSTOMIZABLE ECOPOINTS REWARD */}
              <div className="p-4 bg-emerald-50/70 border border-emerald-200 rounded-2xl flex flex-col sm:flex-row items-center justify-between gap-4">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-emerald-600 text-white flex items-center justify-center shrink-0 shadow-sm">
                    <Coins className="w-5 h-5" />
                  </div>
                  <div>
                    <span className="text-xs font-bold text-emerald-950 uppercase tracking-wider block">
                      Customizable EcoPoints Reward
                    </span>
                    <p className="text-[11px] text-emerald-800">
                      Admins choose the points students receive upon completion. Backend awards this exact value to the ledger.
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  <span className="text-xs font-bold text-emerald-900">+</span>
                  <input
                    type="number"
                    min={1}
                    max={500}
                    value={rewardPoints}
                    onChange={(e) => setRewardPoints(parseInt(e.target.value) || 0)}
                    className="w-24 text-center font-black text-emerald-950 text-base py-1.5 rounded-xl border border-emerald-300 bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  />
                  <span className="text-xs font-bold text-emerald-900">EcoPoints</span>
                </div>
              </div>

              {/* Grid: Type & Recurrence */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                    Challenge Type <span className="text-rose-500">*</span>
                  </label>
                  <select
                    value={challengeType}
                    onChange={(e) => handleChallengeTypeChange(e.target.value as ChallengeType)}
                    className="w-full text-xs font-semibold px-3 py-2.5 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 text-slate-900 bg-white"
                  >
                    <option value="report_issue">Report an Issue (Any valid report)</option>
                    <option value="category_reporting">Category-Specific Reporting</option>
                    <option value="building_reporting">Building-Specific Reporting</option>
                    <option value="multiple_reports">Multiple Reports (Milestone target)</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                    Repeat Recurrence <span className="text-rose-500">*</span>
                  </label>
                  <select
                    value={recurrenceType}
                    onChange={(e) => setRecurrenceType(e.target.value as ChallengeRecurrence)}
                    className="w-full text-xs font-semibold px-3 py-2.5 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-emerald-500/20 text-slate-900 bg-white"
                  >
                    <option value="daily">Daily Challenge (Resets at midnight IST)</option>
                    <option value="weekly">Weekly Challenge (Resets weekly)</option>
                    <option value="one_time">One-Time Challenge (Lifetime completion)</option>
                  </select>
                </div>
              </div>

              {/* Conditional Criteria: Category, Building, Target Count */}
              <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200 space-y-4">
                <span className="text-xs font-bold text-slate-700 uppercase tracking-wider block">
                  Verifiable Completion Criteria
                </span>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  {/* Category */}
                  <div>
                    <label className="block text-[11px] font-bold text-slate-600 mb-1">
                      Required Category
                    </label>
                    <select
                      value={category}
                      onChange={(e) => setCategory(e.target.value as IssueCategory | 'any')}
                      className="w-full text-xs font-medium px-3 py-2 rounded-xl border border-slate-300 bg-white text-slate-800 focus:outline-none focus:ring-1 focus:ring-emerald-600"
                    >
                      <option value="any">Any Category</option>
                      <option value="waste">Waste</option>
                      <option value="water">Water</option>
                      <option value="electricity">Electricity</option>
                      <option value="cleanliness">Cleanliness</option>
                      <option value="greenery">Greenery</option>
                      <option value="infrastructure">Infrastructure</option>
                      <option value="other">Other</option>
                    </select>
                  </div>

                  {/* Building */}
                  <div>
                    <label className="block text-[11px] font-bold text-slate-600 mb-1">
                      Required Building
                    </label>
                    <select
                      value={buildingId}
                      onChange={(e) => setBuildingId(e.target.value)}
                      className="w-full text-xs font-medium px-3 py-2 rounded-xl border border-slate-300 bg-white text-slate-800 focus:outline-none focus:ring-1 focus:ring-emerald-600"
                    >
                      <option value="any">Any Building (Campus-wide)</option>
                      {buildings.map((b) => (
                        <option key={b.id} value={b.id}>
                          {b.name}
                        </option>
                      ))}
                    </select>
                  </div>

                  {/* Target Count */}
                  <div>
                    <label className="block text-[11px] font-bold text-slate-600 mb-1">
                      Target Reports Required
                    </label>
                    <input
                      type="number"
                      min={1}
                      max={50}
                      value={targetCount}
                      onChange={(e) => setTargetCount(parseInt(e.target.value) || 1)}
                      className="w-full text-xs font-bold px-3 py-2 rounded-xl border border-slate-300 bg-white text-slate-800 focus:outline-none focus:ring-1 focus:ring-emerald-600"
                    />
                  </div>
                </div>
              </div>

              {/* Schedule Dates & Pinned */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 p-4 bg-slate-50 rounded-2xl border border-slate-200">
                <div>
                  <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-600 mb-1 flex items-center gap-1.5">
                    <Calendar className="w-3.5 h-3.5 text-emerald-600" />
                    Start Date & Time
                  </label>
                  <input
                    type="datetime-local"
                    value={startsAt}
                    onChange={(e) => setStartsAt(e.target.value)}
                    className="w-full text-xs font-medium px-3 py-2 rounded-xl border border-slate-300 bg-white text-slate-800"
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-600 mb-1 flex items-center gap-1.5">
                    <Calendar className="w-3.5 h-3.5 text-amber-600" />
                    End Date & Time (Optional)
                  </label>
                  <input
                    type="datetime-local"
                    value={endsAt}
                    onChange={(e) => setEndsAt(e.target.value)}
                    className="w-full text-xs font-medium px-3 py-2 rounded-xl border border-slate-300 bg-white text-slate-800"
                  />
                </div>
              </div>

              {/* Pinned Toggle */}
              <div className="flex items-center gap-3">
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={isPinned}
                    onChange={(e) => setIsPinned(e.target.checked)}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600"></div>
                </label>
                <div>
                  <span className="text-xs font-bold text-slate-800 flex items-center gap-1">
                    <Pin className="w-3.5 h-3.5 text-emerald-600" />
                    Feature Challenge at Top
                  </span>
                  <span className="text-[10px] text-slate-400 block">
                    Featured challenges receive prominent placement on student rewards screens.
                  </span>
                </div>
              </div>
            </div>
          ) : (
            /* Student Mobile Preview */
            <div className="py-4 flex flex-col items-center">
              <p className="text-xs text-slate-500 mb-4 flex items-center gap-1.5">
                <Sparkles className="w-4 h-4 text-emerald-600" />
                This is how the challenge will render on student mobile devices:
              </p>

              {/* Mobile Phone Mockup */}
              <div className="w-full max-w-sm bg-white rounded-3xl border-4 border-slate-800 shadow-2xl overflow-hidden">
                <div className="bg-slate-800 h-5 w-full flex items-center justify-center">
                  <div className="w-16 h-2.5 bg-slate-900 rounded-full" />
                </div>

                <div className="p-4 bg-[#F8FAF8]">
                  {/* Challenge Card in App */}
                  <div className="bg-white rounded-2xl p-4 border border-slate-200 shadow-sm space-y-3">
                    {/* Top Row: Type, Recurrence, Points */}
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                          {recurrenceType.toUpperCase()}
                        </span>
                        {category !== 'any' && (
                          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 border border-blue-200">
                            {category.toUpperCase()}
                          </span>
                        )}
                      </div>

                      {/* EcoPoints Badge */}
                      <span className="px-2.5 py-1 rounded-full bg-amber-50 text-amber-900 border border-amber-200 text-xs font-black flex items-center gap-1">
                        <Coins className="w-3.5 h-3.5 text-amber-600" />
                        +{rewardPoints} PTS
                      </span>
                    </div>

                    {/* Title */}
                    <h3 className="text-sm font-bold text-slate-900 leading-snug">
                      {title.trim() || 'Challenge Title Preview'}
                    </h3>

                    {/* Description */}
                    <p className="text-xs text-slate-600 leading-relaxed">
                      {description.trim() || 'Challenge description for students...'}
                    </p>

                    {/* Location or requirements note */}
                    {selectedBuildingName && (
                      <div className="text-[11px] text-slate-500 flex items-center gap-1">
                        <Building2 className="w-3 h-3 text-emerald-600" />
                        <span>Requires report in: <strong>{selectedBuildingName}</strong></span>
                      </div>
                    )}

                    {/* Progress Bar Simulation */}
                    <div className="pt-2 border-t border-slate-100">
                      <div className="flex items-center justify-between text-[11px] font-bold mb-1">
                        <span className="text-slate-500">Progress</span>
                        <span className="text-emerald-700">0 / {targetCount} completed</span>
                      </div>
                      <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                        <div className="bg-emerald-600 h-full w-0 rounded-full" />
                      </div>
                    </div>

                    {/* CTA Button */}
                    <button className="w-full py-2 bg-emerald-700 text-white rounded-xl text-xs font-bold text-center mt-2 shadow-sm">
                      Report Issue to Complete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="p-4 sm:p-5 bg-slate-50 border-t border-slate-200 flex flex-col sm:flex-row items-center justify-between gap-3 shrink-0">
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-slate-500">
              Reward:{' '}
              <strong className="text-emerald-700 font-bold">
                +{rewardPoints} EcoPoints
              </strong>
            </span>
          </div>

          <div className="flex items-center gap-2 w-full sm:w-auto justify-end">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900 bg-white border border-slate-200 rounded-xl hover:bg-slate-100 transition-colors"
            >
              Cancel
            </button>

            {/* Save Draft */}
            <button
              type="button"
              disabled={isSubmitting}
              onClick={() => handleSave('draft')}
              className="px-4 py-2 text-xs font-bold text-slate-700 bg-slate-200 hover:bg-slate-300 rounded-xl transition-colors disabled:opacity-50"
            >
              Save Draft
            </button>

            {/* Publish or Update */}
            <button
              type="button"
              disabled={isSubmitting}
              onClick={() => handleSave('published')}
              className="px-5 py-2 text-xs font-bold text-white bg-emerald-700 hover:bg-emerald-800 rounded-xl transition-all shadow-md shadow-emerald-900/10 flex items-center gap-1.5 disabled:opacity-50"
            >
              <CheckCircle2 className="w-4 h-4" />
              {isSubmitting ? 'Saving...' : 'Publish Challenge'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
