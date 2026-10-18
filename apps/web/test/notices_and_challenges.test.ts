import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  getNoticeTypeBadge,
  getNoticePriorityBadge,
  getNoticeStatusBadge,
  getChallengeTypeBadge,
  getChallengeRecurrenceBadge,
} from '../src/lib/utils';

describe('Admin Notice & Challenge UI Utilities', () => {
  test('1. Resolves notice type badges correctly', () => {
    assert.equal(getNoticeTypeBadge('campus_announcement').label, 'Announcement');
    assert.equal(getNoticeTypeBadge('issue_notice').label, 'Issue Notice');
    assert.equal(getNoticeTypeBadge('maintenance_update').label, 'Maintenance');
    assert.equal(getNoticeTypeBadge('utility_notice').label, 'Utility (Water/Power)');
    assert.equal(getNoticeTypeBadge('safety_notice').label, 'Safety Alert');
    assert.equal(getNoticeTypeBadge('general_notice').label, 'General');
  });

  test('2. Resolves notice priority badges with appropriate severity dots', () => {
    const urgent = getNoticePriorityBadge('urgent');
    assert.equal(urgent.label, 'Urgent');
    assert.match(urgent.bg, /rose/);

    const important = getNoticePriorityBadge('important');
    assert.equal(important.label, 'Important');
    assert.match(important.bg, /amber/);

    const normal = getNoticePriorityBadge('normal');
    assert.equal(normal.label, 'Normal');
  });

  test('3. Resolves challenge types and recurrence badges', () => {
    assert.equal(getChallengeTypeBadge('report_issue').label, 'Report Issue');
    assert.equal(getChallengeTypeBadge('category_reporting').label, 'Category Target');
    assert.equal(getChallengeTypeBadge('building_reporting').label, 'Building Target');
    assert.equal(getChallengeTypeBadge('multiple_reports').label, 'Multiple Reports');

    assert.equal(getChallengeRecurrenceBadge('daily').label, 'Daily');
    assert.equal(getChallengeRecurrenceBadge('weekly').label, 'Weekly');
    assert.equal(getChallengeRecurrenceBadge('one_time').label, 'One-Time');
  });

  test('4. Enforces valid customizable points bounds', () => {
    const isValidPointReward = (pts: number) => Number.isInteger(pts) && pts > 0 && pts <= 500;

    assert.equal(isValidPointReward(25), true);
    assert.equal(isValidPointReward(100), true);
    assert.equal(isValidPointReward(500), true);

    assert.equal(isValidPointReward(0), false);
    assert.equal(isValidPointReward(-10), false);
    assert.equal(isValidPointReward(501), false);
    assert.equal(isValidPointReward(12.5), false);
  });
});
