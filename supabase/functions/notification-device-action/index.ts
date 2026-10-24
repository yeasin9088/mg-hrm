import {createClient} from 'npm:@supabase/supabase-js@2.57.4';
const headers={'Content-Type':'application/json','Cache-Control':'no-store','Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'content-type','Access-Control-Allow-Methods':'POST,OPTIONS'};
// This endpoint authenticates a 256-bit, notification-scoped, expiring capability.
// No JWT, subscription credentials, source ID or user ID is accepted from callers.
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response(null,{headers});
 if(req.method!=='POST')return new Response(null,{status:405,headers});
 try{
  if(Number(req.headers.get('content-length')||0)>1024)return new Response(null,{status:413,headers});
  const body=await req.text();if(body.length>1024)return new Response(null,{status:413,headers});
  const {token,action}=JSON.parse(body);
  if(!/^[0-9a-f]{64}$/.test(String(token||''))||!['read','remind','complete'].includes(action))return new Response(null,{status:400,headers});
  const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data,error}=await client.rpc('notification_device_action',{p_token:token,p_action:action});
  if(error||data?.ok!==true)return new Response(JSON.stringify({ok:false}),{status:403,headers});
  return new Response(JSON.stringify({ok:true}),{headers});
 }catch{return new Response(JSON.stringify({ok:false}),{status:400,headers});}
});
