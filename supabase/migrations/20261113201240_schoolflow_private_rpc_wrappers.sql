-- Keep SECURITY DEFINER transaction logic in the private schema.

-- Preserve the existing public RPC names as SECURITY INVOKER wrappers.

begin;

grant usage on schema private to authenticated, service_role;

ALTER FUNCTION public.schoolflow_record_fee_payment(p_fee_record_id uuid, p_amount numeric, p_payment_method text, p_reference text, p_note text, p_paid_at timestamp with time zone) SET SCHEMA private;

REVOKE ALL ON FUNCTION private.schoolflow_record_fee_payment(p_fee_record_id uuid, p_amount numeric, p_payment_method text, p_reference text, p_note text, p_paid_at timestamp with time zone) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.schoolflow_record_fee_payment(p_fee_record_id uuid, p_amount numeric, p_payment_method text, p_reference text, p_note text, p_paid_at timestamp with time zone) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.schoolflow_record_fee_payment(p_fee_record_id uuid, p_amount numeric, p_payment_method text DEFAULT 'other'::text, p_reference text DEFAULT NULL::text, p_note text DEFAULT NULL::text, p_paid_at timestamp with time zone DEFAULT now())
RETURNS uuid
LANGUAGE sql
SECURITY INVOKER
SET search_path = public, private, pg_temp
AS $$
  SELECT private.schoolflow_record_fee_payment($1, $2, $3, $4, $5, $6);
$$;

REVOKE ALL ON FUNCTION public.schoolflow_record_fee_payment(p_fee_record_id uuid, p_amount numeric, p_payment_method text, p_reference text, p_note text, p_paid_at timestamp with time zone) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_record_fee_payment(p_fee_record_id uuid, p_amount numeric, p_payment_method text, p_reference text, p_note text, p_paid_at timestamp with time zone) TO authenticated, service_role;

ALTER FUNCTION public.schoolflow_record_salary_payment(p_salary_record_id uuid, p_amount numeric, p_payment_method text, p_reference text, p_note text, p_paid_at timestamp with time zone) SET SCHEMA private;

REVOKE ALL ON FUNCTION private.schoolflow_record_salary_payment(p_salary_record_id uuid, p_amount numeric, p_payment_method text, p_reference text, p_note text, p_paid_at timestamp with time zone) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.schoolflow_record_salary_payment(p_salary_record_id uuid, p_amount numeric, p_payment_method text, p_reference text, p_note text, p_paid_at timestamp with time zone) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.schoolflow_record_salary_payment(p_salary_record_id uuid, p_amount numeric, p_payment_method text DEFAULT 'other'::text, p_reference text DEFAULT NULL::text, p_note text DEFAULT NULL::text, p_paid_at timestamp with time zone DEFAULT now())
RETURNS uuid
LANGUAGE sql
SECURITY INVOKER
SET search_path = public, private, pg_temp
AS $$
  SELECT private.schoolflow_record_salary_payment($1, $2, $3, $4, $5, $6);
$$;

REVOKE ALL ON FUNCTION public.schoolflow_record_salary_payment(p_salary_record_id uuid, p_amount numeric, p_payment_method text, p_reference text, p_note text, p_paid_at timestamp with time zone) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_record_salary_payment(p_salary_record_id uuid, p_amount numeric, p_payment_method text, p_reference text, p_note text, p_paid_at timestamp with time zone) TO authenticated, service_role;

ALTER FUNCTION public.schoolflow_reverse_fee_payment(p_payment_id uuid, p_reason text) SET SCHEMA private;

REVOKE ALL ON FUNCTION private.schoolflow_reverse_fee_payment(p_payment_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.schoolflow_reverse_fee_payment(p_payment_id uuid, p_reason text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.schoolflow_reverse_fee_payment(p_payment_id uuid, p_reason text)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public, private, pg_temp
AS $$
  SELECT private.schoolflow_reverse_fee_payment($1, $2);
$$;

REVOKE ALL ON FUNCTION public.schoolflow_reverse_fee_payment(p_payment_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_reverse_fee_payment(p_payment_id uuid, p_reason text) TO authenticated, service_role;

ALTER FUNCTION public.schoolflow_reverse_salary_payment(p_payment_id uuid, p_reason text) SET SCHEMA private;

REVOKE ALL ON FUNCTION private.schoolflow_reverse_salary_payment(p_payment_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.schoolflow_reverse_salary_payment(p_payment_id uuid, p_reason text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.schoolflow_reverse_salary_payment(p_payment_id uuid, p_reason text)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public, private, pg_temp
AS $$
  SELECT private.schoolflow_reverse_salary_payment($1, $2);
$$;

REVOKE ALL ON FUNCTION public.schoolflow_reverse_salary_payment(p_payment_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_reverse_salary_payment(p_payment_id uuid, p_reason text) TO authenticated, service_role;

ALTER FUNCTION public.schoolflow_revoke_finance_permission(p_permission_id uuid, p_reason text) SET SCHEMA private;

REVOKE ALL ON FUNCTION private.schoolflow_revoke_finance_permission(p_permission_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.schoolflow_revoke_finance_permission(p_permission_id uuid, p_reason text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.schoolflow_revoke_finance_permission(p_permission_id uuid, p_reason text DEFAULT NULL::text)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public, private, pg_temp
AS $$
  SELECT private.schoolflow_revoke_finance_permission($1, $2);
$$;

REVOKE ALL ON FUNCTION public.schoolflow_revoke_finance_permission(p_permission_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_revoke_finance_permission(p_permission_id uuid, p_reason text) TO authenticated, service_role;

ALTER FUNCTION public.schoolflow_transfer_school_ownership(p_school_id uuid, p_new_owner_user_id uuid, p_reason text) SET SCHEMA private;

REVOKE ALL ON FUNCTION private.schoolflow_transfer_school_ownership(p_school_id uuid, p_new_owner_user_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.schoolflow_transfer_school_ownership(p_school_id uuid, p_new_owner_user_id uuid, p_reason text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.schoolflow_transfer_school_ownership(p_school_id uuid, p_new_owner_user_id uuid, p_reason text)
RETURNS uuid
LANGUAGE sql
SECURITY INVOKER
SET search_path = public, private, pg_temp
AS $$
  SELECT private.schoolflow_transfer_school_ownership($1, $2, $3);
$$;

REVOKE ALL ON FUNCTION public.schoolflow_transfer_school_ownership(p_school_id uuid, p_new_owner_user_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_transfer_school_ownership(p_school_id uuid, p_new_owner_user_id uuid, p_reason text) TO authenticated, service_role;

ALTER FUNCTION public.schoolflow_transition_expense(p_expense_id uuid, p_action text, p_reason text, p_payment_reference text) SET SCHEMA private;

REVOKE ALL ON FUNCTION private.schoolflow_transition_expense(p_expense_id uuid, p_action text, p_reason text, p_payment_reference text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.schoolflow_transition_expense(p_expense_id uuid, p_action text, p_reason text, p_payment_reference text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.schoolflow_transition_expense(p_expense_id uuid, p_action text, p_reason text DEFAULT NULL::text, p_payment_reference text DEFAULT NULL::text)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public, private, pg_temp
AS $$
  SELECT private.schoolflow_transition_expense($1, $2, $3, $4);
$$;

REVOKE ALL ON FUNCTION public.schoolflow_transition_expense(p_expense_id uuid, p_action text, p_reason text, p_payment_reference text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_transition_expense(p_expense_id uuid, p_action text, p_reason text, p_payment_reference text) TO authenticated, service_role;

ALTER FUNCTION public.schoolflow_void_income_record(p_income_id uuid, p_reason text) SET SCHEMA private;

REVOKE ALL ON FUNCTION private.schoolflow_void_income_record(p_income_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.schoolflow_void_income_record(p_income_id uuid, p_reason text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.schoolflow_void_income_record(p_income_id uuid, p_reason text)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = public, private, pg_temp
AS $$
  SELECT private.schoolflow_void_income_record($1, $2);
$$;

REVOKE ALL ON FUNCTION public.schoolflow_void_income_record(p_income_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_void_income_record(p_income_id uuid, p_reason text) TO authenticated, service_role;

commit;
