-- Align original SchoolFlow RPC/function grants with the verified production ACLs.

-- This migration is applied only to the isolated staging project.

begin;

REVOKE ALL ON FUNCTION public.schoolflow_accept_invite(p_full_name text) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_accept_invite(p_full_name text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_create_conversation(p_type text, p_student_id uuid, p_recipient_user_id uuid, p_subject text) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_conversation(p_type text, p_student_id uuid, p_recipient_user_id uuid, p_subject text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_create_invite(p_email text, p_role text) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_invite(p_email text, p_role text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_create_school_groups() FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_school_groups() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_generate_student_code() FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_generate_student_code() TO PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_link_parent_account(p_student_id uuid, p_parent_email text) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_link_parent_account(p_student_id uuid, p_parent_email text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_my_role() FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_my_role() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_my_school_id() FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_my_school_id() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_parent_has_session(p_session_id uuid, p_school_id uuid) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_has_session(p_session_id uuid, p_school_id uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid, p_school_id uuid) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid, p_school_id uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_parent_message_recipients(p_role text) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_message_recipients(p_role text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_review_admission(p_student_id uuid, p_decision text) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_review_admission(p_student_id uuid, p_decision text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_setup_school(p_school_name text, p_full_name text) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_setup_school(p_school_name text, p_full_name text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_staff_can_access_attendance(p_session_id uuid, p_student_id uuid) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_staff_can_access_attendance(p_session_id uuid, p_student_id uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_staff_can_access_session(p_class_id uuid, p_school_id uuid) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_staff_can_access_session(p_class_id uuid, p_school_id uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_student_in_school(p_student_id uuid, p_school_id uuid) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_student_in_school(p_student_id uuid, p_school_id uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.schoolflow_submit_admission(p_class_id uuid, p_full_name text, p_admission_date date, p_date_of_birth date, p_guardian_name text, p_guardian_phone text, p_guardian_email text) FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_submit_admission(p_class_id uuid, p_full_name text, p_admission_date date, p_date_of_birth date, p_guardian_name text, p_guardian_phone text, p_guardian_email text) TO authenticated, service_role;

commit;

