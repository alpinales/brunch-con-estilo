// No third-party runtime imports. Secrets are provided by Supabase, never the browser.
const ids = ['clasico','romantico','dramatico','natural','creativo','seductor','elegante'];
const origins = new Set(['https://alpinales.github.io', 'http://127.0.0.1:4173', 'http://localhost:4173']);
const headers = (origin: string) => ({
 'Access-Control-Allow-Origin': origin,
 'Access-Control-Allow-Headers': 'apikey, content-type',
 'Access-Control-Allow-Methods': 'POST, OPTIONS',
 'Vary': 'Origin', 'Content-Type': 'application/json',
 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
});
Deno.serve(async (req: Request) => {
 const origin=req.headers.get('origin') || '';
 const reply=(status:number,body:object)=>new Response(JSON.stringify(body),{status,headers:headers(origins.has(origin)?origin:'https://alpinales.github.io')});
 if(!origins.has(origin)) return reply(403,{error:'origin_not_allowed'});
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers:headers(origin)});
 if(req.method!=='POST')return reply(405,{error:'method_not_allowed'});
 if(!req.headers.get('content-type')?.startsWith('application/json'))return reply(415,{error:'json_required'});
 const declared=Number(req.headers.get('content-length')||'0');
 if(declared>4096)return reply(413,{error:'body_too_large'});
 try {
  // Bound the body while reading; Content-Length alone can be missing or false.
  const reader=req.body?.getReader();if(!reader)return reply(400,{error:'empty_body'});
  const chunks:Uint8Array[]=[];let size=0;
  for(;;){const {value,done}=await reader.read();if(done)break;size+=value.byteLength;if(size>4096){await reader.cancel();return reply(413,{error:'body_too_large'});}chunks.push(value);}
  const raw=new Uint8Array(size);let offset=0;for(const chunk of chunks){raw.set(chunk,offset);offset+=chunk.byteLength;}
  const body=JSON.parse(new TextDecoder().decode(raw));
  if(!body || typeof body!=='object' || Array.isArray(body))return reply(400,{error:'invalid_submission'});
  const name=typeof body.name==='string'?body.name.normalize('NFKC').trim().replace(/\s+/g,' '):'';
  if(typeof body.id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(body.id)||name.length<2||name.length>100||/[\u0000-\u001f\u007f<>]/u.test(name)||body.consent!==true||body.website!==''||!Array.isArray(body.answers)||body.answers.length!==9||body.answers.some((a:unknown)=>typeof a!=='string'||!ids.includes(a)))return reply(400,{error:'invalid_submission'});
  const secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const url=Deno.env.get('SUPABASE_URL');
  if(!secret||!url)return reply(503,{error:'unavailable'});
  // Use the platform-forwarded address, never an IP supplied in the form.
  const ip=(req.headers.get('x-forwarded-for')||'unknown').split(',')[0].trim();
  const day=new Date().toISOString().slice(0,10);
  const hash=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(`${secret}|${day}|${ip}`));
  const bucket=Array.from(new Uint8Array(hash),n=>n.toString(16).padStart(2,'0')).join('');
  const isV2=body.resultVersion===2;
  const selection=body.selection??{};
  if(isV2&&(typeof selection!=='object'||selection===null||Array.isArray(selection)||Object.keys(selection).some(key=>!['primary','secondary'].includes(key))||Object.values(selection).some(value=>!Array.isArray(value)||value.length>3||value.some((id:unknown)=>typeof id!=='string'||!ids.includes(id)))))return reply(400,{error:'invalid_selection'});
  const db=await fetch(`${url}/rest/v1/rpc/${isV2?'brunch_submit_v2':'brunch_submit'}`,{method:'POST',headers:{apikey:secret,Authorization:`Bearer ${secret}`,'Content-Type':'application/json'},body:JSON.stringify({p_id:body.id,p_name:name,p_answers:body.answers,p_bucket:bucket,...(isV2?{p_selection:selection}:{})}),signal:AbortSignal.timeout(10000)});
  if(!db.ok){const error=await db.json().catch(()=>({}));return reply(error.message==='rate_limited'?429:error.message==='submission_conflict'?409:['invalid_selection','selection_required'].includes(error.message)?400:503,{error:error.message==='rate_limited'?'rate_limited':'submission_unavailable'});}
  return reply(200,await db.json());
 }catch{return reply(400,{error:'invalid_or_unavailable'});}
});
