-- Run in the SQL Editor. All test entries are rolled back, never retained.
begin;
do $$
declare
 r jsonb;
 test_id uuid := gen_random_uuid();
 a text[] := array['natural','romantico','natural','romantico','natural','romantico','natural','romantico','clasico'];
begin
 assert not has_table_privilege('anon','public.brunch_entries','select'), 'anonymous read must be denied';
 assert not has_table_privilege('anon','public.brunch_entries','insert'), 'anonymous direct insert must be denied';
 assert not has_table_privilege('authenticated','public.brunch_entries','insert'), 'authenticated direct insert must be denied';
 assert not has_table_privilege('authenticated','public.brunch_entries','delete'), 'authenticated delete must be denied';
 assert not has_function_privilege('anon','public.brunch_submit(uuid,text,text[],text)','execute'), 'anonymous RPC must be denied';
 assert not has_function_privilege('authenticated','public.brunch_submit(uuid,text,text[],text)','execute'), 'authenticated RPC must be denied';
 assert (select relrowsecurity from pg_class where oid='public.brunch_entries'::regclass), 'RLS must be enabled';
 r:=public.brunch_submit(test_id,'Prueba transaccional',a,repeat('a',64));
 assert r->'winners'='["romantico","natural"]'::jsonb, 'two-way tie mismatch';
 assert public.brunch_submit(test_id,'Prueba transaccional',a,repeat('a',64))=r, 'retry must be idempotent';
 assert (select count(*) from public.brunch_entries where id=test_id)=1, 'duplicate entry';
 begin
  perform public.brunch_submit(test_id,'Alterado',a,repeat('a',64));
  raise exception 'test_failed_conflict_accepted';
 exception when others then
  if sqlerrm<>'submission_conflict' then raise; end if;
 end;
 begin
  perform public.brunch_submit(gen_random_uuid(),'Inválida',array['fake'],repeat('a',64));
  raise exception 'test_failed_invalid_accepted';
 exception when others then
  if sqlerrm<>'invalid_submission' then raise; end if;
 end;
 for j in 1..6 loop
  perform public.brunch_submit(gen_random_uuid(),'Prueba de frecuencia',a,repeat('b',64));
 end loop;
 begin
  perform public.brunch_submit(gen_random_uuid(),'Prueba de frecuencia',a,repeat('b',64));
  raise exception 'test_failed_rate_accepted';
 exception when others then
  if sqlerrm<>'rate_limited' then raise; end if;
 end;
end;
$$;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000001","aal":"aal2"}',true);
do $$ begin assert (select count(*) from public.brunch_entries)=0, 'non-admin must see no records'; end; $$;
reset role;
select 'PASS: scoring, ties, retry, validation, rate limits, privileges and RLS' as verification;
rollback;
