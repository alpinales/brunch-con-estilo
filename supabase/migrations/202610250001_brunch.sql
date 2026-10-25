begin;
create schema if not exists brunch_private;
revoke all on schema brunch_private from public, anon, authenticated;

create table if not exists brunch_private.admins (
 user_id uuid primary key references auth.users(id) on delete cascade
);
alter table brunch_private.admins enable row level security;
create table if not exists brunch_private.rate_limits (
 bucket text not null,
 window_start timestamptz not null,
 requests integer not null default 1,
 primary key(bucket,window_start)
);
alter table brunch_private.rate_limits enable row level security;

create table if not exists public.brunch_entries (
 id uuid primary key,
 name text not null check (char_length(name) between 2 and 100),
 answers text[] not null check (cardinality(answers)=9),
 scores jsonb not null,
 winners text[] not null,
 consent_version text not null default '2026-10-25-v1',
 created_at timestamptz not null default now()
);
alter table public.brunch_entries enable row level security;
revoke all on public.brunch_entries from public,anon,authenticated;
grant select on public.brunch_entries to authenticated;
grant all on public.brunch_entries to service_role;

create or replace function public.brunch_is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
 select coalesce((auth.jwt()->>'aal')='aal2',false)
 and exists (select 1 from brunch_private.admins where user_id=(select auth.uid()));
$$;
revoke all on function public.brunch_is_admin() from public,anon;
grant execute on function public.brunch_is_admin() to authenticated;
create policy brunch_admin_read on public.brunch_entries for select to authenticated
 using ((select public.brunch_is_admin()));

create or replace function public.brunch_submit(p_id uuid,p_name text,p_answers text[],p_bucket text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 ids text[] := array['clasico','romantico','dramatico','natural','creativo','seductor','elegante'];
 counts integer[] := array[0,0,0,0,0,0,0];
 result_scores jsonb := '{}'::jsonb;
 result_winners text[] := '{}';
 prior public.brunch_entries%rowtype;
 n integer; j integer; top_score integer; request_count integer;
 clean_name text := btrim(regexp_replace(p_name,'\s+',' ','g'));
begin
 if p_id is null or clean_name is null or char_length(clean_name) not between 2 and 100
 or clean_name ~ '[[:cntrl:]<>]' or cardinality(p_answers) is distinct from 9
 or exists(select 1 from unnest(p_answers) a where a is null or not (a=any(ids)))
 or p_bucket is null or p_bucket !~ '^[a-f0-9]{64}$'
 then raise exception 'invalid_submission'; end if;

 -- A transaction-level lock makes retries with the same ID atomic.
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
 select * into prior from public.brunch_entries where id=p_id;
 if found then
   if prior.name<>clean_name or prior.answers<>p_answers then raise exception 'submission_conflict'; end if;
   return jsonb_build_object('ok',true,'winners',prior.winners);
 end if;
 -- Serialize only the small rate counter operation, not requests on the network.
 perform pg_advisory_xact_lock(73120261031);
 for j in 1..2 loop
  insert into brunch_private.rate_limits(bucket,window_start)
    values(p_bucket||':'||j,case when j=1 then date_trunc('minute',now()) else date_trunc('hour',now()) end)
  on conflict(bucket,window_start) do update set requests=brunch_private.rate_limits.requests+1
  returning requests into request_count;
  if request_count > (case when j=1 then 6 else 60 end) then raise exception 'rate_limited'; end if;
 end loop;
 insert into brunch_private.rate_limits(bucket,window_start) values('global',date_trunc('hour',now()))
 on conflict(bucket,window_start) do update set requests=brunch_private.rate_limits.requests+1
 returning requests into request_count;
 if request_count>1000 then raise exception 'rate_limited'; end if;

 foreach n in array array[1,2,3,4,5,6,7,8,9] loop
  j:=array_position(ids,p_answers[n]); counts[j]:=counts[j]+1;
 end loop;
 select max(v) into top_score from unnest(counts) v;
 for j in 1..7 loop
  result_scores:=result_scores||jsonb_build_object(ids[j],counts[j]);
  if counts[j]=top_score then result_winners:=array_append(result_winners,ids[j]); end if;
 end loop;
 insert into public.brunch_entries(id,name,answers,scores,winners)
 values(p_id,clean_name,p_answers,result_scores,result_winners);
 return jsonb_build_object('ok',true,'winners',result_winners);
end;
$$;
revoke all on function public.brunch_submit(uuid,text,text[],text) from public,anon,authenticated;
grant execute on function public.brunch_submit(uuid,text,text[],text) to service_role;
commit;
