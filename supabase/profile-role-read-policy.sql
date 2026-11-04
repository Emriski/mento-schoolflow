-- Ensure an authenticated account can always read its own staff role.
-- Portal role checks depend on this row being visible; without it, PostgREST
-- can return no profile and a staff account may be mistaken for an unregistered user.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Users can read their own role profile'
  ) then
    create policy "Users can read their own role profile"
      on public.profiles
      for select
      to authenticated
      using (id = (select auth.uid()));
  end if;
end
$$;
