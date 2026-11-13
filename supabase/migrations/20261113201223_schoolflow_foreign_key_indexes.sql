-- Add indexes for uncovered foreign keys found during staging advisor review.

begin;

CREATE INDEX IF NOT EXISTS idx_school_conversations_school_conversations_cre_f9bbf9 ON public.school_conversations (created_by);

CREATE INDEX IF NOT EXISTS idx_school_conversations_school_conversations_stu_3f796d ON public.school_conversations (student_id);

CREATE INDEX IF NOT EXISTS idx_school_expenses_school_expenses_approved_8f96db ON public.school_expenses (approved_by);

CREATE INDEX IF NOT EXISTS idx_school_expenses_school_expenses_paid_by__6bdb13 ON public.school_expenses (paid_by);

CREATE INDEX IF NOT EXISTS idx_school_expenses_school_expenses_requeste_ac5cdc ON public.school_expenses (requested_by);

CREATE INDEX IF NOT EXISTS idx_school_fee_payments_school_fee_payments_rece_cdafb4 ON public.school_fee_payments (received_by);

CREATE INDEX IF NOT EXISTS idx_school_fee_payments_school_fee_payments_reco_aac050 ON public.school_fee_payments (fee_record_id, school_id);

CREATE INDEX IF NOT EXISTS idx_school_fee_payments_school_fee_payments_reve_5a6b93 ON public.school_fee_payments (reversed_by);

CREATE INDEX IF NOT EXISTS idx_school_fee_records_school_fee_records_recor_6e346f ON public.school_fee_records (recorded_by);

CREATE INDEX IF NOT EXISTS idx_school_finance_audit_school_finance_audit_log_547b35 ON public.school_finance_audit_log (actor_user_id);

CREATE INDEX IF NOT EXISTS idx_school_finance_permi_school_finance_permissio_8cf007 ON public.school_finance_permissions (granted_by);

CREATE INDEX IF NOT EXISTS idx_school_finance_permi_school_finance_permissio_4f4bbc ON public.school_finance_permissions (revoked_by);

CREATE INDEX IF NOT EXISTS idx_school_income_record_school_income_records_re_1228fb ON public.school_income_records (recorded_by);

CREATE INDEX IF NOT EXISTS idx_school_income_record_school_income_records_vo_ae93f6 ON public.school_income_records (voided_by);

CREATE INDEX IF NOT EXISTS idx_school_ownership_his_school_ownership_approve_995c13 ON public.school_ownership_history (approved_by, school_id);

CREATE INDEX IF NOT EXISTS idx_school_ownership_his_school_ownership_owner_s_eab660 ON public.school_ownership_history (owner_user_id, school_id);

CREATE INDEX IF NOT EXISTS idx_school_salary_paymen_school_salary_payments_r_cd9669 ON public.school_salary_payments (salary_record_id, school_id);

CREATE INDEX IF NOT EXISTS idx_school_salary_paymen_school_salary_payments_r_7d671d ON public.school_salary_payments (recorded_by);

CREATE INDEX IF NOT EXISTS idx_school_salary_paymen_school_salary_payments_r_0820b2 ON public.school_salary_payments (reversed_by);

CREATE INDEX IF NOT EXISTS idx_school_salary_paymen_school_salary_payments_s_5f7993 ON public.school_salary_payments (school_id);

CREATE INDEX IF NOT EXISTS idx_school_salary_record_school_salary_records_cr_4c995e ON public.school_salary_records (created_by);

CREATE INDEX IF NOT EXISTS idx_school_salary_record_school_salary_staff_scho_c57884 ON public.school_salary_records (staff_user_id, school_id);

CREATE INDEX IF NOT EXISTS idx_student_guardians_student_guardians_school_6f32eb ON public.student_guardians (school_id);

CREATE INDEX IF NOT EXISTS idx_student_results_student_results_class_id_acdd1a ON public.student_results (class_id);

CREATE INDEX IF NOT EXISTS idx_student_results_student_results_entered__8d9ab9 ON public.student_results (entered_by);

CREATE INDEX IF NOT EXISTS idx_student_results_student_results_school_i_a03ada ON public.student_results (school_id);

commit;

