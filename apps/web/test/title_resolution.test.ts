import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveReportTitle } from '../src/lib/utils';
import type { ReportTitleContext } from '../src/lib/utils';

test('resolveReportTitle uses existing title when present', () => {
  const report: ReportTitleContext = {
    title: 'Broken Solar Inverter',
    issue_label: 'Broken Solar Inverter',
    description: 'Inverter in block C is throwing error code 44.',
    category: 'electricity',
    buildings: { name: 'Engineering Block' },
  };
  assert.equal(resolveReportTitle(report), 'Broken Solar Inverter');
});

test('resolveReportTitle uses issue_label when title is missing or undefined', () => {
  const report: ReportTitleContext = {
    issue_label: 'Severely Overflowing Outdoor Trash Can',
    description: 'Outdoor slatted bin overflowing onto walkway.',
    category: 'waste',
    buildings: { name: 'Main Campus' },
  };
  assert.equal(resolveReportTitle(report), 'Severely Overflowing Outdoor Trash Can');
});

test('resolveReportTitle derives temporary display title from description when title is empty', () => {
  const report: ReportTitleContext = {
    title: '',
    issue_label: '   ',
    description: 'Water is gushing out of the second floor restroom pipe. Need immediate plumber assistance.',
    category: 'water',
    buildings: { name: 'Science Block' },
  };
  assert.equal(
    resolveReportTitle(report),
    'Water is gushing out of the second floor restroom pipe'
  );
});

test('resolveReportTitle truncates long description first sentence cleanly at 60 chars', () => {
  const longSentence = 'Extremely severe hazardous electrical sparks flying from main distribution panel in corridor';
  const report: ReportTitleContext = {
    title: null,
    issue_label: null,
    description: longSentence,
    category: 'electricity',
    buildings: { name: 'Hostel A' },
  };
  const resolved = resolveReportTitle(report);
  assert.ok(resolved.length <= 60);
  assert.ok(resolved.endsWith('...'));
});

test('resolveReportTitle derives truthful neutral label from category and building when description is empty', () => {
  const report: ReportTitleContext = {
    title: '',
    issue_label: '',
    description: '',
    category: 'water',
    buildings: { name: 'Boys Hostel' },
  };
  assert.equal(resolveReportTitle(report), 'Water issue — Boys Hostel');
});

test('resolveReportTitle falls back to Untitled report when no info is available and never Unnamed', () => {
  const report: ReportTitleContext = {
    title: null,
    issue_label: null,
    description: null,
    category: null,
    buildings: null,
  };
  assert.equal(resolveReportTitle(report), 'Untitled report');
  assert.notEqual(resolveReportTitle(report).toLowerCase(), 'unnamed');
});

test('resolveReportTitle rejects literal Unnamed string and uses fallback', () => {
  const report: ReportTitleContext = {
    title: 'Unnamed',
    issue_label: 'Unnamed',
    description: 'Overflowing dustbin near canteen.',
    category: 'waste',
    buildings: { name: 'Student Centre' },
  };
  assert.equal(resolveReportTitle(report), 'Overflowing dustbin near canteen');
});
