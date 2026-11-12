# SchoolFlow Finance Management — Implementation Plan

## Goal
Build a school finance workspace for recording and reviewing school finances. The first release is an internal ledger and reporting system; it does not initiate bank transfers or payment-gateway transactions.

## Existing system facts
- Staff profiles use one `school_id` and one role (`admin`, `head_teacher`, `teacher`).
- `school_fee_records` already stores one fee obligation per student/academic year/term with `amount_due`, `amount_paid`, `payment_status`, `recorded_by`, and timestamps.
- Current fee-record RLS allows same-school admins to manage records; linked parents can read their students' fee records.
- Do not replace or destructively alter the existing fee records. Add a payment ledger and preserve the current parent fee-read experience.

## Access model
Finance is hidden in the UI when a user lacks access, but authorization must also be enforced by Postgres RLS on every finance table.
- School owner: full finance access and sole authority to grant/revoke finance permissions.
- Explicitly authorized admins: only the finance permissions granted to them.
- Head teachers, teachers, parents: no finance access by default.
- Do not rely on `raw_user_meta_data` or client-side role checks for authorization.
- Existing `schools.created_by` is a possible owner anchor, but confirm and formalize the owner rule before using it in production policies. Do not infer ownership from a user-editable profile field.

## Permissions
- `finance.overview.view`
- `finance.fees.view`, `finance.fees.record`
- `finance.income.view`, `finance.income.record`
- `finance.expenses.view`, `finance.expenses.record`, `finance.expenses.approve`
- `finance.payroll.view`, `finance.payroll.manage`, `finance.payroll.payments.record`, `finance.payroll.payments.approve`
- `finance.reports.view`
- `finance.audit.view`
Only the school owner can manage grants. Admins cannot delegate finance permissions.

## Data model proposal
1. `school_finance_permissions`: school, user, permission key, granted by, created/revoked timestamps. Unique active grant per school/user/permission.
2. `school_fee_payments`: append-only fee receipts linked to `school_fee_records`, school, student, amount, payment date, method, reference, note, received by, created timestamp. Amount must be positive. Do not allow silent edits/deletes; corrections use reversal/void records with reason and audit entry.
3. `school_income_records`: other income categories, amount, date, source/reference, note, recorder, approval state if needed.
4. `school_expenses`: category, description, amount, date, supplier/payee, receipt attachment path, status (draft/submitted/approved/rejected/paid/void), requested by, approved by, paid by, timestamps.
5. `school_salary_records`: staff member, pay period, gross/net amount, currency, status, notes, created by. Avoid exposing salary details to the staff member unless a dedicated payslip policy is designed.
6. `school_salary_payments`: salary record, amount, payment date/method/reference, recorded by, approval metadata. Support partial payments and outstanding balances.
7. `school_finance_audit_log`: school, actor, action, entity/table, entity id, before/after JSON, reason, timestamp. Restrict reads to audit permission; write via controlled database operations.

## Core workflows
- Record fee payments as separate receipts and calculate totals against the existing fee obligation.
- Record income and expenses; require approval for expenses before marking them paid.
- Create salary records per staff/pay period; allow multiple partial salary payments and show remaining balance.
- Keep a clear audit trail. Never silently overwrite posted financial transactions.
- Reports: cash received, other income, expenses, payroll liabilities/payments, fee balances, and date-range summaries.
- Currency is configured per school; do not hard-code NGN in storage. Display the school's configured currency.

## UI navigation
Add a Finance section with:
- Overview
- Fees & collections
- Income
- Expenses & approvals
- Payroll
- Reports
- Audit trail
- Finance access (owner only)

## Delivery phases
1. Confirm owner identity/ownership source, currency requirements, approval rules, and current fee-record data shape.
2. Implement database migration with constraints, indexes, RLS, and permission-management rules. Test owner, authorized admin, unauthorized admin, teacher, and parent access.
3. Build finance UI and connect each screen to the secured schema.
4. Add reporting, exports, and audit review.
5. Test in preview with separate test accounts before any production rollout.

## Safety / accounting rules
- No bank transfers in v1.
- Store monetary values as fixed-precision numeric, never floating-point.
- Prevent negative payments and overpayments unless an explicitly designed credit/refund workflow exists.
- Use transaction-safe database functions for posting a receipt/payment and updating any related balance.
- Use reversal entries rather than deleting posted financial records.
- Keep all records scoped to `school_id`; test cross-school isolation.
- Do not seed fake transactions in production.
- Do not apply schema changes to production until the migration and access tests are reviewed.
