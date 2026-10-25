begin;
alter table public.brunch_entries
 add column if not exists primary_styles text[] not null default '{}',
 add column if not exists secondary_styles text[] not null default '{}',
 add column if not exists tie_selection jsonb not null default '{}'::jsonb,
 add column if not exists result_version integer not null default 1;

create or replace function public.brunch_rank(p_answers text[],p_selection jsonb default '{}'::jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare
 ids text[]:=array['clasico','romantico','dramatico','natural','creativo','seductor','elegante'];
 counts integer[]:=array[0,0,0,0,0,0,0];
 primary_ids text[]:='{}'; secondary_ids text[]:='{}'; candidates text[]:='{}'; chosen text[]:='{}';
 scores jsonb:='{}'; choice jsonb:='null'; role_name text; needed integer;
 a text; j integer; top_score integer; second_score integer:=0;
begin
 if cardinality(p_answers) is distinct from 9 or exists(select 1 from unnest(p_answers) v where v is null or not(v=any(ids))) then raise exception 'invalid_submission'; end if;
 if p_selection is null or jsonb_typeof(p_selection)<>'object' then raise exception 'invalid_selection'; end if;
 if exists(select 1 from jsonb_object_keys(p_selection) k where k not in ('primary','secondary')) then raise exception 'invalid_selection'; end if;
 for j in 1..2 loop
  role_name:=case when j=1 then 'primary' else 'secondary' end;
  if p_selection ? role_name and jsonb_typeof(p_selection->role_name)<>'array' then raise exception 'invalid_selection'; end if;
 end loop;
 foreach a in array p_answers loop j:=array_position(ids,a);counts[j]:=counts[j]+1;end loop;
 select max(v) into top_score from unnest(counts) v;
 for j in 1..7 loop
  scores:=scores||jsonb_build_object(ids[j],counts[j]);
  if counts[j]=top_score then primary_ids:=array_append(primary_ids,ids[j]);
  elsif counts[j]>second_score then second_score:=counts[j];end if;
 end loop;
 if cardinality(primary_ids)>3 then
  role_name:='primary';candidates:=primary_ids;needed:=3;primary_ids:='{}';
 elsif cardinality(primary_ids)<3 and second_score>0 then
  for j in 1..7 loop if counts[j]=second_score then secondary_ids:=array_append(secondary_ids,ids[j]);end if;end loop;
  if cardinality(secondary_ids)>3-cardinality(primary_ids) then
   role_name:='secondary';candidates:=secondary_ids;needed:=3-cardinality(primary_ids);secondary_ids:='{}';
  end if;
 end if;
 if cardinality(candidates)>0 then
  select coalesce(array_agg(value),'{}') into chosen from jsonb_array_elements_text(coalesce(p_selection->role_name,'[]'));
  if cardinality(chosen)=0 then choice:=jsonb_build_object('role',role_name,'candidates',candidates,'count',needed);
  else
   if cardinality(chosen)<>needed or (select count(distinct v) from unnest(chosen) v)<>needed or exists(select 1 from unnest(chosen) v where v is null or not(v=any(candidates))) then raise exception 'invalid_selection'; end if;
   if exists(select 1 from jsonb_object_keys(p_selection) k where k<>role_name and jsonb_array_length(p_selection->k)>0) then raise exception 'invalid_selection'; end if;
   if role_name='primary' then select array_agg(v order by ord) into primary_ids from unnest(ids) with ordinality t(v,ord) where v=any(chosen);
   else select array_agg(v order by ord) into secondary_ids from unnest(ids) with ordinality t(v,ord) where v=any(chosen);end if;
  end if;
 elsif exists(select 1 from jsonb_object_keys(p_selection) k where jsonb_array_length(p_selection->k)>0) then raise exception 'invalid_selection';
 end if;
 return jsonb_build_object('primary',primary_ids,'secondary',secondary_ids,'needsChoice',choice,'scores',scores);
end;
$$;
revoke all on function public.brunch_rank(text[],jsonb) from public,anon,authenticated;
grant execute on function public.brunch_rank(text[],jsonb) to service_role;

create or replace function public.brunch_submit_v2(p_id uuid,p_name text,p_answers text[],p_bucket text,p_selection jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare ranked jsonb; stored public.brunch_entries%rowtype; legacy jsonb;
begin
 ranked:=public.brunch_rank(p_answers,p_selection);
 if ranked->'needsChoice'<>'null'::jsonb then raise exception 'selection_required';end if;
 legacy:=public.brunch_submit(p_id,p_name,p_answers,p_bucket);
 select * into stored from public.brunch_entries where id=p_id;
 if stored.result_version>=2 and stored.tie_selection<>p_selection then raise exception 'submission_conflict';end if;
 update public.brunch_entries set
  primary_styles=array(select jsonb_array_elements_text(ranked->'primary')),
  secondary_styles=array(select jsonb_array_elements_text(ranked->'secondary')),
  tie_selection=p_selection,result_version=2 where id=p_id;
 return legacy||jsonb_build_object('primary',ranked->'primary','secondary',ranked->'secondary','resultVersion',2);
end;
$$;
revoke all on function public.brunch_submit_v2(uuid,text,text[],text,jsonb) from public,anon,authenticated;
grant execute on function public.brunch_submit_v2(uuid,text,text[],text,jsonb) to service_role;

-- Add derived roles to previous entries when no participant choice is needed.
-- Original answers, scores, winners and timestamps are retained.
update public.brunch_entries e set
 primary_styles=array(select jsonb_array_elements_text(r.ranked->'primary')),
 secondary_styles=array(select jsonb_array_elements_text(r.ranked->'secondary'))
from (select id,public.brunch_rank(answers,'{}') as ranked from public.brunch_entries where result_version=1) r
where e.id=r.id and r.ranked->'needsChoice'='null'::jsonb;
commit;
