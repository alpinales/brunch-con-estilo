begin;
do $$
declare r jsonb; id uuid:=gen_random_uuid(); a text[]; before_count integer;
begin
 assert not has_function_privilege('anon','public.brunch_rank(text[],jsonb)','execute');
 assert not has_function_privilege('anon','public.brunch_submit_v2(uuid,text,text[],text,jsonb)','execute');
 assert not has_function_privilege('authenticated','public.brunch_submit_v2(uuid,text,text[],text,jsonb)','execute');
 a:=array['clasico','clasico','clasico','clasico','clasico','romantico','romantico','dramatico','dramatico'];
 r:=public.brunch_rank(a,'{}');
 assert r->'primary'='["clasico"]'::jsonb;
 assert r->'secondary'='["romantico","dramatico"]'::jsonb;
 assert r->'needsChoice'='null'::jsonb;
 a:=array['clasico','clasico','clasico','romantico','romantico','romantico','dramatico','natural','creativo'];
 r:=public.brunch_rank(a,'{}');
 assert r->'primary'='["clasico","romantico"]'::jsonb;
 assert r->'needsChoice'->>'role'='secondary';
 assert (r->'needsChoice'->>'count')::integer=1;
 begin
  perform public.brunch_submit_v2(id,'Prueba v2',a,repeat('c',64),'{}');
  raise exception 'unresolved_choice_accepted';
 exception when others then if sqlerrm<>'selection_required' then raise;end if;end;
 select count(*) into before_count from public.brunch_entries;
 r:=public.brunch_submit_v2(id,'Prueba v2',a,repeat('c',64),'{"secondary":["natural"]}');
 assert r->'primary'='["clasico","romantico"]'::jsonb;
 assert r->'secondary'='["natural"]'::jsonb;
 assert public.brunch_submit_v2(id,'Prueba v2',a,repeat('c',64),'{"secondary":["natural"]}')=r;
 assert (select count(*) from public.brunch_entries)=before_count+1;
 begin
  perform public.brunch_submit_v2(id,'Prueba v2',a,repeat('c',64),'{"secondary":["creativo"]}');
  raise exception 'modified_selection_accepted';
 exception when others then if sqlerrm<>'submission_conflict' then raise;end if;end;
 begin
  perform public.brunch_rank(a,'{"secondary":["clasico"]}');
  raise exception 'invalid_choice_accepted';
 exception when others then if sqlerrm<>'invalid_selection' then raise;end if;end;
 a:=array['clasico','clasico','romantico','romantico','dramatico','dramatico','natural','natural','creativo'];
 r:=public.brunch_rank(a,'{"primary":["natural","clasico","romantico"]}');
 assert r->'primary'='["clasico","romantico","natural"]'::jsonb;
 assert r->'secondary'='[]'::jsonb;
 r:=public.brunch_rank(array_fill('natural'::text,array[9]),'{}');
 assert r->'primary'='["natural"]'::jsonb;
 assert r->'secondary'='[]'::jsonb;
end;
$$;
select 'PASS: primary, secondary, participant tie choice, max 3, retry and privileges' as verification;
rollback;
