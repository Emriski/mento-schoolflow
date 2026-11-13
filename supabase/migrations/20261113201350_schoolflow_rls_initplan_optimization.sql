-- Hoist auth.uid() lookups into initplans in RLS expressions.

begin;

ALTER POLICY "Assigned teacher inserts attendance records" ON public.attendance_records WITH CHECK (((marked_by = ( SELECT (select auth.uid()) AS uid)) AND schoolflow_staff_can_access_attendance(session_id, student_id)));

ALTER POLICY "Assigned teacher or leadership updates attendance records" ON public.attendance_records USING ((schoolflow_staff_can_access_attendance(session_id, student_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (marked_by = ( SELECT (select auth.uid()) AS uid))))) WITH CHECK (((marked_by = ( SELECT (select auth.uid()) AS uid)) AND schoolflow_staff_can_access_attendance(session_id, student_id)));

ALTER POLICY "Assigned teacher inserts attendance session" ON public.attendance_sessions WITH CHECK (((school_id = schoolflow_my_school_id()) AND (marked_by = ( SELECT (select auth.uid()) AS uid)) AND schoolflow_staff_can_access_session(class_id, school_id)));

ALTER POLICY "Assigned teacher or leadership updates attendance session" ON public.attendance_sessions USING (((school_id = schoolflow_my_school_id()) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR ((marked_by = ( SELECT (select auth.uid()) AS uid)) AND schoolflow_staff_can_access_session(class_id, school_id))))) WITH CHECK (((school_id = schoolflow_my_school_id()) AND schoolflow_staff_can_access_session(class_id, school_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (marked_by = ( SELECT (select auth.uid()) AS uid)))));

ALTER POLICY "Attendance sessions read permitted" ON public.attendance_sessions USING (((school_id = schoolflow_my_school_id()) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (EXISTS ( SELECT 1
   FROM classes c
  WHERE ((c.id = attendance_sessions.class_id) AND (c.teacher_id = (select auth.uid()))))))));

ALTER POLICY "Classes read assigned or leadership" ON public.classes USING (((school_id = schoolflow_my_school_id()) AND ((teacher_id = (select auth.uid())) OR (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])))));

ALTER POLICY "Profiles read self and leadership peers" ON public.profiles USING (((id = (select auth.uid())) OR ((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])))));

ALTER POLICY "Users can read their own role profile" ON public.profiles USING ((id = ( SELECT (select auth.uid()) AS uid)));

ALTER POLICY "participants update own read marker" ON public.school_conversation_participants USING ((user_id = ( SELECT (select auth.uid()) AS uid))) WITH CHECK ((user_id = ( SELECT (select auth.uid()) AS uid)));

ALTER POLICY "users read own participant row" ON public.school_conversation_participants USING ((user_id = ( SELECT (select auth.uid()) AS uid)));

ALTER POLICY "participants and school admins read conversations" ON public.school_conversations USING (((EXISTS ( SELECT 1
   FROM school_conversation_participants p
  WHERE ((p.conversation_id = school_conversations.id) AND (p.user_id = ( SELECT (select auth.uid()) AS uid))))) OR ((conversation_type = 'parent_teacher'::text) AND (EXISTS ( SELECT 1
   FROM profiles pr
  WHERE ((pr.id = ( SELECT (select auth.uid()) AS uid)) AND (pr.school_id = school_conversations.school_id) AND (pr.role = 'admin'::text)))))));

ALTER POLICY "finance_expenses_insert" ON public.school_expenses WITH CHECK (((school_id = schoolflow_my_school_id()) AND (requested_by = (select auth.uid())) AND private.schoolflow_has_finance_permission(school_id, 'finance.expenses.record'::text)));

ALTER POLICY "finance_expenses_read" ON public.school_expenses USING (((school_id = schoolflow_my_school_id()) AND (private.schoolflow_has_finance_permission(school_id, 'finance.expenses.view'::text) OR (requested_by = (select auth.uid())))));

ALTER POLICY "finance_fee_payments_insert" ON public.school_fee_payments WITH CHECK (((school_id = schoolflow_my_school_id()) AND (received_by = (select auth.uid())) AND private.schoolflow_has_finance_permission(school_id, 'finance.fees.record'::text) AND (EXISTS ( SELECT 1
   FROM school_fee_records fr
  WHERE ((fr.id = school_fee_payments.fee_record_id) AND (fr.school_id = school_fee_payments.school_id))))));

ALTER POLICY "Parents read fees for linked students" ON public.school_fee_records USING (((EXISTS ( SELECT 1
   FROM student_guardians g
  WHERE ((g.student_id = school_fee_records.student_id) AND (g.school_id = school_fee_records.school_id) AND (g.guardian_user_id = ( SELECT (select auth.uid()) AS uid))))) AND (NOT (EXISTS ( SELECT 1
   FROM profiles p
  WHERE (p.id = ( SELECT (select auth.uid()) AS uid)))))));

ALTER POLICY "finance_permissions_owner_insert" ON public.school_finance_permissions WITH CHECK ((private.schoolflow_is_finance_owner(school_id) AND (granted_by = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = school_finance_permissions.user_id) AND (p.school_id = school_finance_permissions.school_id) AND (p.role = 'admin'::text))))));

ALTER POLICY "finance_permissions_owner_read" ON public.school_finance_permissions USING ((private.schoolflow_is_finance_owner(school_id) OR (user_id = (select auth.uid()))));

ALTER POLICY "finance_income_insert" ON public.school_income_records WITH CHECK (((school_id = schoolflow_my_school_id()) AND (recorded_by = (select auth.uid())) AND private.schoolflow_has_finance_permission(school_id, 'finance.income.record'::text)));

ALTER POLICY "conversation participants send messages" ON public.school_messages WITH CHECK (((sender_id = ( SELECT (select auth.uid()) AS uid)) AND (EXISTS ( SELECT 1
   FROM school_conversation_participants p
  WHERE ((p.conversation_id = school_messages.conversation_id) AND (p.user_id = ( SELECT (select auth.uid()) AS uid)))))));

ALTER POLICY "participants and school admins read messages" ON public.school_messages USING ((EXISTS ( SELECT 1
   FROM school_conversations c
  WHERE ((c.id = school_messages.conversation_id) AND ((EXISTS ( SELECT 1
           FROM school_conversation_participants p
          WHERE ((p.conversation_id = c.id) AND (p.user_id = ( SELECT (select auth.uid()) AS uid))))) OR ((c.conversation_type = 'parent_teacher'::text) AND (EXISTS ( SELECT 1
           FROM profiles pr
          WHERE ((pr.id = ( SELECT (select auth.uid()) AS uid)) AND (pr.school_id = c.school_id) AND (pr.role = 'admin'::text))))))))));

ALTER POLICY "finance_salary_payments_insert" ON public.school_salary_payments WITH CHECK (((school_id = schoolflow_my_school_id()) AND (recorded_by = (select auth.uid())) AND private.schoolflow_has_finance_permission(school_id, 'finance.payroll.payments.record'::text)));

ALTER POLICY "finance_salary_records_insert" ON public.school_salary_records WITH CHECK (((school_id = schoolflow_my_school_id()) AND (created_by = (select auth.uid())) AND private.schoolflow_has_finance_permission(school_id, 'finance.payroll.manage'::text)));

ALTER POLICY "Parents read their own guardian links" ON public.student_guardians USING (((guardian_user_id = ( SELECT (select auth.uid()) AS uid)) AND (NOT (EXISTS ( SELECT 1
   FROM profiles p
  WHERE (p.id = ( SELECT (select auth.uid()) AS uid)))))));

ALTER POLICY "Assigned teachers and leadership insert results" ON public.student_results WITH CHECK (((school_id = schoolflow_my_school_id()) AND (entered_by = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM (students s
     JOIN classes c ON ((c.id = s.class_id)))
  WHERE ((s.id = student_results.student_id) AND (s.school_id = student_results.school_id) AND (s.class_id = student_results.class_id) AND (c.school_id = student_results.school_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (c.teacher_id = (select auth.uid()))))))));

ALTER POLICY "Assigned teachers and leadership update results" ON public.student_results USING (((school_id = schoolflow_my_school_id()) AND (EXISTS ( SELECT 1
   FROM classes c
  WHERE ((c.id = student_results.class_id) AND (c.school_id = student_results.school_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (c.teacher_id = (select auth.uid())))))))) WITH CHECK (((school_id = schoolflow_my_school_id()) AND (entered_by = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM (students s
     JOIN classes c ON ((c.id = s.class_id)))
  WHERE ((s.id = student_results.student_id) AND (s.school_id = student_results.school_id) AND (s.class_id = student_results.class_id) AND (c.school_id = student_results.school_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (c.teacher_id = (select auth.uid()))))))));

ALTER POLICY "Parents read results for linked students" ON public.student_results USING (((EXISTS ( SELECT 1
   FROM student_guardians g
  WHERE ((g.student_id = student_results.student_id) AND (g.school_id = student_results.school_id) AND (g.guardian_user_id = ( SELECT (select auth.uid()) AS uid))))) AND (NOT (EXISTS ( SELECT 1
   FROM profiles p
  WHERE (p.id = ( SELECT (select auth.uid()) AS uid)))))));

ALTER POLICY "School staff read permitted student results" ON public.student_results USING (((school_id = schoolflow_my_school_id()) AND (EXISTS ( SELECT 1
   FROM classes c
  WHERE ((c.id = student_results.class_id) AND (c.school_id = student_results.school_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (c.teacher_id = (select auth.uid()))))))));

ALTER POLICY "Students read permitted class" ON public.students USING (((school_id = schoolflow_my_school_id()) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (EXISTS ( SELECT 1
   FROM classes c
  WHERE ((c.id = students.class_id) AND (c.teacher_id = (select auth.uid()))))))));

commit;

