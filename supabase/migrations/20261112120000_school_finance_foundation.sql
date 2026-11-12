-- SchoolFlow Finance foundation (reviewed migration draft)
-- This file is intentionally committed to the feature branch only.
-- Do not apply to production until owner identity and RLS tests are reviewed.

begin;

alter table public.schools
  add column if not exists currency_code text not null default 'NGN',
  add column if not exists currency_symbol text not null default '₦',
  add constraint schools_currency_code_format
    check (currency_code ~ '^[A-Z]{3}$') not valid;

create unique index if not exists profiles_id_school_id_uidx on public.profiles(id, school_id);

create table if not exists public.school_finance_permissions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  permission_key text not null check (permission_key in (
    'finance.overview.view',
    'finance.fees.view','finance.fees.record',
    'finance.income.view','finance.income.record',
    'finance.expenses.view','finance.expenses.record','finance.expenses.approve',
    'finance.payroll.view','finance.payroll.manage',
    'finance.payroll.payments.record','finance.payroll.payments.approve',
    'finance.reports.view','finance.audit.view'
  )),
  granted_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(id),
  constraint school_finance_permissions_user_school_fk
    foreign key (user_id, school_id) references public.profiles(id, school_id)
);

-- Composite FK is backed by the unique index created before this table.
create unique index if not exists school_finance_permissions_active_uidx
  on public.school_finance_permissions(school_id,user_id,permission_key)
  where revoked_at is null;
create index if not exists school_finance_permissions_user_idx
  on public.school_finance_permissions(user_id,school_id) where revoked_at is null;

create table if not exists public.school_fee_payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  fee_record_id uuid not null references public.school_fee_records(id),
  amount numeric(14,2) not null check (amount > 0),
  paid_at timestamptz not null default now(),
  payment_method text not null default 'other'
    check (payment_method in ('cash','bank_transfer','pos','online','cheque','other')),
  reference text,
  note text,
  received_by uuid not null references public.profiles(id),
  status text not null default 'posted' check (status in ('posted','reversed')),
  reversed_at timestamptz,
  reversed_by uuid references public.profiles(id),
  reversal_reason text,
  created_at timestamptz not null default now(),
  constraint school_fee_payments_record_school_fk foreign key (fee_record_id, school_id)
    references public.school_fee_records(id, school_id),
  constraint school_fee_payments_reversal_check check (
    (status='posted' and reversed_at is null and reversed_by is null and reversal_reason is null)
    or (status='reversed' and reversed_at is not null and reversed_by is not null and length(trim(coalesce(reversal_reason,'')))>0)
  )
);
create index if not exists school_fee_payments_record_idx on public.school_fee_payments(fee_record_id,paid_at desc);
create index if not exists school_fee_payments_school_idx on public.school_fee_payments(school_id,paid_at desc);

create table if not exists public.school_income_records (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  category text not null,
  description text not null,
  amount numeric(14,2) not null check (amount > 0),
  received_at timestamptz not null default now(),
  source text,
  reference text,
  note text,
  recorded_by uuid not null references public.profiles(id),
  status text not null default 'posted' check (status in ('posted','void')),
  voided_at timestamptz,
  voided_by uuid references public.profiles(id),
  void_reason text,
  created_at timestamptz not null default now(),
  check ((status='posted' and voided_at is null and voided_by is null and void_reason is null)
      or (status='void' and voided_at is not null and voided_by is not null and length(trim(coalesce(void_reason,'')))>0))
);
create index if not exists school_income_records_school_date_idx on public.school_income_records(school_id,received_at desc);

create table if not exists public.school_expenses (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  category text not null,
  description text not null,
  amount numeric(14,2) not null check (amount > 0),
  expense_date date not null default current_date,
  supplier text,
  receipt_path text,
  status text not null default 'draft'
    check (status in ('draft','submitted','approved','rejected','paid','void')),
  requested_by uuid not null references public.profiles(id),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  rejection_reason text,
  paid_by uuid references public.profiles(id),
  paid_at timestamptz,
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status not in ('approved','paid') or (approved_by is not null and approved_at is not null))),
  check (status <> 'paid' or (paid_by is not null and paid_at is not null)),
  check (status <> 'rejected' or length(trim(coalesce(rejection_reason,'')))>0)
);
create index if not exists school_expenses_school_date_idx on public.school_expenses(school_id,expense_date desc);

create table if not exists public.school_salary_records (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  staff_user_id uuid not null,
  pay_period_start date not null,
  pay_period_end date not null,
  gross_amount numeric(14,2) not null check (gross_amount >= 0),
  deductions numeric(14,2) not null default 0 check (deductions >= 0),
  net_amount numeric(14,2) generated always as (gross_amount-deductions) stored,
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  note text,
  status text not null default 'open' check (status in ('open','paid','void')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (pay_period_end >= pay_period_start),
  check (deductions <= gross_amount),
  constraint school_salary_staff_school_fk
    foreign key (staff_user_id,school_id) references public.profiles(id,school_id),
  constraint school_salary_records_id_school_uidx unique (id, school_id)
);
create index if not exists school_salary_records_period_idx on public.school_salary_records(school_id,pay_period_end desc);

create table if not exists public.school_salary_payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  salary_record_id uuid not null references public.school_salary_records(id),
  amount numeric(14,2) not null check (amount > 0),
  paid_at timestamptz not null default now(),
  payment_method text not null default 'other'
    check (payment_method in ('cash','bank_transfer','pos','online','cheque','other')),
  reference text,
  note text,
  recorded_by uuid not null references public.profiles(id),
  status text not null default 'posted' check (status in ('posted','reversed')),
  reversed_at timestamptz,
  reversed_by uuid references public.profiles(id),
  reversal_reason text,
  created_at timestamptz not null default now(),
  constraint school_salary_payments_record_school_fk foreign key (salary_record_id, school_id)
    references public.school_salary_records(id, school_id),
  check ((status='posted' and reversed_at is null and reversed_by is null and reversal_reason is null)
      or (status='reversed' and reversed_at is not null and reversed_by is not null and length(trim(coalesce(reversal_reason,'')))>0))
);
create index if not exists school_salary_payments_record_idx on public.school_salary_payments(salary_record_id,paid_at desc);

create table if not exists public.school_finance_audit_log (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id),
  actor_user_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  reason text,
  created_at timestamptz not null default now()
);
create index if not exists school_finance_audit_school_date_idx on public.school_finance_audit_log(school_id,created_at desc);

-- Finance owner is the immutable school creator. Permissions are always evaluated server-side.
create or replace function public.schoolflow_is_finance_owner(p_school_id uuid)
returns boolean language sql stable security definer set search_path=public
as $$
  select exists (
    select 1 from public.schools s
    where s.id=p_school_id and s.created_by=auth.uid()
  );
$$;

create or replace function public.schoolflow_has_finance_permission(p_school_id uuid,p_permission text)
returns boolean language sql stable security definer set search_path=public
as $$
  select public.schoolflow_is_finance_owner(p_school_id)
    or exists (
      select 1 from public.school_finance_permissions fp
      join public.profiles p on p.id=fp.user_id and p.school_id=fp.school_id
      where fp.school_id=p_school_id and fp.user_id=auth.uid()
        and fp.permission_key=p_permission and fp.revoked_at is null
        and p.role='admin'
    );
$$;

create or replace function public.schoolflow_finance_can_view(p_school_id uuid)
returns boolean language sql stable security definer set search_path=public
as $$
  select public.schoolflow_has_finance_permission(p_school_id,'finance.overview.view')
    or public.schoolflow_has_finance_permission(p_school_id,'finance.fees.view')
    or public.schoolflow_has_finance_permission(p_school_id,'finance.income.view')
    or public.schoolflow_has_finance_permission(p_school_id,'finance.expenses.view')
    or public.schoolflow_has_finance_permission(p_school_id,'finance.payroll.view')
    or public.schoolflow_has_finance_permission(p_school_id,'finance.reports.view')
    or public.schoolflow_has_finance_permission(p_school_id,'finance.audit.view');
$$;

-- Permission grants/revocations are owner-only. A grant can only target an admin in that school.
alter table public.school_finance_permissions enable row level security;
create policy finance_permissions_owner_read on public.school_finance_permissions
  for select using (public.schoolflow_is_finance_owner(school_id) or user_id=auth.uid());
create policy finance_permissions_owner_insert on public.school_finance_permissions
  for insert with check (
    public.schoolflow_is_finance_owner(school_id)
    and granted_by=auth.uid()
    and exists(select 1 from public.profiles p where p.id=school_finance_permissions.user_id and p.school_id=school_finance_permissions.school_id and p.role='admin')
  );
-- Grant revocation will be handled by a narrowly scoped database function; no direct update/delete.

alter table public.school_fee_payments enable row level security;
create policy finance_fee_payments_read on public.school_fee_payments for select
  using (school_id=public.schoolflow_my_school_id() and public.schoolflow_has_finance_permission(school_id,'finance.fees.view'));
create policy finance_fee_payments_insert on public.school_fee_payments for insert
  with check (school_id=public.schoolflow_my_school_id() and received_by=auth.uid()
    and public.schoolflow_has_finance_permission(school_id,'finance.fees.record')
    and exists(select 1 from public.school_fee_records fr where fr.id=school_fee_payments.fee_record_id and fr.school_id=school_fee_payments.school_id));

alter table public.school_income_records enable row level security;
create policy finance_income_read on public.school_income_records for select
  using (school_id=public.schoolflow_my_school_id() and public.schoolflow_has_finance_permission(school_id,'finance.income.view'));
create policy finance_income_insert on public.school_income_records for insert
  with check (school_id=public.schoolflow_my_school_id() and recorded_by=auth.uid()
    and public.schoolflow_has_finance_permission(school_id,'finance.income.record'));

alter table public.school_expenses enable row level security;
create policy finance_expenses_read on public.school_expenses for select
  using (school_id=public.schoolflow_my_school_id() and (
    public.schoolflow_has_finance_permission(school_id,'finance.expenses.view')
    or requested_by=auth.uid()
  ));
create policy finance_expenses_insert on public.school_expenses for insert
  with check (school_id=public.schoolflow_my_school_id() and requested_by=auth.uid()
    and public.schoolflow_has_finance_permission(school_id,'finance.expenses.record'));
-- Expense state changes will be performed through validated workflow functions only.

alter table public.school_salary_records enable row level security;
create policy finance_salary_records_read on public.school_salary_records for select
  using (school_id=public.schoolflow_my_school_id() and public.schoolflow_has_finance_permission(school_id,'finance.payroll.view'));
create policy finance_salary_records_insert on public.school_salary_records for insert
  with check (school_id=public.schoolflow_my_school_id() and created_by=auth.uid()
    and public.schoolflow_has_finance_permission(school_id,'finance.payroll.manage'));
create policy finance_salary_records_update on public.school_salary_records for update
  using (school_id=public.schoolflow_my_school_id() and public.schoolflow_has_finance_permission(school_id,'finance.payroll.manage'))
  with check (school_id=public.schoolflow_my_school_id());

alter table public.school_salary_payments enable row level security;
create policy finance_salary_payments_read on public.school_salary_payments for select
  using (school_id=public.schoolflow_my_school_id() and public.schoolflow_has_finance_permission(school_id,'finance.payroll.view'));
create policy finance_salary_payments_insert on public.school_salary_payments for insert
  with check (school_id=public.schoolflow_my_school_id() and recorded_by=auth.uid()
    and public.schoolflow_has_finance_permission(school_id,'finance.payroll.payments.record'));

alter table public.school_finance_audit_log enable row level security;
create policy finance_audit_read on public.school_finance_audit_log for select
  using (school_id=public.schoolflow_my_school_id() and public.schoolflow_has_finance_permission(school_id,'finance.audit.view'));

-- No client-side update/delete policies for posted receipts, income, salary payments or audit entries.
-- Posting/reversal functions and audit triggers will be added in the next migration after workflow review.

commit;
