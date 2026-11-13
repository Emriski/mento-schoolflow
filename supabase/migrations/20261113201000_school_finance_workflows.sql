-- SchoolFlow Finance transaction-safe workflows.
-- Feature branch only. Validate against a staging database before production use.

begin;

create or replace function public.schoolflow_finance_audit(
  p_school_id uuid, p_action text, p_entity_type text, p_entity_id uuid,
  p_details jsonb default '{}'::jsonb, p_reason text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  insert into public.school_finance_audit_log
    (school_id, actor_user_id, action, entity_type, entity_id, details, reason)
  values
    (p_school_id, auth.uid(), p_action, p_entity_type, p_entity_id,
     coalesce(p_details, '{}'::jsonb), p_reason);
end;
$$;

create or replace function public.schoolflow_record_fee_payment(
  p_fee_record_id uuid, p_amount numeric, p_payment_method text default 'other',
  p_reference text default null, p_note text default null, p_paid_at timestamptz default now()
) returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_school_id uuid;
  v_payment_id uuid;
  v_due numeric(14,2);
  v_paid numeric(14,2);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Payment amount must be greater than zero'; end if;

  select school_id, amount_due, amount_paid
    into v_school_id, v_due, v_paid
  from public.school_fee_records
  where id = p_fee_record_id
  for update;

  if not found then raise exception 'Fee record not found'; end if;
  if v_school_id <> public.schoolflow_my_school_id()
     or not private.schoolflow_has_finance_permission(v_school_id, 'finance.fees.record') then
    raise exception 'Not authorized to record this fee payment';
  end if;
  if coalesce(v_paid,0) + p_amount > v_due then
    raise exception 'Payment exceeds the outstanding fee balance';
  end if;
  if p_payment_method not in ('cash','bank_transfer','pos','online','cheque','other') then
    raise exception 'Invalid payment method';
  end if;

  insert into public.school_fee_payments
    (school_id, fee_record_id, amount, paid_at, payment_method, reference, note, received_by)
  values
    (v_school_id, p_fee_record_id, p_amount, coalesce(p_paid_at,now()),
     p_payment_method, p_reference, p_note, auth.uid())
  returning id into v_payment_id;

  update public.school_fee_records
    set amount_paid = coalesce(amount_paid,0) + p_amount, updated_at = now()
  where id = p_fee_record_id;

  perform public.schoolflow_finance_audit(
    v_school_id, 'fee_payment.recorded', 'fee_payment', v_payment_id,
    jsonb_build_object('fee_record_id',p_fee_record_id,'amount',p_amount,'method',p_payment_method)
  );
  return v_payment_id;
end;
$$;

create or replace function public.schoolflow_reverse_fee_payment(
  p_payment_id uuid, p_reason text
) returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_payment public.school_fee_payments%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if length(trim(coalesce(p_reason,''))) < 5 then raise exception 'A clear reversal reason is required'; end if;

  -- Read the payment first without locking, then lock fee record before payment.
  -- This matches the posting path's fee-record-first lock order.
  select * into v_payment from public.school_fee_payments where id=p_payment_id;
  if not found then raise exception 'Payment not found'; end if;
  if v_payment.school_id <> public.schoolflow_my_school_id()
     or not private.schoolflow_has_finance_permission(v_payment.school_id,'finance.fees.record') then
    raise exception 'Not authorized to reverse this payment';
  end if;

  perform 1 from public.school_fee_records
    where id=v_payment.fee_record_id and school_id=v_payment.school_id for update;
  if not found then raise exception 'Fee record not found'; end if;

  select * into v_payment from public.school_fee_payments
    where id=p_payment_id for update;
  if not found or v_payment.status <> 'posted' then
    raise exception 'Only posted payments can be reversed';
  end if;

  update public.school_fee_records
    set amount_paid = greatest(0,coalesce(amount_paid,0)-v_payment.amount), updated_at=now()
  where id=v_payment.fee_record_id and school_id=v_payment.school_id;

  update public.school_fee_payments
    set status='reversed', reversed_at=now(), reversed_by=auth.uid(), reversal_reason=trim(p_reason)
  where id=p_payment_id;

  perform public.schoolflow_finance_audit(
    v_payment.school_id,'fee_payment.reversed','fee_payment',p_payment_id,
    jsonb_build_object('amount',v_payment.amount),trim(p_reason)
  );
end;
$$;

create or replace function public.schoolflow_transition_expense(
  p_expense_id uuid, p_action text, p_reason text default null,
  p_payment_reference text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_expense public.school_expenses%rowtype;
  v_permission text;
  v_next text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_expense from public.school_expenses where id=p_expense_id for update;
  if not found then raise exception 'Expense not found'; end if;
  if v_expense.school_id <> public.schoolflow_my_school_id() then raise exception 'Wrong school'; end if;

  if p_action='submit' then
    if v_expense.requested_by <> auth.uid() or v_expense.status <> 'draft' then
      raise exception 'Only the requester can submit a draft expense';
    end if;
    v_next := 'submitted';
  elsif p_action in ('approve','reject') then
    if not private.schoolflow_has_finance_permission(v_expense.school_id,'finance.expenses.approve') then
      raise exception 'Not authorized to approve expenses';
    end if;
    if v_expense.status <> 'submitted' then raise exception 'Only submitted expenses can be reviewed'; end if;
    if p_action='approve' then v_next := 'approved'; else
      if length(trim(coalesce(p_reason,''))) < 5 then raise exception 'A rejection reason is required'; end if;
      v_next := 'rejected';
    end if;
  elsif p_action='mark_paid' then
    if not private.schoolflow_has_finance_permission(v_expense.school_id,'finance.expenses.approve') then
      raise exception 'Not authorized to mark expenses paid';
    end if;
    if v_expense.status <> 'approved' then raise exception 'Only approved expenses can be marked paid'; end if;
    v_next := 'paid';
  elsif p_action='void' then
    if not private.schoolflow_has_finance_permission(v_expense.school_id,'finance.expenses.approve') then
      raise exception 'Not authorized to void expenses';
    end if;
    if v_expense.status not in ('draft','submitted','approved','rejected') then
      raise exception 'This expense cannot be voided';
    end if;
    if length(trim(coalesce(p_reason,''))) < 5 then raise exception 'A void reason is required'; end if;
    v_next := 'void';
  else
    raise exception 'Unsupported expense action';
  end if;

  update public.school_expenses set
    status=v_next,
    approved_by=case when p_action='approve' then auth.uid() else approved_by end,
    approved_at=case when p_action='approve' then now() else approved_at end,
    rejection_reason=case when p_action='reject' then trim(p_reason) else rejection_reason end,
    paid_by=case when p_action='mark_paid' then auth.uid() else paid_by end,
    paid_at=case when p_action='mark_paid' then now() else paid_at end,
    payment_reference=case when p_action='mark_paid' then p_payment_reference else payment_reference end,
    updated_at=now()
  where id=p_expense_id;

  perform public.schoolflow_finance_audit(
    v_expense.school_id,'expense.'||p_action,'expense',p_expense_id,
    jsonb_build_object('from',v_expense.status,'to',v_next),p_reason
  );
end;
$$;

create or replace function public.schoolflow_revoke_finance_permission(
  p_permission_id uuid, p_reason text default null
) returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_permission public.school_finance_permissions%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_permission from public.school_finance_permissions
  where id=p_permission_id for update;
  if not found then raise exception 'Permission not found'; end if;
  if not private.schoolflow_is_finance_owner(v_permission.school_id) then
    raise exception 'Only the school owner can revoke finance access';
  end if;
  if v_permission.revoked_at is not null then raise exception 'Permission already revoked'; end if;

  update public.school_finance_permissions
    set revoked_at=now(), revoked_by=auth.uid()
  where id=p_permission_id;

  perform public.schoolflow_finance_audit(
    v_permission.school_id,'permission.revoked','finance_permission',p_permission_id,
    jsonb_build_object('user_id',v_permission.user_id,'permission_key',v_permission.permission_key),
    p_reason
  );
end;
$$;

revoke all on function public.schoolflow_finance_audit(uuid,text,text,uuid,jsonb,text) from public, anon, authenticated;
revoke all on function public.schoolflow_record_fee_payment(uuid,numeric,text,text,text,timestamptz) from public, anon;
revoke all on function public.schoolflow_reverse_fee_payment(uuid,text) from public, anon;
revoke all on function public.schoolflow_transition_expense(uuid,text,text,text) from public, anon;
revoke all on function public.schoolflow_revoke_finance_permission(uuid,text) from public, anon;

grant execute on function public.schoolflow_record_fee_payment(uuid,numeric,text,text,text,timestamptz) to authenticated;
grant execute on function public.schoolflow_reverse_fee_payment(uuid,text) to authenticated;
grant execute on function public.schoolflow_transition_expense(uuid,text,text,text) to authenticated;
grant execute on function public.schoolflow_revoke_finance_permission(uuid,text) to authenticated;


create or replace function public.schoolflow_record_salary_payment(
  p_salary_record_id uuid, p_amount numeric, p_payment_method text default 'other',
  p_reference text default null, p_note text default null, p_paid_at timestamptz default now()
) returns uuid
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_salary public.school_salary_records%rowtype;
  v_total numeric(14,2);
  v_payment_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Payment amount must be greater than zero'; end if;
  select * into v_salary from public.school_salary_records
    where id=p_salary_record_id for update;
  if not found then raise exception 'Salary record not found'; end if;
  if v_salary.school_id <> public.schoolflow_my_school_id()
     or not private.schoolflow_has_finance_permission(v_salary.school_id,'finance.payroll.payments.record') then
    raise exception 'Not authorized to record salary payments';
  end if;
  if v_salary.status='void' then raise exception 'Cannot pay a void salary record'; end if;
  if p_payment_method not in ('cash','bank_transfer','pos','online','cheque','other') then
    raise exception 'Invalid payment method';
  end if;
  select coalesce(sum(amount),0) into v_total
  from public.school_salary_payments
  where salary_record_id=p_salary_record_id and status='posted';
  if v_total+p_amount > v_salary.net_amount then
    raise exception 'Payment exceeds the remaining net salary';
  end if;
  insert into public.school_salary_payments
    (school_id,salary_record_id,amount,paid_at,payment_method,reference,note,recorded_by)
  values
    (v_salary.school_id,p_salary_record_id,p_amount,coalesce(p_paid_at,now()),
     p_payment_method,p_reference,p_note,auth.uid())
  returning id into v_payment_id;
  select coalesce(sum(amount),0) into v_total
  from public.school_salary_payments
  where salary_record_id=p_salary_record_id and status='posted';
  update public.school_salary_records
    set status=case when v_total >= net_amount then 'paid' else 'open' end
  where id=p_salary_record_id;
  perform public.schoolflow_finance_audit(
    v_salary.school_id,'salary_payment.recorded','salary_payment',v_payment_id,
    jsonb_build_object('salary_record_id',p_salary_record_id,'amount',p_amount)
  );
  return v_payment_id;
end;
$$;
create or replace function public.schoolflow_reverse_salary_payment(
  p_payment_id uuid, p_reason text
) returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_payment public.school_salary_payments%rowtype;
  v_salary public.school_salary_records%rowtype;
  v_total numeric(14,2);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if length(trim(coalesce(p_reason,''))) < 5 then raise exception 'A clear reversal reason is required'; end if;
  -- Match salary posting's salary-record-first lock order.
  select * into v_payment from public.school_salary_payments where id=p_payment_id;
  if not found then raise exception 'Salary payment not found'; end if;
  if v_payment.school_id <> public.schoolflow_my_school_id()
     or not private.schoolflow_has_finance_permission(v_payment.school_id,'finance.payroll.payments.approve') then
    raise exception 'Not authorized to reverse salary payments';
  end if;
  select * into v_salary from public.school_salary_records
    where id=v_payment.salary_record_id and school_id=v_payment.school_id for update;
  if not found then raise exception 'Salary record not found'; end if;
  select * into v_payment from public.school_salary_payments
    where id=p_payment_id for update;
  if not found or v_payment.status <> 'posted' then
    raise exception 'Only posted payments can be reversed';
  end if;
  update public.school_salary_payments
    set status='reversed',reversed_at=now(),reversed_by=auth.uid(),reversal_reason=trim(p_reason)
  where id=p_payment_id;
  select coalesce(sum(amount),0) into v_total
  from public.school_salary_payments
  where salary_record_id=v_payment.salary_record_id and status='posted';
  update public.school_salary_records
    set status=case when v_total >= net_amount then 'paid' else 'open' end
  where id=v_payment.salary_record_id;
  perform public.schoolflow_finance_audit(
    v_payment.school_id,'salary_payment.reversed','salary_payment',p_payment_id,
    jsonb_build_object('amount',v_payment.amount),trim(p_reason)
  );
end;
$$;
create or replace function public.schoolflow_void_income_record(
  p_income_id uuid, p_reason text
) returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_income public.school_income_records%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if length(trim(coalesce(p_reason,''))) < 5 then raise exception 'A clear void reason is required'; end if;
  select * into v_income from public.school_income_records where id=p_income_id for update;
  if not found then raise exception 'Income record not found'; end if;
  if v_income.school_id <> public.schoolflow_my_school_id()
     or not private.schoolflow_has_finance_permission(v_income.school_id,'finance.income.record') then
    raise exception 'Not authorized to void this income record';
  end if;
  if v_income.status <> 'posted' then raise exception 'Only posted income can be voided'; end if;
  update public.school_income_records
    set status='void',voided_at=now(),voided_by=auth.uid(),void_reason=trim(p_reason)
  where id=p_income_id;
  perform public.schoolflow_finance_audit(
    v_income.school_id,'income.voided','income',p_income_id,
    jsonb_build_object('amount',v_income.amount,'category',v_income.category),trim(p_reason)
  );
end;
$$;
revoke all on function public.schoolflow_record_salary_payment(uuid,numeric,text,text,text,timestamptz) from public, anon;
revoke all on function public.schoolflow_reverse_salary_payment(uuid,text) from public, anon;
revoke all on function public.schoolflow_void_income_record(uuid,text) from public, anon;
grant execute on function public.schoolflow_record_salary_payment(uuid,numeric,text,text,text,timestamptz) to authenticated;
grant execute on function public.schoolflow_reverse_salary_payment(uuid,text) to authenticated;
grant execute on function public.schoolflow_void_income_record(uuid,text) to authenticated;


commit;
