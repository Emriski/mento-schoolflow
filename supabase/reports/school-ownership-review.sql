-- SchoolFlow ownership review report.
-- Run only in an isolated test database after the ownership migration.
-- This is read-only. Review every row before deciding how to remediate it.

select
  s.id as school_id,
  s.name as school_name,
  s.created_by as original_creator_user_id,
  creator.id as matching_creator_profile_id,
  creator.role as creator_role,
  owner.owner_user_id as current_owner_user_id,
  owner_profile.full_name as current_owner_name,
  case
    when owner.id is not null then 'owned'
    when creator.id is null then 'creator_profile_missing_or_school_mismatch'
    else 'ownership_seed_missing'
  end as ownership_review_status
from public.schools s
left join public.profiles creator
  on creator.id = s.created_by
 and creator.school_id = s.id
left join public.school_ownership_history owner
  on owner.school_id = s.id
 and owner.is_current
 and owner.effective_to is null
left join public.profiles owner_profile
  on owner_profile.id = owner.owner_user_id
 and owner_profile.school_id = owner.school_id
order by s.name, s.id;
