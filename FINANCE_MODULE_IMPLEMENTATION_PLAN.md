# SchoolFlow Finance & Accounts — implementation blueprint

Status: planning specification for the Modern Hybrid redesign branch. This document does not apply or change a production database migration.

## 1. Verified facts from the connected production schema

- `public.profiles` has `id`, `school_id`, `full_name`, and a checked `role` limited to `admin`, `head_teacher`, and `teacher`.
- `public.schools` has `id`, `name`, `created_by`, and `created_at`.
- The deployed `schoolflow_setup_school(p_school_name, p_full_name)` database function inserts a school with `created_by = auth.uid()`, then creates that same user's profile with role `admin`.
- All three current school records have a non-null `created_by` that joins to an `admin` profile in the same school.
- No public function body was found that updates `public.schools.created_by`.
- `public.schools` currently has a SELECT policy for the signed-in school member, but no UPDATE policy.
- `public.school_fee_records` already exists, with amount due, amount paid, a generated payment status, and school-level RLS. Its administrator write/read policy currently checks only `schoolflow_my_role() = 'admin'`. Parents have a separate SELECT policy for records belonging to their linked children.
- No payroll, general-expense, or other-income tables exist yet.
- The current staff portal exposes school fees to every profile whose role is `admin`; that is broader than the requested owner-granted permission model.

### Ownership decision

Use `schools.created_by` as the initial school-owner identity. This is grounded in the actual setup RPC and current rows, not inferred from the word “admin”. A profile is an owner only when its authenticated user ID equals the `created_by` value for its own `school_id`. An invited administrator is not automatically an owner.

Do not add a free-editable owner field to `profiles`, and do not treat every `admin` as an owner. Any future ownership transfer must be an explicit audited owner-transfer operation with a re-authentication/confirmation flow. Keep the existing creator identity stable until that feature is designed.

Before the first live migration, re-run a preflight query that rejects migration if any existing school has a null `created_by`, no matching profile, a mismatched profile school, or a creator whose profile is not `admin`. Do not silently guess an owner for an exception.

## 2. Access model

### Owner

The owner receives all Finance permissions implicitly. The owner alone can grant, revoke, and inspect all administrator Finance permission assignments. Owner access must not depend on a grant row, so an owner cannot lock themselves out by deleting their own permission.

### Administrators

Only a profile with role `admin` can receive individual Finance permissions. A standard administrator receives no Finance access until the owner explicitly grants it. Head teachers, teachers, and parents receive no Finance access.

Permissions are additive and school-scoped. Each grant is keyed by `school_id + admin_user_id + permission_key`. Revoking a grant removes it immediately on the next database request; do not cache authorization in browser state or long-lived JWT custom claims.

### Permission catalogue

| Key | Capability |
|---|---|
| `finance.overview.view` | View the Finance summary |
| `finance.fees.view` | View school-fee schedules, balances and collections |
| `finance.fees.record` | Create or update fee records / record fee payments |
| `finance.income.view` | View non-fee income |
| `finance.income.record` | Record other school income |
| `finance.expenses.view` | View expenses |
| `finance.expenses.record` | Record or edit expenses |
| `finance.expenses.approve` | Approve or reject submitted expenses |
| `finance.payroll.view` | View salary arrangements and payroll totals |
| `finance.payroll.manage` | Create or update salary arrangements |
| `finance.payroll.payments.record` | Record full or partial salary payments |
| `finance.payroll.payments.approve` | Approve salary-payment records, where approval is enabled |
| `finance.reports.view` | View and export financial reports |
| `finance.audit.view` | View Finance audit history |

Permission management itself is not a grantable key. It remains owner-only.

## 3. Suggested data model

All Finance tables must include `school_id NOT NULL REFERENCES public.schools(id)`, appropriate timestamps, creator/recorder references, constraints and indexes. Use `numeric(14,2)` for money; do not use floating-point types. Store currency explicitly (default `NGN`) rather than baking the currency symbol into data.

1. **`school_finance_permissions`** — one row per owner-approved admin permission. Fields: `school_id`, `admin_user_id`, `permission_key`, `granted_by`, `granted_at`. Unique constraint on the first three. Validate that the target profile belongs to the same school and currently has role `admin`.
2. **`school_salary_records`** — salary terms for one school staff profile, with amount, currency, frequency, effective dates and active/archived status. Keep salary data separate from the public staff directory.
3. **`school_salary_payments`** — individual payroll payment entries linked to a salary record and staff member. Multiple entries in one pay period support part-payments. Include amount, pay-period start/end, paid date, payment method/reference, recorder, approval state and approver. This is a record-keeping ledger only; no bank-transfer integration in the first release.
4. **`school_expenses`** — category, payee/vendor, description, amount, incurred date, payment method/reference, recorded by, approval status, approver and timestamps. Keep draft/pending/approved/rejected states explicit.
5. **`school_income_records`** — non-fee income source/category, description, amount, received date, reference and recorder. Do not duplicate fee income here.
6. **`school_finance_audit_log`** — append-only events for permission grants/revocations and financial record create/update/approval actions. Store school, actor, event, affected table/record ID, timestamp, and bounded before/after JSON snapshots. Never expose this table to parents or teachers.

### Existing school fees

Retain `school_fee_records` as the current fee obligation/collection summary to avoid a destructive rewrite. Replace its staff-side “all admins” RLS rule with distinct view and record permissions. Preserve the existing parent read policy for linked children. For an accurate transaction history and receipt-level audit, introduce a separate `school_fee_payments` ledger and reconcile its totals with `school_fee_records.amount_paid`; do not pretend the existing aggregate amount_paid field is a full transaction ledger.

## 4. RLS and database enforcement

- Enable RLS on every new public table.
- Grant only the necessary table privileges to `authenticated`; grant no Finance privileges to `anon`.
- Owner checks must bind `auth.uid()` to `schools.created_by` for the caller's own `school_id`.
- The permission table may be read by the owner and by an admin for that admin's own grant rows. Only the school owner may INSERT/UPDATE/DELETE grants. Target users must be current same-school admins.
- Business tables require the matching read or write permission in RLS `USING` and `WITH CHECK` policies, and must verify the row's `school_id` equals the caller's school. Write policies must prevent moving a row to another school.
- For record approval, require the approval permission and record the approver. Consider preventing self-approval for expense/payment actions as a separation-of-duties rule; owner override should be explicit and audited if adopted.
- Audit rows are insert-only for trusted database trigger logic. Authenticated clients should have SELECT only through the dedicated audit-view permission, and no UPDATE/DELETE access.
- Keep owner authorization independent of the permission grant table. Keep `finance.manage_permissions` owner-only, not configurable.
- Avoid authorization decisions based on editable user metadata or stale JWT role claims. Query the trusted database profile and owner/grant records.
- Prefer simple RLS predicates. If a helper function is required to avoid policy recursion, place it in a non-exposed schema, harden its search path, verify `auth.uid()` inside it, and grant EXECUTE only to the intended role. Do not add broad PUBLIC-executable SECURITY DEFINER functions to `public`.

### Data API exposure

Supabase changed the default for newly created public tables: tables created after 2026-10-30 are no longer automatically exposed through the Data API. The migration must explicitly grant only the required `SELECT/INSERT/UPDATE/DELETE` table privileges to `authenticated`, enable RLS, and rely on the RLS policies for row authorization. Do not grant `anon` access.

## 5. Finance user experience

- Add a Finance navigation group only after the current user's owner/grant state has been loaded and confirmed.
- Owner sees all Finance pages plus **Finance permissions**.
- An administrator sees only the pages permitted by their grants. Hide unavailable pages in navigation, but treat RLS as the actual security boundary.
- Finance landing page: school name, reporting period, verified fee collections, other income, expenses, payroll totals and outstanding balances, each calculated from authorized live records.
- Payroll: salary register, staff, salary frequency, period, paid amount, outstanding amount and payment history; allow several payment entries to settle one payroll period.
- Expenses: register, categories, approval queue, dates, references and export.
- Income: non-fee receipts and fee collections with separate totals.
- Reports: date/term filters, printable view and CSV/PDF exports.
- Permissions screen: owner chooses one administrator and checks exact capabilities; show clear read vs record vs approve distinctions and a confirmation summary before saving.
- Keep monetary totals out of generic staff dashboards for anyone without the corresponding Finance permissions.

## 6. Implementation sequence

1. **Preflight and tests (read-only):** Reconfirm all creator/profile mappings, school IDs, current table policies, function privileges, and whether any legacy exceptions exist.
2. **Migration draft on the redesign branch:** Add schema, permission catalogue, helper functions, RLS, grants, audit triggers and indexes. Do not apply it to production.
3. **Automated authorization tests:** Owner full access; ungranted admin denied; each permission grants only its function; head teacher/teacher/parent denied; cross-school access denied; users cannot grant themselves access; permission revocation takes effect; audit events immutable; partial payroll payments total correctly.
4. **Finance UI on the redesign branch:** Render nav and pages only from server-confirmed grants, while keeping RLS as the enforcement layer.
5. **Isolated staging database:** Test with synthetic school, owner, two admins with different grants, head teacher, teacher and parent. Do not use the production project for interactive preview actions.
6. **Owner review:** Inspect the exact permissions and sample financial screens; only then consider a separate approved production migration and release.

## 7. Acceptance criteria

- An ordinary administrator cannot read payroll, expenses, income or fee data until explicitly granted the matching permission.
- An administrator with read-only access cannot create, edit, approve or export restricted data.
- An admin granted payroll access cannot automatically see expenses or other income.
- Head teachers, teachers and parents cannot discover the Finance module or query its data.
- The owner always retains all Finance access and sole control of grants.
- Cross-school reads and writes fail even if IDs are guessed.
- Every grant/revoke and financial write/approval is attributable and auditable.
- Full and partial salary payments reconcile to the outstanding balance.
- No actual money is transferred in phase one.
- All existing parent fee visibility and existing non-Finance workflows continue to work.

## 8. Preview visibility and release note

The redesigned staff/parent pages are committed to `redesign/modern-hybrid-admin-portals` and the branch has a READY Vercel preview deployment. The production domain remains on `main`, and the root route redirects to the staff portal. To see the changed UI before release, open the branch preview's `/portal.html` or `/parent.html` URL and sign in there; preview browser storage is separate from the production hostname. The preview currently uses the production Supabase project, so use it for visual inspection only until an isolated staging project is connected.
