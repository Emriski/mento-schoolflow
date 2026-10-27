# Mento SchoolFlow

A responsive school-operations prototype from Mento Solutions, designed for Nigerian primary and secondary schools.

## Dashboard redesign

The Overview dashboard now uses a deep-indigo school header, lavender page canvas, white rounded cards, filter controls, KPI trend strips, an attendance donut, grouped class-result bars, student spotlights, student-detail cards and circular average-score rings. Student avatars use initials rather than illustrations.

### Dashboard component renderers

All Overview sections are kept as separate render functions in [components/dashboard.js](components/dashboard.js):

- `renderDashboardIntro()` — dashboard title, date and primary actions
- `renderDashboardFilters()` — class, term, assessment and session filters
- `renderKpiCards()` — student, attendance, class and review KPIs with trend strips
- `renderPerformanceBars()` — grouped exam-result chart, using a single-color family
- `renderAttendanceDonut()` — consistent school-level present/late/absent totals
- `renderSpotlightCards()` — Best in Marks, Best in Attendance and two improvement spotlights
- `renderStudentDetails()` — academic performer, support and latest-record cards
- `renderAverageRings()` — class average score rings
- `renderRecentAttendance()` — recent register preview
- `renderQuickActions()` — shortcuts to existing pages
- `renderOverview()` — assembles the components and preserves selected filters

## Theme and styles

- [`theme.css`](theme.css) is the single source of truth for colors, fonts, radii, shadows and spacing tokens.
- [`styles.css`](styles.css) contains layout and responsive rules that reference those theme tokens.
- [`index.html`](index.html) retains the existing app shell and non-dashboard pages.
- [`components/dashboard.js`](components/dashboard.js) contains the dashboard section renderers.

To make a global visual adjustment, edit a token in `theme.css`. To move or resize a dashboard section, adjust the component markup in `components/dashboard.js` and its class rules in `styles.css`.

## Supabase staff portal (early implementation)

Open [portal.html](portal.html) to use the separate staff portal backed by the `schoolflow-production` Supabase project. The main `index.html` dashboard remains the fictional-data prototype and should not be used for real records.

The portal currently includes:
- Email/password sign-in and first-school administrator setup
- Staff invitation acceptance for teacher and headteacher roles
- Class creation, optional teacher assignment and student creation
- Date-specific attendance sessions and Present / Late / Absent marking
- Database-backed attendance submission that leadership can review across devices
- Role-aware class selection, backed by Supabase row-level security

Security and data integrity work: privileged functions are no longer executable by the unauthenticated `anon` role; school setup blocks accounts with a pending staff invitation; class/student/attendance policies now validate school and class relationships; and unique database constraints prevent duplicate daily class registers and duplicate student records within a register. Supabase's advisor still reports that the intentionally authenticated, role-checked `SECURITY DEFINER` functions are callable by signed-in users; review these functions before production.

Deployment and testing status: portal code is committed, and database policies were verified by querying the live schema. The Vercel deployment could not be verified from this session, and a full end-to-end test with separate administrator and teacher accounts is still required. Configure Supabase Auth email confirmation and recovery settings before production use. Do not enter real student records until access policies and account flows have been tested.

## Existing features preserved

- Student directory with search, class filtering, add-student workflow and CSV export
- Daily attendance register with status updates and CSV export
- Teacher-assistant template generator for lesson notes and classroom materials
- Assessment score entry with automatic totals and grade bands
- Printable draft report card
- Class directory and school settings preview
- Responsive desktop/mobile layout and browser-local demo persistence

## Attendance and sample-data notes

The school-level overview displays a 248-student summary with 213 present, 14 late and 21 absent; those counts add up to 248 and the attendance percentage is shown only once in the donut. The editable register still contains the 12 fictional sample records available in this prototype, so its local counts are intentionally separate from the school-level summary.

The two “Most Improved” cards do not invent historic performance: they explain that previous-term scores or registers are needed to calculate real improvement. The current prototype does not yet store historical term data.

## Run locally

Open `index.html` in a modern browser. No build step or dependencies are required.

## Important limitations

This is a frontend prototype, not a production school information system. It has no secure login, server-side database, multi-user synchronization, live AI provider, parent messaging, payments, backups, or production security controls. Demo records are fictional. Do not enter real student or guardian information until access controls, privacy safeguards, server-side validation, backups, and applicable data-protection requirements have been implemented and tested.
