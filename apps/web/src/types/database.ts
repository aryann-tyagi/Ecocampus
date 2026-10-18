export type IssueCategory =
  | 'waste'
  | 'water'
  | 'electricity'
  | 'infrastructure'
  | 'greenery'
  | 'cleanliness'
  | 'other';

export type IssueSeverity = 'low' | 'medium' | 'high' | 'critical';

export type ReportStatus =
  | 'REPORTED'
  | 'ASSIGNED'
  | 'IN_PROGRESS'
  | 'RESOLVED';

export type UserRole = 'student' | 'staff' | 'admin';

export interface Department {
  id: string;
  name: string;
  slug: string;
  active: boolean;
  created_at: string;
}

export interface Building {
  id: string;
  name: string;
  slug: string;
  active: boolean;
  zone?: string | null;
}

export interface Floor {
  id: string;
  building_id: string;
  label: string;
  sort_order: number;
  active: boolean;
}

export interface ReportStatusEvent {
  id: string;
  report_id: string;
  from_status: ReportStatus | null;
  to_status: ReportStatus;
  actor_id: string | null;
  actor_email?: string | null;
  actor_role?: string | null;
  note: string | null;
  occurred_at: string;
}

export interface ReportMedia {
  id: string;
  report_id: string;
  storage_path: string;
  mime_type: string;
  position: number;
  created_at: string;
}

export interface ReportItem {
  id: string;
  reporter_id: string;
  title: string;
  issue_label?: string | null;
  description: string;
  category: IssueCategory;
  severity: IssueSeverity;
  status: ReportStatus;
  building_id: string;
  floor_id: string | null;
  floor_text: string | null;
  location_details: string;
  suggested_department_id: string | null;
  suggested_department_label: string | null;
  assigned_department_id: string | null;
  latitude: number | null;
  longitude: number | null;
  created_at: string;
  updated_at: string;

  // Joined relations
  buildings?: { id: string; name: string; slug: string } | null;
  floors?: { id: string; label: string } | null;
  assigned_department?: { id: string; name: string; slug: string } | null;
  suggested_department?: { id: string; name: string; slug: string } | null;
  report_media?: ReportMedia[];
  report_status_events?: ReportStatusEvent[];
}

export interface DashboardMetrics {
  total: number;
  newReported: number;
  assigned: number;
  inProgress: number;
  resolved: number;
  critical: number;
}

export interface NotificationItem {
  id: string;
  user_id: string;
  report_id: string;
  status_event_id: string | null;
  event_type: string;
  title: string;
  message: string;
  is_read: boolean;
  read_at: string | null;
  created_at: string;
}

export type NoticeType =
  | 'issue_notice'
  | 'campus_announcement'
  | 'maintenance_update'
  | 'utility_notice'
  | 'safety_notice'
  | 'general_notice';

export type NoticePriority = 'normal' | 'important' | 'urgent';

export type NoticeStatus = 'draft' | 'published' | 'archived';

export interface CampusNotice {
  id: string;
  title: string;
  message: string;
  summary: string | null;
  notice_type: NoticeType;
  priority: NoticePriority;
  status: NoticeStatus;
  target_building_id: string | null;
  is_pinned: boolean;
  starts_at: string;
  expires_at: string | null;
  created_by: string;
  published_at: string | null;
  created_at: string;
  updated_at: string;
  target_building?: { id: string; name: string } | null;
}

export type ChallengeType =
  | 'report_issue'
  | 'category_reporting'
  | 'building_reporting'
  | 'multiple_reports';

export type ChallengeRecurrence = 'one_time' | 'daily' | 'weekly';

export type ChallengeStatus = 'draft' | 'published' | 'archived';

export interface ChallengeItem {
  id: string;
  challenge_key: string;
  title: string;
  description: string;
  instructions: string;
  challenge_type: ChallengeType;
  category: IssueCategory | null;
  building_id: string | null;
  target_count: number;
  reward_points: number;
  recurrence_type: ChallengeRecurrence;
  status: ChallengeStatus;
  is_pinned: boolean;
  starts_at: string;
  ends_at: string | null;
  created_at: string;
  updated_at: string;
  buildings?: { id: string; name: string } | null;
  completions_count?: number;
}
