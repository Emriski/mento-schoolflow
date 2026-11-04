-- SchoolFlow: enforce exclusive staff vs parent portal access.
-- Applied to Supabase project rkwcfkkckfitcgvstekr on 2026-11-04.
-- Staff profiles take precedence: an Auth user with a public.profiles row
-- cannot read parent-only guardian, student, attendance, fee, or result data.

create or replace function public.schoolflow_parent_linked_student(p_student_id uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select not exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
  ) and exists (
    select 1 from public.student_guardians g
    where g.student_id = p_student_id
      and g.guardian_user_id = (select auth.uid())
  );
$$;

create or replace function public.schoolflow_parent_has_session(p_session_id uuid, p_school_id uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select not exists (
    select 1 from public.profiles p where p.id = (select auth.uid())
  ) and exists (
    select 1 from public.attendance_records ar
    join public.student_guardians g on g.student_id = ar.student_id
    where ar.session_id = p_session_id
      and g.school_id = p_school_id
      and g.guardian_user_id = (select auth.uid())
  );
$$;

drop policy if exists "Parents read their own guardian links" on public.student_guardians;
create policy "Parents read their own guardian links"
on public.student_guardians for select to authenticated
using (
  guardian_user_id = (select auth.uid())
  and not exists (select 1 from public.profiles p where p.id = (select auth.uid()))
);

drop policy if exists "Parents read fees for linked students" on public.school_fee_records;
create policy "Parents read fees for linked students"
on public.school_fee_records for select to authenticated
using (
  exists (
    select 1 from public.student_guardians g
    where g.student_id = school_fee_records.student_id
      and g.school_id = school_fee_records.school_id
      and g.guardian_user_id = (select auth.uid())
  )
  and not exists (select 1 from public.profiles p where p.id = (select auth.uid()))
);

drop policy if exists "Parents read results for linked students" on public.student_results;
create policy "Parents read results for linked students"
on public.student_results for select to authenticated
using (
  exists (
    select 1 from public.student_guardians g
    where g.student_id = student_results.student_id
      and g.school_id = student_results.school_id
      and g.guardian_user_id = (select auth.uid())
  )
  and not exists (select 1 from public.profiles p where p.id = (select auth.uid()))
);
