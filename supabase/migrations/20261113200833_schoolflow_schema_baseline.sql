-- Schema-only baseline reconstructed from SchoolFlow production catalog metadata.

-- No production records are included. Apply only to the isolated staging project.

begin;

-- Core application tables and constraints

CREATE TABLE public.schools (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name text NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT schools_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT schools_pkey PRIMARY KEY (id)
);

CREATE TABLE public.profiles (
  id uuid NOT NULL,
  school_id uuid NOT NULL,
  full_name text NOT NULL,
  role text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_role_check CHECK ((role = ANY (ARRAY['admin'::text, 'head_teacher'::text, 'teacher'::text]))),
  CONSTRAINT profiles_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
);

CREATE TABLE public.classes (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  school_id uuid NOT NULL,
  name text NOT NULL,
  teacher_id uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT classes_pkey PRIMARY KEY (id),
  CONSTRAINT classes_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
  CONSTRAINT classes_school_id_name_key UNIQUE (school_id, name),
  CONSTRAINT classes_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE SET NULL
);

CREATE TABLE public.students (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  school_id uuid NOT NULL,
  class_id uuid NOT NULL,
  full_name text NOT NULL,
  student_code text,
  active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  admission_date date DEFAULT CURRENT_DATE NOT NULL,
  admission_status text DEFAULT 'admitted'::text NOT NULL,
  CONSTRAINT students_admission_status_check CHECK ((admission_status = ANY (ARRAY['pending'::text, 'admitted'::text, 'rejected'::text]))),
  CONSTRAINT students_class_id_fkey FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
  CONSTRAINT students_class_id_student_code_key UNIQUE (class_id, student_code),
  CONSTRAINT students_pkey PRIMARY KEY (id),
  CONSTRAINT students_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
);

CREATE TABLE public.attendance_sessions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  school_id uuid NOT NULL,
  class_id uuid NOT NULL,
  attendance_date date DEFAULT CURRENT_DATE NOT NULL,
  marked_by uuid NOT NULL,
  status text DEFAULT 'submitted'::text NOT NULL,
  submitted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT attendance_sessions_class_id_attendance_date_key UNIQUE (class_id, attendance_date),
  CONSTRAINT attendance_sessions_class_id_fkey FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
  CONSTRAINT attendance_sessions_marked_by_fkey FOREIGN KEY (marked_by) REFERENCES profiles(id),
  CONSTRAINT attendance_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_sessions_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
  CONSTRAINT attendance_sessions_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text])))
);

CREATE TABLE public.attendance_records (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  session_id uuid NOT NULL,
  student_id uuid NOT NULL,
  status text NOT NULL,
  marked_by uuid NOT NULL,
  marked_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT attendance_records_marked_by_fkey FOREIGN KEY (marked_by) REFERENCES profiles(id),
  CONSTRAINT attendance_records_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_records_session_id_fkey FOREIGN KEY (session_id) REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  CONSTRAINT attendance_records_session_id_student_id_key UNIQUE (session_id, student_id),
  CONSTRAINT attendance_records_status_check CHECK ((status = ANY (ARRAY['present'::text, 'late'::text, 'absent'::text]))),
  CONSTRAINT attendance_records_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
);

CREATE TABLE public.school_invites (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  school_id uuid NOT NULL,
  email text NOT NULL,
  role text NOT NULL,
  created_by uuid NOT NULL,
  accepted_by uuid,
  accepted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT school_invites_accepted_by_fkey FOREIGN KEY (accepted_by) REFERENCES profiles(id),
  CONSTRAINT school_invites_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id),
  CONSTRAINT school_invites_pkey PRIMARY KEY (id),
  CONSTRAINT school_invites_role_check CHECK ((role = ANY (ARRAY['head_teacher'::text, 'teacher'::text, 'admin'::text, 'parent'::text]))),
  CONSTRAINT school_invites_school_id_email_key UNIQUE (school_id, email),
  CONSTRAINT school_invites_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE
);

CREATE TABLE public.student_guardians (
  student_id uuid NOT NULL,
  school_id uuid NOT NULL,
  date_of_birth date,
  guardian_name text NOT NULL,
  guardian_phone text NOT NULL,
  guardian_email text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  guardian_user_id uuid,
  CONSTRAINT student_guardians_guardian_user_id_fkey FOREIGN KEY (guardian_user_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT student_guardians_pkey PRIMARY KEY (student_id),
  CONSTRAINT student_guardians_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
  CONSTRAINT student_guardians_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
);

CREATE TABLE public.school_fee_records (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid NOT NULL,
  academic_year text NOT NULL,
  term text NOT NULL,
  amount_due numeric(12,2) NOT NULL,
  amount_paid numeric(12,2) DEFAULT 0 NOT NULL,
  note text,
  recorded_by uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  payment_status text GENERATED ALWAYS AS (
CASE
    WHEN (amount_paid = (0)::numeric) THEN 'unpaid'::text
    WHEN (amount_paid < amount_due) THEN 'part_payment'::text
    ELSE 'paid'::text
END) STORED,
  CONSTRAINT school_fee_records_amount_due_check CHECK ((amount_due > (0)::numeric)),
  CONSTRAINT school_fee_records_check CHECK (((amount_paid >= (0)::numeric) AND (amount_paid <= amount_due))),
  CONSTRAINT school_fee_records_pkey PRIMARY KEY (id),
  CONSTRAINT school_fee_records_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES profiles(id),
  CONSTRAINT school_fee_records_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
  CONSTRAINT school_fee_records_student_id_academic_year_term_key UNIQUE (student_id, academic_year, term),
  CONSTRAINT school_fee_records_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
  CONSTRAINT school_fee_records_term_check CHECK ((term = ANY (ARRAY['First Term'::text, 'Second Term'::text, 'Third Term'::text])))
);

CREATE TABLE public.student_results (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  school_id uuid NOT NULL,
  class_id uuid NOT NULL,
  student_id uuid NOT NULL,
  academic_year text NOT NULL,
  term text NOT NULL,
  subject text NOT NULL,
  ca_score numeric(6,2) DEFAULT 0 NOT NULL,
  ca_max numeric(6,2) DEFAULT 20 NOT NULL,
  exam_score numeric(6,2) DEFAULT 0 NOT NULL,
  exam_max numeric(6,2) DEFAULT 80 NOT NULL,
  total_score numeric(7,2) GENERATED ALWAYS AS ((ca_score + exam_score)) STORED,
  total_max numeric(7,2) GENERATED ALWAYS AS ((ca_max + exam_max)) STORED,
  percentage numeric(6,2) GENERATED ALWAYS AS (round((((ca_score + exam_score) / NULLIF((ca_max + exam_max), (0)::numeric)) * (100)::numeric), 2)) STORED,
  grade text GENERATED ALWAYS AS (
CASE
    WHEN ((((ca_score + exam_score) / NULLIF((ca_max + exam_max), (0)::numeric)) * (100)::numeric) >= (70)::numeric) THEN 'A'::text
    WHEN ((((ca_score + exam_score) / NULLIF((ca_max + exam_max), (0)::numeric)) * (100)::numeric) >= (60)::numeric) THEN 'B'::text
    WHEN ((((ca_score + exam_score) / NULLIF((ca_max + exam_max), (0)::numeric)) * (100)::numeric) >= (50)::numeric) THEN 'C'::text
    WHEN ((((ca_score + exam_score) / NULLIF((ca_max + exam_max), (0)::numeric)) * (100)::numeric) >= (45)::numeric) THEN 'D'::text
    WHEN ((((ca_score + exam_score) / NULLIF((ca_max + exam_max), (0)::numeric)) * (100)::numeric) >= (40)::numeric) THEN 'E'::text
    ELSE 'F'::text
END) STORED,
  remarks text,
  entered_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT student_results_academic_year_check CHECK (((char_length(TRIM(BOTH FROM academic_year)) >= 4) AND (char_length(TRIM(BOTH FROM academic_year)) <= 20))),
  CONSTRAINT student_results_ca_score_check CHECK ((ca_score >= (0)::numeric)),
  CONSTRAINT student_results_check CHECK (((ca_max > (0)::numeric) AND (ca_score <= ca_max))),
  CONSTRAINT student_results_check1 CHECK (((exam_max > (0)::numeric) AND (exam_score <= exam_max))),
  CONSTRAINT student_results_class_id_fkey FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
  CONSTRAINT student_results_entered_by_fkey FOREIGN KEY (entered_by) REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT student_results_exam_score_check CHECK ((exam_score >= (0)::numeric)),
  CONSTRAINT student_results_pkey PRIMARY KEY (id),
  CONSTRAINT student_results_remarks_check CHECK (((remarks IS NULL) OR (char_length(remarks) <= 240))),
  CONSTRAINT student_results_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
  CONSTRAINT student_results_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
  CONSTRAINT student_results_subject_check CHECK (((char_length(TRIM(BOTH FROM subject)) >= 1) AND (char_length(TRIM(BOTH FROM subject)) <= 100))),
  CONSTRAINT student_results_term_check CHECK ((term = ANY (ARRAY['First Term'::text, 'Second Term'::text, 'Third Term'::text]))),
  CONSTRAINT student_results_unique_subject_term UNIQUE (student_id, academic_year, term, subject)
);

CREATE TABLE public.school_conversations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  school_id uuid NOT NULL,
  student_id uuid,
  conversation_type text NOT NULL,
  subject text NOT NULL,
  created_by uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT school_conversations_conversation_type_check CHECK ((conversation_type = ANY (ARRAY['parent_teacher'::text, 'parent_admin'::text, 'staff_private'::text, 'school_community'::text, 'staff_group'::text]))),
  CONSTRAINT school_conversations_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id),
  CONSTRAINT school_conversations_pkey PRIMARY KEY (id),
  CONSTRAINT school_conversations_school_id_fkey FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
  CONSTRAINT school_conversations_student_id_fkey FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE SET NULL,
  CONSTRAINT school_conversations_subject_check CHECK (((char_length(TRIM(BOTH FROM subject)) >= 1) AND (char_length(TRIM(BOTH FROM subject)) <= 120)))
);

CREATE TABLE public.school_conversation_participants (
  conversation_id uuid NOT NULL,
  user_id uuid NOT NULL,
  participant_role text NOT NULL,
  joined_at timestamp with time zone DEFAULT now() NOT NULL,
  last_read_at timestamp with time zone,
  CONSTRAINT school_conversation_participants_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES school_conversations(id) ON DELETE CASCADE,
  CONSTRAINT school_conversation_participants_participant_role_check CHECK ((participant_role = ANY (ARRAY['parent'::text, 'teacher'::text, 'admin'::text, 'head_teacher'::text]))),
  CONSTRAINT school_conversation_participants_pkey PRIMARY KEY (conversation_id, user_id),
  CONSTRAINT school_conversation_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE public.school_messages (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  client_message_id uuid NOT NULL,
  body text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT school_messages_body_check CHECK (((char_length(TRIM(BOTH FROM body)) >= 1) AND (char_length(TRIM(BOTH FROM body)) <= 5000))),
  CONSTRAINT school_messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES school_conversations(id) ON DELETE CASCADE,
  CONSTRAINT school_messages_pkey PRIMARY KEY (id),
  CONSTRAINT school_messages_sender_id_client_message_id_key UNIQUE (sender_id, client_message_id),
  CONSTRAINT school_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id)
);

-- Supporting indexes

CREATE INDEX attendance_records_marked_by_idx ON public.attendance_records USING btree (marked_by);



CREATE INDEX attendance_records_session_idx ON public.attendance_records USING btree (session_id);

CREATE INDEX attendance_records_student_id_idx ON public.attendance_records USING btree (student_id);


CREATE INDEX attendance_sessions_marked_by_idx ON public.attendance_sessions USING btree (marked_by);


CREATE INDEX attendance_sessions_school_date_idx ON public.attendance_sessions USING btree (school_id, attendance_date DESC);

CREATE UNIQUE INDEX classes_one_assigned_class_per_teacher ON public.classes USING btree (school_id, teacher_id) WHERE (teacher_id IS NOT NULL);



CREATE INDEX classes_school_idx ON public.classes USING btree (school_id);

CREATE INDEX classes_teacher_id_idx ON public.classes USING btree (teacher_id);


CREATE INDEX profiles_school_role_idx ON public.profiles USING btree (school_id, role);


CREATE INDEX school_participants_user_idx ON public.school_conversation_participants USING btree (user_id, conversation_id);


CREATE INDEX school_conversations_school_updated_idx ON public.school_conversations USING btree (school_id, updated_at DESC);


CREATE INDEX school_fee_records_school_term_idx ON public.school_fee_records USING btree (school_id, academic_year, term, payment_status);


CREATE INDEX school_invites_accepted_by_idx ON public.school_invites USING btree (accepted_by);

CREATE INDEX school_invites_created_by_idx ON public.school_invites USING btree (created_by);



CREATE INDEX school_messages_conversation_created_idx ON public.school_messages USING btree (conversation_id, created_at DESC);



CREATE INDEX schools_created_by_idx ON public.schools USING btree (created_by);


CREATE INDEX student_guardians_guardian_user_id_idx ON public.student_guardians USING btree (guardian_user_id);





CREATE INDEX students_class_idx ON public.students USING btree (class_id);


CREATE INDEX students_school_admission_status_date_idx ON public.students USING btree (school_id, admission_status, admission_date DESC);

CREATE INDEX students_school_id_idx ON public.students USING btree (school_id);

CREATE UNIQUE INDEX students_school_student_code_unique ON public.students USING btree (school_id, student_code) WHERE ((student_code IS NOT NULL) AND (btrim(student_code) <> ''::text));

-- Database helper and workflow functions

CREATE OR REPLACE FUNCTION public.schoolflow_my_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select role from public.profiles where id = auth.uid() limit 1 $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_my_school_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select school_id from public.profiles where id = auth.uid() limit 1 $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_generate_student_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ begin if new.student_code is null or btrim(new.student_code) = '' then new.student_code := 'SF-' || to_char(coalesce(new.admission_date, current_date), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)); end if; return new; end; $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_accept_invite(p_full_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt()->>'email',''));
  v_inv public.school_invites%rowtype;
begin
  if v_uid is null then raise exception 'Sign in first'; end if;
  if not exists (
    select 1 from auth.users u
    where u.id = v_uid and u.email_confirmed_at is not null
  ) then
    raise exception 'Verify your email address before accepting a school invitation';
  end if;
  if exists(select 1 from public.profiles where id=v_uid) then
    raise exception 'This account already has a school profile';
  end if;
  if coalesce(trim(p_full_name),'') = '' then
    raise exception 'Full name is required';
  end if;
  select * into v_inv
  from public.school_invites
  where email=v_email and accepted_at is null
  order by created_at desc
  limit 1
  for update;
  if not found then
    raise exception 'No pending school invitation matches this signed-in email';
  end if;
  insert into public.profiles(id,school_id,full_name,role)
  values(v_uid,v_inv.school_id,trim(p_full_name),v_inv.role);
  update public.school_invites
  set accepted_by=v_uid, accepted_at=now()
  where id=v_inv.id;
  return jsonb_build_object('school_id',v_inv.school_id,'role',v_inv.role);
end
$function$;


CREATE OR REPLACE FUNCTION public.schoolflow_create_conversation(p_type text, p_student_id uuid, p_recipient_user_id uuid, p_subject text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_uid uuid:=auth.uid(); v_school_id uuid; v_caller_role text; v_recipient_role text; v_conversation_id uuid;
begin
 if v_uid is null then raise exception 'You must be signed in.'; end if;
 if p_type not in ('parent_teacher','parent_admin','staff_private') then raise exception 'Invalid conversation type.'; end if;
 if p_recipient_user_id is null or p_recipient_user_id=v_uid then raise exception 'Choose another participant.'; end if;
 if p_subject is null or char_length(trim(p_subject)) not between 1 and 120 then raise exception 'Subject must be 1 to 120 characters.'; end if;
 select s.school_id into v_school_id from public.students s where s.id=p_student_id and s.active=true;
 if v_school_id is null then raise exception 'Student not found.'; end if;
 select pr.role into v_caller_role from public.profiles pr where pr.id=v_uid and pr.school_id=v_school_id;
 select pr.role into v_recipient_role from public.profiles pr where pr.id=p_recipient_user_id and pr.school_id=v_school_id;
 if p_type='parent_teacher' then
  if v_caller_role is null then
   if not exists(select 1 from public.student_guardians g where g.student_id=p_student_id and g.school_id=v_school_id and g.guardian_user_id=v_uid) then raise exception 'You are not linked as this student’s parent.'; end if;
   if v_recipient_role is distinct from 'teacher' then raise exception 'Select a teacher from this school.'; end if;
  elsif v_caller_role='teacher' then
   if not exists(select 1 from public.classes cl join public.students st on st.class_id=cl.id where st.id=p_student_id and cl.teacher_id=v_uid) then raise exception 'You are not assigned to this student’s class.'; end if;
   if not exists(select 1 from public.student_guardians g where g.student_id=p_student_id and g.guardian_user_id=p_recipient_user_id) then raise exception 'The selected parent is not linked to this student.'; end if;
  else raise exception 'Only the parent or assigned teacher can start this conversation.';
  end if;
 elsif p_type='parent_admin' then
  if v_caller_role is null then
   if not exists(select 1 from public.student_guardians g where g.student_id=p_student_id and g.school_id=v_school_id and g.guardian_user_id=v_uid) then raise exception 'You are not linked as this student’s parent.'; end if;
   if v_recipient_role is distinct from 'admin' then raise exception 'Select an administrator from this school.'; end if;
  elsif v_caller_role='admin' then
   if not exists(select 1 from public.student_guardians g where g.student_id=p_student_id and g.guardian_user_id=p_recipient_user_id) then raise exception 'The selected parent is not linked to this student.'; end if;
  else raise exception 'Only a parent or administrator can start this conversation.';
  end if;
 else
  if v_caller_role not in ('teacher','admin','head_teacher') or v_recipient_role not in ('teacher','admin','head_teacher') then raise exception 'Staff accounts only.'; end if;
 end if;
 insert into public.school_conversations(school_id,student_id,conversation_type,subject,created_by) values(v_school_id,p_student_id,p_type,trim(p_subject),v_uid) returning id into v_conversation_id;
 insert into public.school_conversation_participants(conversation_id,user_id,participant_role)
 values(v_conversation_id,v_uid,coalesce(v_caller_role,'parent')),(v_conversation_id,p_recipient_user_id,coalesce(v_recipient_role,'parent'));
 return v_conversation_id;
end; $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_create_invite(p_email text, p_role text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$ declare v_school uuid := public.schoolflow_my_school_id(); v_role text := public.schoolflow_my_role(); v_id uuid; begin if auth.uid() is null then raise exception 'Sign in first'; end if; if v_role not in ('admin','head_teacher') then raise exception 'Only school leadership can invite staff'; end if; if p_role not in ('teacher','head_teacher','admin') then raise exception 'Invalid staff role'; end if; if p_role = 'admin' and v_role <> 'admin' then raise exception 'Only an existing administrator can appoint another administrator'; end if; if coalesce(trim(p_email),'') = '' then raise exception 'Email is required'; end if; insert into public.school_invites(school_id,email,role,created_by) values(v_school,lower(trim(p_email)),p_role,auth.uid()) on conflict (school_id,email) do update set role=excluded.role, created_by=excluded.created_by, accepted_by=null, accepted_at=null returning id into v_id; return jsonb_build_object('invite_id',v_id,'email',lower(trim(p_email)),'role',p_role); end; $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_create_school_groups()
 RETURNS TABLE(community_conversation_id uuid, staff_conversation_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_school_id uuid; v_role text; v_community uuid; v_staff uuid;
begin
 if v_uid is null then raise exception 'You must be signed in.'; end if;
 select p.school_id,p.role into v_school_id,v_role from public.profiles p where p.id=v_uid;
 if v_school_id is null or v_role not in ('admin','head_teacher') then raise exception 'Only a school administrator can create or refresh school groups.'; end if;
 select c.id into v_community from public.school_conversations c where c.school_id=v_school_id and c.conversation_type='school_community' and c.subject='School Community' order by c.created_at limit 1;
 if v_community is null then
  insert into public.school_conversations(school_id,student_id,conversation_type,subject,created_by) values(v_school_id,null,'school_community','School Community',v_uid) returning id into v_community;
 end if;
 select c.id into v_staff from public.school_conversations c where c.school_id=v_school_id and c.conversation_type='staff_group' and c.subject='Teachers & Administrators' order by c.created_at limit 1;
 if v_staff is null then
  insert into public.school_conversations(school_id,student_id,conversation_type,subject,created_by) values(v_school_id,null,'staff_group','Teachers & Administrators',v_uid) returning id into v_staff;
 end if;
 delete from public.school_conversation_participants cp where cp.conversation_id=v_community and cp.participant_role='parent'
 and not exists(select 1 from public.student_guardians g where g.school_id=v_school_id and g.guardian_user_id=cp.user_id);
 insert into public.school_conversation_participants(conversation_id,user_id,participant_role)
 select v_community,p.id,p.role from public.profiles p where p.school_id=v_school_id and p.role in ('admin','head_teacher','teacher')
 on conflict(conversation_id,user_id) do nothing;
 insert into public.school_conversation_participants(conversation_id,user_id,participant_role)
 select v_community,g.guardian_user_id,'parent' from public.student_guardians g where g.school_id=v_school_id and g.guardian_user_id is not null
 on conflict(conversation_id,user_id) do nothing;
 insert into public.school_conversation_participants(conversation_id,user_id,participant_role)
 select v_staff,p.id,p.role from public.profiles p where p.school_id=v_school_id and p.role in ('admin','head_teacher','teacher')
 on conflict(conversation_id,user_id) do nothing;
 return query select v_community,v_staff;
end; $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_link_parent_account(p_student_id uuid, p_parent_email text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare v_school_id uuid; v_parent_user_id uuid; v_updated integer; begin if auth.uid() is null then raise exception 'You must be signed in.'; end if; select p.school_id into v_school_id from public.profiles p where p.id = auth.uid() and p.role in ('admin','head_teacher'); if v_school_id is null then raise exception 'Only a school administrator or head teacher can link parent accounts.'; end if; if p_parent_email is null or length(trim(p_parent_email)) = 0 then raise exception 'Enter the parent email address.'; end if; select u.id into v_parent_user_id from auth.users u where lower(u.email) = lower(trim(p_parent_email)) and u.email_confirmed_at is not null limit 1; if v_parent_user_id is null then raise exception 'No account with a confirmed email address was found. Ask the parent to create and confirm their account first.'; end if; if not exists (select 1 from public.students s where s.id = p_student_id and s.school_id = v_school_id) then raise exception 'Student not found in your school.'; end if; update public.student_guardians g set guardian_user_id = v_parent_user_id where g.student_id = p_student_id and g.school_id = v_school_id and lower(g.guardian_email) = lower(trim(p_parent_email)); get diagnostics v_updated = row_count; if v_updated = 0 then raise exception 'The parent email does not match a guardian contact recorded for this student.'; end if; return v_updated; end; $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_parent_has_session(p_session_id uuid, p_school_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select not exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
  ) and exists (
    select 1
    from public.attendance_records ar
    join public.student_guardians g on g.student_id = ar.student_id
    where ar.session_id = p_session_id
      and g.school_id = p_school_id
      and g.guardian_user_id = (select auth.uid())
  );
$function$;


CREATE OR REPLACE FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select not exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
  ) and exists (
    select 1 from public.student_guardians g
    where g.student_id = p_student_id
      and g.guardian_user_id = (select auth.uid())
  );
$function$;


CREATE OR REPLACE FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid, p_school_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ select exists(select 1 from public.student_guardians g where g.student_id=p_student_id and g.school_id=p_school_id and g.guardian_user_id=(select auth.uid())); $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_parent_message_recipients(p_role text)
 RETURNS TABLE(id uuid, full_name text, role text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_school_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign-in required';
  end if;
  if p_role not in ('teacher','admin') then
    raise exception 'Invalid recipient role';
  end if;
  select g.school_id into v_school_id
  from public.student_guardians g
  where g.guardian_user_id = auth.uid()
  limit 1;
  if v_school_id is null then
    raise exception 'No linked student account found';
  end if;
  return query
  select p.id, p.full_name, p.role
  from public.profiles p
  where p.school_id = v_school_id and p.role = p_role
  order by p.full_name;
end;
$function$;


CREATE OR REPLACE FUNCTION public.schoolflow_review_admission(p_student_id uuid, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_school_id uuid; v_role text; v_updated integer;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 if p_decision not in ('approve','reject') then raise exception 'Decision must be approve or reject'; end if;
 select p.school_id,p.role into v_school_id,v_role from public.profiles p where p.id=auth.uid();
 if v_role not in ('admin','head_teacher') or v_school_id is null then raise exception 'Only school leadership can review admissions'; end if;
 update public.students s set admission_status=case when p_decision='approve' then 'admitted' else 'rejected' end, active=(p_decision='approve') where s.id=p_student_id and s.school_id=v_school_id and s.admission_status='pending';
 get diagnostics v_updated = row_count;
 if v_updated=0 then raise exception 'Pending admission not found in your school, or it has already been reviewed'; end if;
 return jsonb_build_object('student_id',p_student_id,'decision',p_decision,'updated',v_updated);
end; $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_setup_school(p_school_name text, p_full_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt()->>'email',''));
  v_school uuid;
begin
  if v_uid is null then raise exception 'Sign in first'; end if;
  if not exists (
    select 1 from auth.users u
    where u.id = v_uid
      and u.email_confirmed_at is not null
      and lower(coalesce(u.email,'')) = v_email
  ) then
    raise exception 'Verify your email address before creating a school';
  end if;
  if exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'This account already has a school profile';
  end if;
  if v_email = '' then raise exception 'A verified account email is required'; end if;
  if exists (
    select 1 from public.school_invites
    where email = v_email and accepted_at is null
  ) then
    raise exception 'A pending school invitation exists for this email. Accept that invitation instead of creating a new school';
  end if;
  if coalesce(trim(p_school_name),'') = '' or coalesce(trim(p_full_name),'') = '' then
    raise exception 'School name and full name are required';
  end if;
  insert into public.schools(name, created_by)
  values(trim(p_school_name), v_uid)
  returning id into v_school;
  insert into public.profiles(id, school_id, full_name, role)
  values(v_uid, v_school, trim(p_full_name), 'admin');
  return jsonb_build_object('school_id', v_school, 'role', 'admin');
end
$function$;


CREATE OR REPLACE FUNCTION public.schoolflow_staff_can_access_attendance(p_session_id uuid, p_student_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ select exists(
 select 1 from public.attendance_sessions s
 join public.classes c on c.id=s.class_id
 join public.students st on st.id=p_student_id
 where s.id=p_session_id and s.school_id=public.schoolflow_my_school_id()
 and st.school_id=s.school_id and st.class_id=c.id
 and ((public.schoolflow_my_role() = any(array['admin','head_teacher'])) or c.teacher_id=(select auth.uid()))
); $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_staff_can_access_session(p_class_id uuid, p_school_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ select exists(
 select 1 from public.classes c where c.id=p_class_id and c.school_id=p_school_id
 and ((public.schoolflow_my_role() = any(array['admin','head_teacher'])) or c.teacher_id=(select auth.uid()))
); $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_student_in_school(p_student_id uuid, p_school_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ select exists(select 1 from public.students s where s.id=p_student_id and s.school_id=p_school_id); $function$;


CREATE OR REPLACE FUNCTION public.schoolflow_submit_admission(p_class_id uuid, p_full_name text, p_admission_date date, p_date_of_birth date, p_guardian_name text, p_guardian_phone text, p_guardian_email text DEFAULT NULL::text)
 RETURNS TABLE(student_id uuid, student_code text)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_school_id uuid;
  v_role text;
  v_student_id uuid;
  v_student_code text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  v_school_id := public.schoolflow_my_school_id();
  v_role := public.schoolflow_my_role();
  if v_school_id is null or v_role <> 'admin' then raise exception 'Only the school admin can submit admissions'; end if;
  if nullif(btrim(p_full_name),'') is null or nullif(btrim(p_guardian_name),'') is null or nullif(btrim(p_guardian_phone),'') is null or p_class_id is null or p_admission_date is null then
    raise exception 'Student, guardian, class, and admission date are required';
  end if;
  if not exists (select 1 from public.classes c where c.id = p_class_id and c.school_id = v_school_id) then
    raise exception 'Selected class is not in your school';
  end if;
  insert into public.students as st (school_id,class_id,full_name,student_code,active,admission_date,admission_status)
  values (v_school_id,p_class_id,btrim(p_full_name),null,false,p_admission_date,'pending')
  returning st.id, st.student_code into v_student_id, v_student_code;
  insert into public.student_guardians (student_id,school_id,date_of_birth,guardian_name,guardian_phone,guardian_email)
  values (v_student_id,v_school_id,p_date_of_birth,btrim(p_guardian_name),btrim(p_guardian_phone),nullif(lower(btrim(coalesce(p_guardian_email,''))), ''));
  return query select v_student_id, v_student_code;
end;
$function$;


-- RLS is enabled before policies are installed

ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.attendance_sessions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.school_conversation_participants ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.school_conversations ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.school_fee_records ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.school_invites ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.school_messages ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.student_guardians ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.student_results ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- Existing row-level security policies

CREATE POLICY "Assigned teacher inserts attendance records" ON public.attendance_records AS permissive FOR INSERT TO authenticated WITH CHECK (((marked_by = ( SELECT auth.uid() AS uid)) AND schoolflow_staff_can_access_attendance(session_id, student_id)));

CREATE POLICY "Assigned teacher or leadership updates attendance records" ON public.attendance_records AS permissive FOR UPDATE TO authenticated USING ((schoolflow_staff_can_access_attendance(session_id, student_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (marked_by = ( SELECT auth.uid() AS uid))))) WITH CHECK (((marked_by = ( SELECT auth.uid() AS uid)) AND schoolflow_staff_can_access_attendance(session_id, student_id)));

CREATE POLICY "Attendance records read permitted" ON public.attendance_records AS permissive FOR SELECT TO authenticated USING (schoolflow_staff_can_access_attendance(session_id, student_id));

CREATE POLICY "Parents read attendance for linked students" ON public.attendance_records AS permissive FOR SELECT TO authenticated USING (schoolflow_parent_linked_student(student_id));

CREATE POLICY "Assigned teacher inserts attendance session" ON public.attendance_sessions AS permissive FOR INSERT TO authenticated WITH CHECK (((school_id = schoolflow_my_school_id()) AND (marked_by = ( SELECT auth.uid() AS uid)) AND schoolflow_staff_can_access_session(class_id, school_id)));

CREATE POLICY "Assigned teacher or leadership updates attendance session" ON public.attendance_sessions AS permissive FOR UPDATE TO authenticated USING (((school_id = schoolflow_my_school_id()) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR ((marked_by = ( SELECT auth.uid() AS uid)) AND schoolflow_staff_can_access_session(class_id, school_id))))) WITH CHECK (((school_id = schoolflow_my_school_id()) AND schoolflow_staff_can_access_session(class_id, school_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (marked_by = ( SELECT auth.uid() AS uid)))));

CREATE POLICY "Attendance sessions read permitted" ON public.attendance_sessions AS permissive FOR SELECT TO authenticated USING (((school_id = schoolflow_my_school_id()) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (EXISTS ( SELECT 1
   FROM classes c
  WHERE ((c.id = attendance_sessions.class_id) AND (c.teacher_id = auth.uid())))))));

CREATE POLICY "Parents read sessions for linked attendance" ON public.attendance_sessions AS permissive FOR SELECT TO authenticated USING (schoolflow_parent_has_session(id, school_id));

CREATE POLICY "Classes read assigned or leadership" ON public.classes AS permissive FOR SELECT TO authenticated USING (((school_id = schoolflow_my_school_id()) AND ((teacher_id = auth.uid()) OR (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])))));

CREATE POLICY "Leadership deletes classes" ON public.classes AS permissive FOR DELETE TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text]))));

CREATE POLICY "Leadership inserts classes" ON public.classes AS permissive FOR INSERT TO authenticated WITH CHECK (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) AND ((teacher_id IS NULL) OR (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = classes.teacher_id) AND (p.school_id = schoolflow_my_school_id()) AND (p.role = 'teacher'::text)))))));

CREATE POLICY "Leadership updates classes" ON public.classes AS permissive FOR UPDATE TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])))) WITH CHECK (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) AND ((teacher_id IS NULL) OR (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = classes.teacher_id) AND (p.school_id = schoolflow_my_school_id()) AND (p.role = 'teacher'::text)))))));

CREATE POLICY "Profiles read self and leadership peers" ON public.profiles AS permissive FOR SELECT TO authenticated USING (((id = auth.uid()) OR ((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])))));

CREATE POLICY "Users can read their own role profile" ON public.profiles AS permissive FOR SELECT TO authenticated USING ((id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "participants update own read marker" ON public.school_conversation_participants AS permissive FOR UPDATE TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "users read own participant row" ON public.school_conversation_participants AS permissive FOR SELECT TO authenticated USING ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "participants and school admins read conversations" ON public.school_conversations AS permissive FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM school_conversation_participants p
  WHERE ((p.conversation_id = school_conversations.id) AND (p.user_id = ( SELECT auth.uid() AS uid))))) OR ((conversation_type = 'parent_teacher'::text) AND (EXISTS ( SELECT 1
   FROM profiles pr
  WHERE ((pr.id = ( SELECT auth.uid() AS uid)) AND (pr.school_id = school_conversations.school_id) AND (pr.role = 'admin'::text)))))));

CREATE POLICY "Admins manage school fee records" ON public.school_fee_records AS permissive FOR ALL TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = 'admin'::text))) WITH CHECK (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = 'admin'::text) AND (EXISTS ( SELECT 1
   FROM students s
  WHERE ((s.id = school_fee_records.student_id) AND (s.school_id = school_fee_records.school_id))))));

CREATE POLICY "Parents read fees for linked students" ON public.school_fee_records AS permissive FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM student_guardians g
  WHERE ((g.student_id = school_fee_records.student_id) AND (g.school_id = school_fee_records.school_id) AND (g.guardian_user_id = ( SELECT auth.uid() AS uid))))) AND (NOT (EXISTS ( SELECT 1
   FROM profiles p
  WHERE (p.id = ( SELECT auth.uid() AS uid)))))));

CREATE POLICY "Leadership reads staff invites" ON public.school_invites AS permissive FOR SELECT TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text]))));

CREATE POLICY "conversation participants send messages" ON public.school_messages AS permissive FOR INSERT TO authenticated WITH CHECK (((sender_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM school_conversation_participants p
  WHERE ((p.conversation_id = school_messages.conversation_id) AND (p.user_id = ( SELECT auth.uid() AS uid)))))));

CREATE POLICY "participants and school admins read messages" ON public.school_messages AS permissive FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM school_conversations c
  WHERE ((c.id = school_messages.conversation_id) AND ((EXISTS ( SELECT 1
           FROM school_conversation_participants p
          WHERE ((p.conversation_id = c.id) AND (p.user_id = ( SELECT auth.uid() AS uid))))) OR ((c.conversation_type = 'parent_teacher'::text) AND (EXISTS ( SELECT 1
           FROM profiles pr
          WHERE ((pr.id = ( SELECT auth.uid() AS uid)) AND (pr.school_id = c.school_id) AND (pr.role = 'admin'::text))))))))));

CREATE POLICY "School members read own school" ON public.schools AS permissive FOR SELECT TO authenticated USING ((id = schoolflow_my_school_id()));

CREATE POLICY "Admins delete student guardian details" ON public.student_guardians AS permissive FOR DELETE TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = 'admin'::text)));

CREATE POLICY "Admins insert student guardian details" ON public.student_guardians AS permissive FOR INSERT TO authenticated WITH CHECK (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = 'admin'::text) AND schoolflow_student_in_school(student_id, school_id)));

CREATE POLICY "Admins update student guardian details" ON public.student_guardians AS permissive FOR UPDATE TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = 'admin'::text))) WITH CHECK (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = 'admin'::text) AND schoolflow_student_in_school(student_id, school_id)));

CREATE POLICY "Leadership reads student guardian details" ON public.student_guardians AS permissive FOR SELECT TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text]))));

CREATE POLICY "Parents read their own guardian links" ON public.student_guardians AS permissive FOR SELECT TO authenticated USING (((guardian_user_id = ( SELECT auth.uid() AS uid)) AND (NOT (EXISTS ( SELECT 1
   FROM profiles p
  WHERE (p.id = ( SELECT auth.uid() AS uid)))))));

CREATE POLICY "Assigned teachers and leadership insert results" ON public.student_results AS permissive FOR INSERT TO authenticated WITH CHECK (((school_id = schoolflow_my_school_id()) AND (entered_by = auth.uid()) AND (EXISTS ( SELECT 1
   FROM (students s
     JOIN classes c ON ((c.id = s.class_id)))
  WHERE ((s.id = student_results.student_id) AND (s.school_id = student_results.school_id) AND (s.class_id = student_results.class_id) AND (c.school_id = student_results.school_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (c.teacher_id = auth.uid())))))));

CREATE POLICY "Assigned teachers and leadership update results" ON public.student_results AS permissive FOR UPDATE TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (EXISTS ( SELECT 1
   FROM classes c
  WHERE ((c.id = student_results.class_id) AND (c.school_id = student_results.school_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (c.teacher_id = auth.uid()))))))) WITH CHECK (((school_id = schoolflow_my_school_id()) AND (entered_by = auth.uid()) AND (EXISTS ( SELECT 1
   FROM (students s
     JOIN classes c ON ((c.id = s.class_id)))
  WHERE ((s.id = student_results.student_id) AND (s.school_id = student_results.school_id) AND (s.class_id = student_results.class_id) AND (c.school_id = student_results.school_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (c.teacher_id = auth.uid())))))));

CREATE POLICY "Leadership deletes student results" ON public.student_results AS permissive FOR DELETE TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text]))));

CREATE POLICY "Parents read results for linked students" ON public.student_results AS permissive FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM student_guardians g
  WHERE ((g.student_id = student_results.student_id) AND (g.school_id = student_results.school_id) AND (g.guardian_user_id = ( SELECT auth.uid() AS uid))))) AND (NOT (EXISTS ( SELECT 1
   FROM profiles p
  WHERE (p.id = ( SELECT auth.uid() AS uid)))))));

CREATE POLICY "School staff read permitted student results" ON public.student_results AS permissive FOR SELECT TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (EXISTS ( SELECT 1
   FROM classes c
  WHERE ((c.id = student_results.class_id) AND (c.school_id = student_results.school_id) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (c.teacher_id = auth.uid())))))));

CREATE POLICY "Admins delete students" ON public.students AS permissive FOR DELETE TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = 'admin'::text)));

CREATE POLICY "Admins insert students" ON public.students AS permissive FOR INSERT TO authenticated WITH CHECK (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = 'admin'::text) AND (EXISTS ( SELECT 1
   FROM classes c
  WHERE ((c.id = students.class_id) AND (c.school_id = students.school_id) AND (c.school_id = schoolflow_my_school_id()))))));

CREATE POLICY "Admins update students" ON public.students AS permissive FOR UPDATE TO authenticated USING (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = 'admin'::text))) WITH CHECK (((school_id = schoolflow_my_school_id()) AND (schoolflow_my_role() = 'admin'::text) AND (EXISTS ( SELECT 1
   FROM classes c
  WHERE ((c.id = students.class_id) AND (c.school_id = students.school_id) AND (c.school_id = schoolflow_my_school_id()))))));

CREATE POLICY "Parents read their linked students" ON public.students AS permissive FOR SELECT TO authenticated USING (schoolflow_parent_linked_student(id, school_id));

CREATE POLICY "Students read permitted class" ON public.students AS permissive FOR SELECT TO authenticated USING (((school_id = schoolflow_my_school_id()) AND ((schoolflow_my_role() = ANY (ARRAY['admin'::text, 'head_teacher'::text])) OR (EXISTS ( SELECT 1
   FROM classes c
  WHERE ((c.id = students.class_id) AND (c.teacher_id = auth.uid())))))));

-- Existing application triggers

CREATE TRIGGER schoolflow_student_code_trigger BEFORE INSERT ON students FOR EACH ROW EXECUTE FUNCTION schoolflow_generate_student_code();

-- Explicit table grants copied from source ACLs

GRANT DELETE ON TABLE public.attendance_records TO anon;

GRANT DELETE ON TABLE public.attendance_records TO authenticated;

GRANT DELETE ON TABLE public.attendance_records TO postgres;

GRANT DELETE ON TABLE public.attendance_records TO service_role;

GRANT DELETE ON TABLE public.attendance_sessions TO anon;

GRANT DELETE ON TABLE public.attendance_sessions TO authenticated;

GRANT DELETE ON TABLE public.attendance_sessions TO postgres;

GRANT DELETE ON TABLE public.attendance_sessions TO service_role;

GRANT DELETE ON TABLE public.classes TO anon;

GRANT DELETE ON TABLE public.classes TO authenticated;

GRANT DELETE ON TABLE public.classes TO postgres;

GRANT DELETE ON TABLE public.classes TO service_role;

GRANT DELETE ON TABLE public.profiles TO anon;

GRANT DELETE ON TABLE public.profiles TO authenticated;

GRANT DELETE ON TABLE public.profiles TO postgres;

GRANT DELETE ON TABLE public.profiles TO service_role;

GRANT DELETE ON TABLE public.school_conversation_participants TO anon;

GRANT DELETE ON TABLE public.school_conversation_participants TO authenticated;

GRANT DELETE ON TABLE public.school_conversation_participants TO postgres;

GRANT DELETE ON TABLE public.school_conversation_participants TO service_role;

GRANT DELETE ON TABLE public.school_conversations TO anon;

GRANT DELETE ON TABLE public.school_conversations TO authenticated;

GRANT DELETE ON TABLE public.school_conversations TO postgres;

GRANT DELETE ON TABLE public.school_conversations TO service_role;

GRANT DELETE ON TABLE public.school_fee_records TO authenticated;

GRANT DELETE ON TABLE public.school_fee_records TO postgres;

GRANT DELETE ON TABLE public.school_fee_records TO service_role;

GRANT DELETE ON TABLE public.school_invites TO anon;

GRANT DELETE ON TABLE public.school_invites TO authenticated;

GRANT DELETE ON TABLE public.school_invites TO postgres;

GRANT DELETE ON TABLE public.school_invites TO service_role;

GRANT DELETE ON TABLE public.school_messages TO anon;

GRANT DELETE ON TABLE public.school_messages TO authenticated;

GRANT DELETE ON TABLE public.school_messages TO postgres;

GRANT DELETE ON TABLE public.school_messages TO service_role;

GRANT DELETE ON TABLE public.schools TO anon;

GRANT DELETE ON TABLE public.schools TO authenticated;

GRANT DELETE ON TABLE public.schools TO postgres;

GRANT DELETE ON TABLE public.schools TO service_role;

GRANT DELETE ON TABLE public.student_guardians TO authenticated;

GRANT DELETE ON TABLE public.student_guardians TO postgres;

GRANT DELETE ON TABLE public.student_guardians TO service_role;

GRANT DELETE ON TABLE public.student_results TO authenticated;

GRANT DELETE ON TABLE public.student_results TO postgres;

GRANT DELETE ON TABLE public.student_results TO service_role;

GRANT DELETE ON TABLE public.students TO anon;

GRANT DELETE ON TABLE public.students TO authenticated;

GRANT DELETE ON TABLE public.students TO postgres;

GRANT DELETE ON TABLE public.students TO service_role;

GRANT INSERT ON TABLE public.attendance_records TO anon;

GRANT INSERT ON TABLE public.attendance_records TO authenticated;

GRANT INSERT ON TABLE public.attendance_records TO postgres;

GRANT INSERT ON TABLE public.attendance_records TO service_role;

GRANT INSERT ON TABLE public.attendance_sessions TO anon;

GRANT INSERT ON TABLE public.attendance_sessions TO authenticated;

GRANT INSERT ON TABLE public.attendance_sessions TO postgres;

GRANT INSERT ON TABLE public.attendance_sessions TO service_role;

GRANT INSERT ON TABLE public.classes TO anon;

GRANT INSERT ON TABLE public.classes TO authenticated;

GRANT INSERT ON TABLE public.classes TO postgres;

GRANT INSERT ON TABLE public.classes TO service_role;

GRANT INSERT ON TABLE public.profiles TO anon;

GRANT INSERT ON TABLE public.profiles TO authenticated;

GRANT INSERT ON TABLE public.profiles TO postgres;

GRANT INSERT ON TABLE public.profiles TO service_role;

GRANT INSERT ON TABLE public.school_conversation_participants TO anon;

GRANT INSERT ON TABLE public.school_conversation_participants TO authenticated;

GRANT INSERT ON TABLE public.school_conversation_participants TO postgres;

GRANT INSERT ON TABLE public.school_conversation_participants TO service_role;

GRANT INSERT ON TABLE public.school_conversations TO anon;

GRANT INSERT ON TABLE public.school_conversations TO authenticated;

GRANT INSERT ON TABLE public.school_conversations TO postgres;

GRANT INSERT ON TABLE public.school_conversations TO service_role;

GRANT INSERT ON TABLE public.school_fee_records TO authenticated;

GRANT INSERT ON TABLE public.school_fee_records TO postgres;

GRANT INSERT ON TABLE public.school_fee_records TO service_role;

GRANT INSERT ON TABLE public.school_invites TO anon;

GRANT INSERT ON TABLE public.school_invites TO authenticated;

GRANT INSERT ON TABLE public.school_invites TO postgres;

GRANT INSERT ON TABLE public.school_invites TO service_role;

GRANT INSERT ON TABLE public.school_messages TO anon;

GRANT INSERT ON TABLE public.school_messages TO authenticated;

GRANT INSERT ON TABLE public.school_messages TO postgres;

GRANT INSERT ON TABLE public.school_messages TO service_role;

GRANT INSERT ON TABLE public.schools TO anon;

GRANT INSERT ON TABLE public.schools TO authenticated;

GRANT INSERT ON TABLE public.schools TO postgres;

GRANT INSERT ON TABLE public.schools TO service_role;

GRANT INSERT ON TABLE public.student_guardians TO authenticated;

GRANT INSERT ON TABLE public.student_guardians TO postgres;

GRANT INSERT ON TABLE public.student_guardians TO service_role;

GRANT INSERT ON TABLE public.student_results TO authenticated;

GRANT INSERT ON TABLE public.student_results TO postgres;

GRANT INSERT ON TABLE public.student_results TO service_role;

GRANT INSERT ON TABLE public.students TO anon;

GRANT INSERT ON TABLE public.students TO authenticated;

GRANT INSERT ON TABLE public.students TO postgres;

GRANT INSERT ON TABLE public.students TO service_role;

GRANT MAINTAIN ON TABLE public.attendance_records TO anon;

GRANT MAINTAIN ON TABLE public.attendance_records TO authenticated;

GRANT MAINTAIN ON TABLE public.attendance_records TO postgres;

GRANT MAINTAIN ON TABLE public.attendance_records TO service_role;

GRANT MAINTAIN ON TABLE public.attendance_sessions TO anon;

GRANT MAINTAIN ON TABLE public.attendance_sessions TO authenticated;

GRANT MAINTAIN ON TABLE public.attendance_sessions TO postgres;

GRANT MAINTAIN ON TABLE public.attendance_sessions TO service_role;

GRANT MAINTAIN ON TABLE public.classes TO anon;

GRANT MAINTAIN ON TABLE public.classes TO authenticated;

GRANT MAINTAIN ON TABLE public.classes TO postgres;

GRANT MAINTAIN ON TABLE public.classes TO service_role;

GRANT MAINTAIN ON TABLE public.profiles TO anon;

GRANT MAINTAIN ON TABLE public.profiles TO authenticated;

GRANT MAINTAIN ON TABLE public.profiles TO postgres;

GRANT MAINTAIN ON TABLE public.profiles TO service_role;

GRANT MAINTAIN ON TABLE public.school_conversation_participants TO anon;

GRANT MAINTAIN ON TABLE public.school_conversation_participants TO authenticated;

GRANT MAINTAIN ON TABLE public.school_conversation_participants TO postgres;

GRANT MAINTAIN ON TABLE public.school_conversation_participants TO service_role;

GRANT MAINTAIN ON TABLE public.school_conversations TO anon;

GRANT MAINTAIN ON TABLE public.school_conversations TO authenticated;

GRANT MAINTAIN ON TABLE public.school_conversations TO postgres;

GRANT MAINTAIN ON TABLE public.school_conversations TO service_role;

GRANT MAINTAIN ON TABLE public.school_fee_records TO authenticated;

GRANT MAINTAIN ON TABLE public.school_fee_records TO postgres;

GRANT MAINTAIN ON TABLE public.school_fee_records TO service_role;

GRANT MAINTAIN ON TABLE public.school_invites TO anon;

GRANT MAINTAIN ON TABLE public.school_invites TO authenticated;

GRANT MAINTAIN ON TABLE public.school_invites TO postgres;

GRANT MAINTAIN ON TABLE public.school_invites TO service_role;

GRANT MAINTAIN ON TABLE public.school_messages TO anon;

GRANT MAINTAIN ON TABLE public.school_messages TO authenticated;

GRANT MAINTAIN ON TABLE public.school_messages TO postgres;

GRANT MAINTAIN ON TABLE public.school_messages TO service_role;

GRANT MAINTAIN ON TABLE public.schools TO anon;

GRANT MAINTAIN ON TABLE public.schools TO authenticated;

GRANT MAINTAIN ON TABLE public.schools TO postgres;

GRANT MAINTAIN ON TABLE public.schools TO service_role;

GRANT MAINTAIN ON TABLE public.student_guardians TO authenticated;

GRANT MAINTAIN ON TABLE public.student_guardians TO postgres;

GRANT MAINTAIN ON TABLE public.student_guardians TO service_role;

GRANT MAINTAIN ON TABLE public.student_results TO authenticated;

GRANT MAINTAIN ON TABLE public.student_results TO postgres;

GRANT MAINTAIN ON TABLE public.student_results TO service_role;

GRANT MAINTAIN ON TABLE public.students TO anon;

GRANT MAINTAIN ON TABLE public.students TO authenticated;

GRANT MAINTAIN ON TABLE public.students TO postgres;

GRANT MAINTAIN ON TABLE public.students TO service_role;

GRANT REFERENCES ON TABLE public.attendance_records TO anon;

GRANT REFERENCES ON TABLE public.attendance_records TO authenticated;

GRANT REFERENCES ON TABLE public.attendance_records TO postgres;

GRANT REFERENCES ON TABLE public.attendance_records TO service_role;

GRANT REFERENCES ON TABLE public.attendance_sessions TO anon;

GRANT REFERENCES ON TABLE public.attendance_sessions TO authenticated;

GRANT REFERENCES ON TABLE public.attendance_sessions TO postgres;

GRANT REFERENCES ON TABLE public.attendance_sessions TO service_role;

GRANT REFERENCES ON TABLE public.classes TO anon;

GRANT REFERENCES ON TABLE public.classes TO authenticated;

GRANT REFERENCES ON TABLE public.classes TO postgres;

GRANT REFERENCES ON TABLE public.classes TO service_role;

GRANT REFERENCES ON TABLE public.profiles TO anon;

GRANT REFERENCES ON TABLE public.profiles TO authenticated;

GRANT REFERENCES ON TABLE public.profiles TO postgres;

GRANT REFERENCES ON TABLE public.profiles TO service_role;

GRANT REFERENCES ON TABLE public.school_conversation_participants TO anon;

GRANT REFERENCES ON TABLE public.school_conversation_participants TO authenticated;

GRANT REFERENCES ON TABLE public.school_conversation_participants TO postgres;

GRANT REFERENCES ON TABLE public.school_conversation_participants TO service_role;

GRANT REFERENCES ON TABLE public.school_conversations TO anon;

GRANT REFERENCES ON TABLE public.school_conversations TO authenticated;

GRANT REFERENCES ON TABLE public.school_conversations TO postgres;

GRANT REFERENCES ON TABLE public.school_conversations TO service_role;

GRANT REFERENCES ON TABLE public.school_fee_records TO authenticated;

GRANT REFERENCES ON TABLE public.school_fee_records TO postgres;

GRANT REFERENCES ON TABLE public.school_fee_records TO service_role;

GRANT REFERENCES ON TABLE public.school_invites TO anon;

GRANT REFERENCES ON TABLE public.school_invites TO authenticated;

GRANT REFERENCES ON TABLE public.school_invites TO postgres;

GRANT REFERENCES ON TABLE public.school_invites TO service_role;

GRANT REFERENCES ON TABLE public.school_messages TO anon;

GRANT REFERENCES ON TABLE public.school_messages TO authenticated;

GRANT REFERENCES ON TABLE public.school_messages TO postgres;

GRANT REFERENCES ON TABLE public.school_messages TO service_role;

GRANT REFERENCES ON TABLE public.schools TO anon;

GRANT REFERENCES ON TABLE public.schools TO authenticated;

GRANT REFERENCES ON TABLE public.schools TO postgres;

GRANT REFERENCES ON TABLE public.schools TO service_role;

GRANT REFERENCES ON TABLE public.student_guardians TO authenticated;

GRANT REFERENCES ON TABLE public.student_guardians TO postgres;

GRANT REFERENCES ON TABLE public.student_guardians TO service_role;

GRANT REFERENCES ON TABLE public.student_results TO authenticated;

GRANT REFERENCES ON TABLE public.student_results TO postgres;

GRANT REFERENCES ON TABLE public.student_results TO service_role;

GRANT REFERENCES ON TABLE public.students TO anon;

GRANT REFERENCES ON TABLE public.students TO authenticated;

GRANT REFERENCES ON TABLE public.students TO postgres;

GRANT REFERENCES ON TABLE public.students TO service_role;

GRANT SELECT ON TABLE public.attendance_records TO anon;

GRANT SELECT ON TABLE public.attendance_records TO authenticated;

GRANT SELECT ON TABLE public.attendance_records TO postgres;

GRANT SELECT ON TABLE public.attendance_records TO service_role;

GRANT SELECT ON TABLE public.attendance_sessions TO anon;

GRANT SELECT ON TABLE public.attendance_sessions TO authenticated;

GRANT SELECT ON TABLE public.attendance_sessions TO postgres;

GRANT SELECT ON TABLE public.attendance_sessions TO service_role;

GRANT SELECT ON TABLE public.classes TO anon;

GRANT SELECT ON TABLE public.classes TO authenticated;

GRANT SELECT ON TABLE public.classes TO postgres;

GRANT SELECT ON TABLE public.classes TO service_role;

GRANT SELECT ON TABLE public.profiles TO anon;

GRANT SELECT ON TABLE public.profiles TO authenticated;

GRANT SELECT ON TABLE public.profiles TO postgres;

GRANT SELECT ON TABLE public.profiles TO service_role;

GRANT SELECT ON TABLE public.school_conversation_participants TO anon;

GRANT SELECT ON TABLE public.school_conversation_participants TO authenticated;

GRANT SELECT ON TABLE public.school_conversation_participants TO postgres;

GRANT SELECT ON TABLE public.school_conversation_participants TO service_role;

GRANT SELECT ON TABLE public.school_conversations TO anon;

GRANT SELECT ON TABLE public.school_conversations TO authenticated;

GRANT SELECT ON TABLE public.school_conversations TO postgres;

GRANT SELECT ON TABLE public.school_conversations TO service_role;

GRANT SELECT ON TABLE public.school_fee_records TO authenticated;

GRANT SELECT ON TABLE public.school_fee_records TO postgres;

GRANT SELECT ON TABLE public.school_fee_records TO service_role;

GRANT SELECT ON TABLE public.school_invites TO anon;

GRANT SELECT ON TABLE public.school_invites TO authenticated;

GRANT SELECT ON TABLE public.school_invites TO postgres;

GRANT SELECT ON TABLE public.school_invites TO service_role;

GRANT SELECT ON TABLE public.school_messages TO anon;

GRANT SELECT ON TABLE public.school_messages TO authenticated;

GRANT SELECT ON TABLE public.school_messages TO postgres;

GRANT SELECT ON TABLE public.school_messages TO service_role;

GRANT SELECT ON TABLE public.schools TO anon;

GRANT SELECT ON TABLE public.schools TO authenticated;

GRANT SELECT ON TABLE public.schools TO postgres;

GRANT SELECT ON TABLE public.schools TO service_role;

GRANT SELECT ON TABLE public.student_guardians TO authenticated;

GRANT SELECT ON TABLE public.student_guardians TO postgres;

GRANT SELECT ON TABLE public.student_guardians TO service_role;

GRANT SELECT ON TABLE public.student_results TO authenticated;

GRANT SELECT ON TABLE public.student_results TO postgres;

GRANT SELECT ON TABLE public.student_results TO service_role;

GRANT SELECT ON TABLE public.students TO anon;

GRANT SELECT ON TABLE public.students TO authenticated;

GRANT SELECT ON TABLE public.students TO postgres;

GRANT SELECT ON TABLE public.students TO service_role;

GRANT TRIGGER ON TABLE public.attendance_records TO anon;

GRANT TRIGGER ON TABLE public.attendance_records TO authenticated;

GRANT TRIGGER ON TABLE public.attendance_records TO postgres;

GRANT TRIGGER ON TABLE public.attendance_records TO service_role;

GRANT TRIGGER ON TABLE public.attendance_sessions TO anon;

GRANT TRIGGER ON TABLE public.attendance_sessions TO authenticated;

GRANT TRIGGER ON TABLE public.attendance_sessions TO postgres;

GRANT TRIGGER ON TABLE public.attendance_sessions TO service_role;

GRANT TRIGGER ON TABLE public.classes TO anon;

GRANT TRIGGER ON TABLE public.classes TO authenticated;

GRANT TRIGGER ON TABLE public.classes TO postgres;

GRANT TRIGGER ON TABLE public.classes TO service_role;

GRANT TRIGGER ON TABLE public.profiles TO anon;

GRANT TRIGGER ON TABLE public.profiles TO authenticated;

GRANT TRIGGER ON TABLE public.profiles TO postgres;

GRANT TRIGGER ON TABLE public.profiles TO service_role;

GRANT TRIGGER ON TABLE public.school_conversation_participants TO anon;

GRANT TRIGGER ON TABLE public.school_conversation_participants TO authenticated;

GRANT TRIGGER ON TABLE public.school_conversation_participants TO postgres;

GRANT TRIGGER ON TABLE public.school_conversation_participants TO service_role;

GRANT TRIGGER ON TABLE public.school_conversations TO anon;

GRANT TRIGGER ON TABLE public.school_conversations TO authenticated;

GRANT TRIGGER ON TABLE public.school_conversations TO postgres;

GRANT TRIGGER ON TABLE public.school_conversations TO service_role;

GRANT TRIGGER ON TABLE public.school_fee_records TO authenticated;

GRANT TRIGGER ON TABLE public.school_fee_records TO postgres;

GRANT TRIGGER ON TABLE public.school_fee_records TO service_role;

GRANT TRIGGER ON TABLE public.school_invites TO anon;

GRANT TRIGGER ON TABLE public.school_invites TO authenticated;

GRANT TRIGGER ON TABLE public.school_invites TO postgres;

GRANT TRIGGER ON TABLE public.school_invites TO service_role;

GRANT TRIGGER ON TABLE public.school_messages TO anon;

GRANT TRIGGER ON TABLE public.school_messages TO authenticated;

GRANT TRIGGER ON TABLE public.school_messages TO postgres;

GRANT TRIGGER ON TABLE public.school_messages TO service_role;

GRANT TRIGGER ON TABLE public.schools TO anon;

GRANT TRIGGER ON TABLE public.schools TO authenticated;

GRANT TRIGGER ON TABLE public.schools TO postgres;

GRANT TRIGGER ON TABLE public.schools TO service_role;

GRANT TRIGGER ON TABLE public.student_guardians TO authenticated;

GRANT TRIGGER ON TABLE public.student_guardians TO postgres;

GRANT TRIGGER ON TABLE public.student_guardians TO service_role;

GRANT TRIGGER ON TABLE public.student_results TO authenticated;

GRANT TRIGGER ON TABLE public.student_results TO postgres;

GRANT TRIGGER ON TABLE public.student_results TO service_role;

GRANT TRIGGER ON TABLE public.students TO anon;

GRANT TRIGGER ON TABLE public.students TO authenticated;

GRANT TRIGGER ON TABLE public.students TO postgres;

GRANT TRIGGER ON TABLE public.students TO service_role;

GRANT TRUNCATE ON TABLE public.attendance_records TO anon;

GRANT TRUNCATE ON TABLE public.attendance_records TO authenticated;

GRANT TRUNCATE ON TABLE public.attendance_records TO postgres;

GRANT TRUNCATE ON TABLE public.attendance_records TO service_role;

GRANT TRUNCATE ON TABLE public.attendance_sessions TO anon;

GRANT TRUNCATE ON TABLE public.attendance_sessions TO authenticated;

GRANT TRUNCATE ON TABLE public.attendance_sessions TO postgres;

GRANT TRUNCATE ON TABLE public.attendance_sessions TO service_role;

GRANT TRUNCATE ON TABLE public.classes TO anon;

GRANT TRUNCATE ON TABLE public.classes TO authenticated;

GRANT TRUNCATE ON TABLE public.classes TO postgres;

GRANT TRUNCATE ON TABLE public.classes TO service_role;

GRANT TRUNCATE ON TABLE public.profiles TO anon;

GRANT TRUNCATE ON TABLE public.profiles TO authenticated;

GRANT TRUNCATE ON TABLE public.profiles TO postgres;

GRANT TRUNCATE ON TABLE public.profiles TO service_role;

GRANT TRUNCATE ON TABLE public.school_conversation_participants TO anon;

GRANT TRUNCATE ON TABLE public.school_conversation_participants TO authenticated;

GRANT TRUNCATE ON TABLE public.school_conversation_participants TO postgres;

GRANT TRUNCATE ON TABLE public.school_conversation_participants TO service_role;

GRANT TRUNCATE ON TABLE public.school_conversations TO anon;

GRANT TRUNCATE ON TABLE public.school_conversations TO authenticated;

GRANT TRUNCATE ON TABLE public.school_conversations TO postgres;

GRANT TRUNCATE ON TABLE public.school_conversations TO service_role;

GRANT TRUNCATE ON TABLE public.school_fee_records TO authenticated;

GRANT TRUNCATE ON TABLE public.school_fee_records TO postgres;

GRANT TRUNCATE ON TABLE public.school_fee_records TO service_role;

GRANT TRUNCATE ON TABLE public.school_invites TO anon;

GRANT TRUNCATE ON TABLE public.school_invites TO authenticated;

GRANT TRUNCATE ON TABLE public.school_invites TO postgres;

GRANT TRUNCATE ON TABLE public.school_invites TO service_role;

GRANT TRUNCATE ON TABLE public.school_messages TO anon;

GRANT TRUNCATE ON TABLE public.school_messages TO authenticated;

GRANT TRUNCATE ON TABLE public.school_messages TO postgres;

GRANT TRUNCATE ON TABLE public.school_messages TO service_role;

GRANT TRUNCATE ON TABLE public.schools TO anon;

GRANT TRUNCATE ON TABLE public.schools TO authenticated;

GRANT TRUNCATE ON TABLE public.schools TO postgres;

GRANT TRUNCATE ON TABLE public.schools TO service_role;

GRANT TRUNCATE ON TABLE public.student_guardians TO authenticated;

GRANT TRUNCATE ON TABLE public.student_guardians TO postgres;

GRANT TRUNCATE ON TABLE public.student_guardians TO service_role;

GRANT TRUNCATE ON TABLE public.student_results TO authenticated;

GRANT TRUNCATE ON TABLE public.student_results TO postgres;

GRANT TRUNCATE ON TABLE public.student_results TO service_role;

GRANT TRUNCATE ON TABLE public.students TO anon;

GRANT TRUNCATE ON TABLE public.students TO authenticated;

GRANT TRUNCATE ON TABLE public.students TO postgres;

GRANT TRUNCATE ON TABLE public.students TO service_role;

GRANT UPDATE ON TABLE public.attendance_records TO anon;

GRANT UPDATE ON TABLE public.attendance_records TO authenticated;

GRANT UPDATE ON TABLE public.attendance_records TO postgres;

GRANT UPDATE ON TABLE public.attendance_records TO service_role;

GRANT UPDATE ON TABLE public.attendance_sessions TO anon;

GRANT UPDATE ON TABLE public.attendance_sessions TO authenticated;

GRANT UPDATE ON TABLE public.attendance_sessions TO postgres;

GRANT UPDATE ON TABLE public.attendance_sessions TO service_role;

GRANT UPDATE ON TABLE public.classes TO anon;

GRANT UPDATE ON TABLE public.classes TO authenticated;

GRANT UPDATE ON TABLE public.classes TO postgres;

GRANT UPDATE ON TABLE public.classes TO service_role;

GRANT UPDATE ON TABLE public.profiles TO anon;

GRANT UPDATE ON TABLE public.profiles TO authenticated;

GRANT UPDATE ON TABLE public.profiles TO postgres;

GRANT UPDATE ON TABLE public.profiles TO service_role;

GRANT UPDATE ON TABLE public.school_conversation_participants TO anon;

GRANT UPDATE ON TABLE public.school_conversation_participants TO postgres;

GRANT UPDATE ON TABLE public.school_conversation_participants TO service_role;

GRANT UPDATE ON TABLE public.school_conversations TO anon;

GRANT UPDATE ON TABLE public.school_conversations TO authenticated;

GRANT UPDATE ON TABLE public.school_conversations TO postgres;

GRANT UPDATE ON TABLE public.school_conversations TO service_role;

GRANT UPDATE ON TABLE public.school_fee_records TO authenticated;

GRANT UPDATE ON TABLE public.school_fee_records TO postgres;

GRANT UPDATE ON TABLE public.school_fee_records TO service_role;

GRANT UPDATE ON TABLE public.school_invites TO anon;

GRANT UPDATE ON TABLE public.school_invites TO authenticated;

GRANT UPDATE ON TABLE public.school_invites TO postgres;

GRANT UPDATE ON TABLE public.school_invites TO service_role;

GRANT UPDATE ON TABLE public.school_messages TO anon;

GRANT UPDATE ON TABLE public.school_messages TO authenticated;

GRANT UPDATE ON TABLE public.school_messages TO postgres;

GRANT UPDATE ON TABLE public.school_messages TO service_role;

GRANT UPDATE ON TABLE public.schools TO anon;

GRANT UPDATE ON TABLE public.schools TO authenticated;

GRANT UPDATE ON TABLE public.schools TO postgres;

GRANT UPDATE ON TABLE public.schools TO service_role;

GRANT UPDATE ON TABLE public.student_guardians TO authenticated;

GRANT UPDATE ON TABLE public.student_guardians TO postgres;

GRANT UPDATE ON TABLE public.student_guardians TO service_role;

GRANT UPDATE ON TABLE public.student_results TO authenticated;

GRANT UPDATE ON TABLE public.student_results TO postgres;

GRANT UPDATE ON TABLE public.student_results TO service_role;

GRANT UPDATE ON TABLE public.students TO anon;

GRANT UPDATE ON TABLE public.students TO authenticated;

GRANT UPDATE ON TABLE public.students TO postgres;

GRANT UPDATE ON TABLE public.students TO service_role;

REVOKE ALL ON TABLE public.attendance_records FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.attendance_sessions FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.classes FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.profiles FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.school_conversation_participants FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.school_conversations FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.school_fee_records FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.school_invites FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.school_messages FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.schools FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.student_guardians FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.student_results FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON TABLE public.students FROM PUBLIC, anon, authenticated, service_role;

-- Explicit function grants copied from source ACLs

GRANT EXECUTE ON FUNCTION public.schoolflow_accept_invite(p_full_name text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_accept_invite(p_full_name text) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_accept_invite(p_full_name text) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_conversation(p_type text, p_student_id uuid, p_recipient_user_id uuid, p_subject text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_conversation(p_type text, p_student_id uuid, p_recipient_user_id uuid, p_subject text) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_conversation(p_type text, p_student_id uuid, p_recipient_user_id uuid, p_subject text) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_invite(p_email text, p_role text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_invite(p_email text, p_role text) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_invite(p_email text, p_role text) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_school_groups() TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_school_groups() TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_create_school_groups() TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_generate_student_code() TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.schoolflow_generate_student_code() TO anon;

GRANT EXECUTE ON FUNCTION public.schoolflow_generate_student_code() TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_generate_student_code() TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_generate_student_code() TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_link_parent_account(p_student_id uuid, p_parent_email text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_link_parent_account(p_student_id uuid, p_parent_email text) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_link_parent_account(p_student_id uuid, p_parent_email text) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_my_role() TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_my_role() TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_my_role() TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_my_school_id() TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_my_school_id() TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_my_school_id() TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_has_session(p_session_id uuid, p_school_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_has_session(p_session_id uuid, p_school_id uuid) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_has_session(p_session_id uuid, p_school_id uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid, p_school_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid, p_school_id uuid) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid, p_school_id uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_message_recipients(p_role text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_message_recipients(p_role text) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_parent_message_recipients(p_role text) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_review_admission(p_student_id uuid, p_decision text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_review_admission(p_student_id uuid, p_decision text) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_review_admission(p_student_id uuid, p_decision text) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_setup_school(p_school_name text, p_full_name text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_setup_school(p_school_name text, p_full_name text) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_setup_school(p_school_name text, p_full_name text) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_staff_can_access_attendance(p_session_id uuid, p_student_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_staff_can_access_attendance(p_session_id uuid, p_student_id uuid) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_staff_can_access_attendance(p_session_id uuid, p_student_id uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_staff_can_access_session(p_class_id uuid, p_school_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_staff_can_access_session(p_class_id uuid, p_school_id uuid) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_staff_can_access_session(p_class_id uuid, p_school_id uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_student_in_school(p_student_id uuid, p_school_id uuid) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_student_in_school(p_student_id uuid, p_school_id uuid) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_student_in_school(p_student_id uuid, p_school_id uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.schoolflow_submit_admission(p_class_id uuid, p_full_name text, p_admission_date date, p_date_of_birth date, p_guardian_name text, p_guardian_phone text, p_guardian_email text) TO authenticated;

GRANT EXECUTE ON FUNCTION public.schoolflow_submit_admission(p_class_id uuid, p_full_name text, p_admission_date date, p_date_of_birth date, p_guardian_name text, p_guardian_phone text, p_guardian_email text) TO postgres;

GRANT EXECUTE ON FUNCTION public.schoolflow_submit_admission(p_class_id uuid, p_full_name text, p_admission_date date, p_date_of_birth date, p_guardian_name text, p_guardian_phone text, p_guardian_email text) TO service_role;

REVOKE ALL ON FUNCTION public.schoolflow_accept_invite(p_full_name text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_create_conversation(p_type text, p_student_id uuid, p_recipient_user_id uuid, p_subject text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_create_invite(p_email text, p_role text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_create_school_groups() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_generate_student_code() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_link_parent_account(p_student_id uuid, p_parent_email text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_my_role() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_my_school_id() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_parent_has_session(p_session_id uuid, p_school_id uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_parent_linked_student(p_student_id uuid, p_school_id uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_parent_message_recipients(p_role text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_review_admission(p_student_id uuid, p_decision text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_setup_school(p_school_name text, p_full_name text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_staff_can_access_attendance(p_session_id uuid, p_student_id uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_staff_can_access_session(p_class_id uuid, p_school_id uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_student_in_school(p_student_id uuid, p_school_id uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.schoolflow_submit_admission(p_class_id uuid, p_full_name text, p_admission_date date, p_date_of_birth date, p_guardian_name text, p_guardian_phone text, p_guardian_email text) FROM PUBLIC, anon, authenticated;

-- Realtime publication membership

ALTER PUBLICATION supabase_realtime ADD TABLE public.school_messages;

commit;

