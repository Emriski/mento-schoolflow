-- Class-based school fee schedules.
-- Review and apply manually only after the application changes are tested.
-- This migration is intentionally NOT executed against the live Supabase database.

create table if not exists public.school_fee_schedules (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  academic_year text not null,
  term text not null check (term in ('First Term','Second Term','Third Term')),
  items jsonb not null default '[]'::jsonb,
  total_due numeric(12,2) not null default 0 check (total_due >= 0),
  is_published boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint school_fee_schedules_scope_key unique (school_id, class_id, academic_year, term),
  constraint school_fee_schedules_items_array check (jsonb_typeof(items) = 'array')
);

create index if not exists school_fee_schedules_school_year_term_idx
  on public.school_fee_schedules (school_id, academic_year, term);

alter table public.school_fee_schedules enable row level security;

drop policy if exists "Admins manage class fee schedules" on public.school_fee_schedules;
create policy "Admins manage class fee schedules"
  on public.school_fee_schedules
  for all
  using (
    school_id = public.schoolflow_my_school_id()
    and public.schoolflow_my_role() = 'admin'
  )
  with check (
    school_id = public.schoolflow_my_school_id()
    and public.schoolflow_my_role() = 'admin'
    and exists (
      select 1 from public.classes c
      where c.id = school_fee_schedules.class_id
        and c.school_id = school_fee_schedules.school_id
    )
  );

drop policy if exists "Parents read published schedules for linked children" on public.school_fee_schedules;
create policy "Parents read published schedules for linked children"
  on public.school_fee_schedules
  for select
  using (
    is_published = true
    and exists (
      select 1
      from public.students s
      join public.student_guardians g
        on g.student_id = s.id
       and g.school_id = s.school_id
      where s.class_id = school_fee_schedules.class_id
        and s.school_id = school_fee_schedules.school_id
        and s.active = true
        and g.guardian_user_id = auth.uid()
    )
    and not exists (
      select 1 from public.profiles p where p.id = auth.uid()
    )
  );

comment on table public.school_fee_schedules is
  'Class-level fee schedule by academic year and term. Items is a JSON array of {name, amount}. Publishing a schedule does not overwrite existing student payment records.';
