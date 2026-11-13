-- SchoolFlow ownership governance.
-- Apply only after finance foundation; test in an isolated staging database first.

begin;

create table if not exists public.school_ownership_history (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  owner_user_id uuid not null,
  is_current boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  approved_by uuid not null,
  transfer_reason text,
  created_at timestamptz not null default now(),
  constraint school_ownership_owner_school_fk
    foreign key (owner_user_id, school_id) references public.profiles(id, school_id),
  constraint school_ownership_approver_school_fk
    foreign key (approved_by, school_id) references public.profiles(id, school_id),
  constraint school_ownership_dates_check check (
    (is_current and effective_to is null)
    or (not is_current and effective_to is not null)
  )
);

create unique index if not exists school_ownership_one_current_owner_uidx
  on public.school_ownership_history(school_id) where is_current;

-- School setup creates the school row first, then its first admin profile in
-- the same transaction. Seed ownership when that matching creator profile
-- arrives; this also covers a creator profile restored after migration.
create or replace function public.schoolflow_seed_school_owner_on_profile_insert()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $
begin
  if new.role = 'admin' and exists (
    select 1 from public.schools s
    where s.id = new.school_id and s.created_by = new.id
  ) then
    insert into public.school_ownership_history
      (school_id, owner_user_id, is_current, approved_by, transfer_reason)
    values
      (new.school_id, new.id, true, new.id, 'Initial owner seeded during school setup')
    on conflict do nothing;
  end if;
  return new;
end;
$;

drop trigger if exists schoolflow_seed_school_owner_after_profile_insert on public.profiles;
create trigger schoolflow_seed_school_owner_after_profile_insert
after insert on public.profiles
for each row execute function public.schoolflow_seed_school_owner_on_profile_insert();
create index if not exists school_ownership_history_school_idx
  on public.school_ownership_history(school_id, effective_from desc);

-- Seed the current schools from their existing creator, but only where the
-- creator is still a profile in that same school. Do not silently guess otherwise.
insert into public.school_ownership_history
  (school_id, owner_user_id, is_current, approved_by, transfer_reason)
select s.id, s.created_by, true, s.created_by, 'Initial owner migrated from school creator'
from public.schools s
join public.profiles p on p.id=s.created_by and p.school_id=s.id
where not exists (
  select 1 from public.school_ownership_history oh
  where oh.school_id=s.id and oh.is_current
)
on conflict do nothing;

create or replace function private.schoolflow_is_finance_owner(p_school_id uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.school_ownership_history oh
    where oh.school_id=p_school_id
      and oh.owner_user_id=auth.uid()
      and oh.is_current
      and oh.effective_to is null
  );
$$;

create or replace function public.schoolflow_transfer_school_ownership(
  p_school_id uuid,
  p_new_owner_user_id uuid,
  p_reason text
) returns uuid
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_new_owner_history_id uuid;
  v_old_owner_id uuid;
  v_new_owner_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if length(trim(coalesce(p_reason,''))) < 10 then
    raise exception 'A transfer reason of at least 10 characters is required';
  end if;
  if p_new_owner_user_id is null or p_new_owner_user_id=auth.uid() then
    raise exception 'Choose a different, valid new owner';
  end if;

  -- Serialize transfers for this school and confirm the caller owns it now.
  perform 1 from public.schools where id=p_school_id for update;
  if not found then raise exception 'School not found'; end if;
  if not private.schoolflow_is_finance_owner(p_school_id) then
    raise exception 'Only the current school owner can transfer ownership';
  end if;

  select owner_user_id into v_old_owner_id
  from public.school_ownership_history
  where school_id=p_school_id and is_current and effective_to is null
  for update;

  if not found then raise exception 'Current ownership record is missing'; end if;

  select p.id into v_new_owner_id
  from public.profiles p
  where p.id=p_new_owner_user_id
    and p.school_id=p_school_id
    and p.role='admin';

  if v_new_owner_id is null then
    raise exception 'New owner must be an existing administrator of this school';
  end if;

  update public.school_ownership_history
  set is_current=false, effective_to=now()
  where school_id=p_school_id and is_current;

  insert into public.school_ownership_history
    (school_id, owner_user_id, is_current, effective_from, approved_by, transfer_reason)
  values
    (p_school_id, v_new_owner_id, true, now(), auth.uid(), trim(p_reason))
  returning id into v_new_owner_history_id;

  insert into public.school_finance_audit_log
    (school_id, actor_user_id, action, entity_type, entity_id, details, reason)
  values
    (p_school_id, auth.uid(), 'school.ownership_transferred', 'school_ownership',
     v_new_owner_history_id,
     jsonb_build_object('previous_owner_user_id',v_old_owner_id,
                        'new_owner_user_id',p_new_owner_user_id),
     trim(p_reason));

  return p_new_owner_user_id;
end;
$$;

alter table public.school_ownership_history enable row level security;
create policy school_ownership_history_owner_read
  on public.school_ownership_history for select to authenticated
  using (private.schoolflow_is_finance_owner(school_id));

revoke all on public.school_ownership_history from anon, authenticated;
grant select on public.school_ownership_history to authenticated;
revoke all on function public.schoolflow_transfer_school_ownership(uuid,uuid,text)
  from public, anon;
revoke all on function public.schoolflow_seed_school_owner_on_profile_insert()
  from public, anon, authenticated;
grant execute on function public.schoolflow_transfer_school_ownership(uuid,uuid,text)
  to authenticated;

commit;
