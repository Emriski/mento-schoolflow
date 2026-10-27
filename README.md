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
