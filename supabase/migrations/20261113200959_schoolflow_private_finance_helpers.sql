-- Keep privileged finance helpers outside the exposed public API schema.

begin;

create schema if not exists private;

revoke all on schema private from public, anon;

grant usage on schema private to authenticated, service_role;

create or replace function private.schoolflow_is_finance_owner(p_school_id uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp
as $$
  select exists (
    select 1 from public.schools s
    where s.id=p_school_id and s.created_by=auth.uid()
  );
$$;

create or replace function private.schoolflow_has_finance_permission(p_school_id uuid,p_permission text)
returns boolean language sql stable security definer set search_path=public,pg_temp
as $$
  select private.schoolflow_is_finance_owner(p_school_id)
    or exists (
      select 1 from public.school_finance_permissions fp
      join public.profiles p on p.id=fp.user_id and p.school_id=fp.school_id
      where fp.school_id=p_school_id and fp.user_id=auth.uid()
        and fp.permission_key=p_permission and fp.revoked_at is null
        and p.role='admin'
    );
$$;

create or replace function private.schoolflow_finance_can_view(p_school_id uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp
as $$
  select private.schoolflow_has_finance_permission(p_school_id,'finance.overview.view')
    or private.schoolflow_has_finance_permission(p_school_id,'finance.fees.view')
    or private.schoolflow_has_finance_permission(p_school_id,'finance.income.view')
    or private.schoolflow_has_finance_permission(p_school_id,'finance.expenses.view')
    or private.schoolflow_has_finance_permission(p_school_id,'finance.payroll.view')
    or private.schoolflow_has_finance_permission(p_school_id,'finance.reports.view')
    or private.schoolflow_has_finance_permission(p_school_id,'finance.audit.view');
$$;

revoke all on function private.schoolflow_is_finance_owner(uuid) from public, anon;

revoke all on function private.schoolflow_has_finance_permission(uuid,text) from public, anon;

revoke all on function private.schoolflow_finance_can_view(uuid) from public, anon;

grant execute on function private.schoolflow_is_finance_owner(uuid) to authenticated, service_role;

grant execute on function private.schoolflow_has_finance_permission(uuid,text) to authenticated, service_role;

grant execute on function private.schoolflow_finance_can_view(uuid) to authenticated, service_role;

-- Replace finance RLS policies so they call the private helpers.

drop policy if exists finance_permissions_owner_read on public.school_finance_permissions;
create policy finance_permissions_owner_read on public.school_finance_permissions
  for select using (private.schoolflow_is_finance_owner(school_id) or user_id=auth.uid());

drop policy if exists finance_permissions_owner_insert on public.school_finance_permissions;
create policy finance_permissions_owner_insert on public.school_finance_permissions
  for insert with check (
    private.schoolflow_is_finance_owner(school_id)
    and granted_by=auth.uid()
    and exists(select 1 from public.profiles p where p.id=school_finance_permissions.user_id and p.school_id=school_finance_permissions.school_id and p.role='admin')
  );

drop policy if exists finance_fee_payments_read on public.school_fee_payments;
create policy finance_fee_payments_read on public.school_fee_payments for select
  using (school_id=public.schoolflow_my_school_id() and private.schoolflow_has_finance_permission(school_id,'finance.fees.view'));

drop policy if exists finance_fee_payments_insert on public.school_fee_payments;
create policy finance_fee_payments_insert on public.school_fee_payments for insert
  with check (school_id=public.schoolflow_my_school_id() and received_by=auth.uid()
    and private.schoolflow_has_finance_permission(school_id,'finance.fees.record')
    and exists(select 1 from public.school_fee_records fr where fr.id=school_fee_payments.fee_record_id and fr.school_id=school_fee_payments.school_id));

drop policy if exists finance_income_read on public.school_income_records;
create policy finance_income_read on public.school_income_records for select
  using (school_id=public.schoolflow_my_school_id() and private.schoolflow_has_finance_permission(school_id,'finance.income.view'));

drop policy if exists finance_income_insert on public.school_income_records;
create policy finance_income_insert on public.school_income_records for insert
  with check (school_id=public.schoolflow_my_school_id() and recorded_by=auth.uid()
    and private.schoolflow_has_finance_permission(school_id,'finance.income.record'));

drop policy if exists finance_expenses_read on public.school_expenses;
create policy finance_expenses_read on public.school_expenses for select
  using (school_id=public.schoolflow_my_school_id() and (
    private.schoolflow_has_finance_permission(school_id,'finance.expenses.view')
    or requested_by=auth.uid()
  ));

drop policy if exists finance_expenses_insert on public.school_expenses;
create policy finance_expenses_insert on public.school_expenses for insert
  with check (school_id=public.schoolflow_my_school_id() and requested_by=auth.uid()
    and private.schoolflow_has_finance_permission(school_id,'finance.expenses.record'));

drop policy if exists finance_salary_records_read on public.school_salary_records;
create policy finance_salary_records_read on public.school_salary_records for select
  using (school_id=public.schoolflow_my_school_id() and private.schoolflow_has_finance_permission(school_id,'finance.payroll.view'));

drop policy if exists finance_salary_records_insert on public.school_salary_records;
create policy finance_salary_records_insert on public.school_salary_records for insert
  with check (school_id=public.schoolflow_my_school_id() and created_by=auth.uid()
    and private.schoolflow_has_finance_permission(school_id,'finance.payroll.manage'));

drop policy if exists finance_salary_records_update on public.school_salary_records;
create policy finance_salary_records_update on public.school_salary_records for update
  using (school_id=public.schoolflow_my_school_id() and private.schoolflow_has_finance_permission(school_id,'finance.payroll.manage'))
  with check (school_id=public.schoolflow_my_school_id());

drop policy if exists finance_salary_payments_read on public.school_salary_payments;
create policy finance_salary_payments_read on public.school_salary_payments for select
  using (school_id=public.schoolflow_my_school_id() and private.schoolflow_has_finance_permission(school_id,'finance.payroll.view'));

drop policy if exists finance_salary_payments_insert on public.school_salary_payments;
create policy finance_salary_payments_insert on public.school_salary_payments for insert
  with check (school_id=public.schoolflow_my_school_id() and recorded_by=auth.uid()
    and private.schoolflow_has_finance_permission(school_id,'finance.payroll.payments.record'));

drop policy if exists finance_audit_read on public.school_finance_audit_log;
create policy finance_audit_read on public.school_finance_audit_log for select
  using (school_id=public.schoolflow_my_school_id() and private.schoolflow_has_finance_permission(school_id,'finance.audit.view'));

-- The private equivalents now back all policies and later workflow functions.

drop function public.schoolflow_finance_can_view(uuid);

drop function public.schoolflow_has_finance_permission(uuid,text);

drop function public.schoolflow_is_finance_owner(uuid);

commit;

