import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import webpush from 'npm:web-push@3.6.7';
import {runSender} from './worker.mjs';

function required(name: string): string {
  const value=Deno.env.get(name)?.trim();
  if(!value) throw Error('Missing server configuration');
  return value;
}
function sameToken(left: string, right: string): boolean {
  // Compare every byte without early exits on matching-length secret tokens.
  const a=new TextEncoder().encode(left), b=new TextEncoder().encode(right);
  if(a.length!==b.length) return false;
  let diff=0; for(let i=0;i<a.length;i++) diff|=a[i]^b[i];
  return diff===0;
}
const headers={'Content-Type':'application/json','Cache-Control':'no-store'};
Deno.serve(async(req: Request)=>{
  if(req.method!=='POST') return new Response(null,{status:405});
  try {
    if(!sameToken(req.headers.get('x-web-push-sender-token')?.trim()||'',required('WEB_PUSH_SENDER_TOKEN')))
      return new Response(null,{status:401});
    webpush.setVapidDetails(required('WEB_PUSH_VAPID_SUBJECT'),required('WEB_PUSH_VAPID_PUBLIC_KEY'),required('WEB_PUSH_VAPID_PRIVATE_KEY'));
    const admin=createClient(required('SUPABASE_URL'),required('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
    if(new URL(req.url).searchParams.get('health')==='1') {
      const {data,error}=await admin.rpc('notification_reminder_mode');
      return new Response(JSON.stringify({configured:!error,serverReminders:!!data}),{status:error?503:200,headers});
    }
    const result=await runSender({rpc:admin.rpc.bind(admin),send:webpush.sendNotification.bind(webpush),workerId:`web-push-sender:${crypto.randomUUID()}`});
    console.log(JSON.stringify({component:'web-push-sender',...result}));
    return new Response(JSON.stringify(result),{status:result.jobErrors?503:200,headers});
  } catch {
    console.error('Web Push sender unavailable; inspect server configuration and queue health');
    return new Response(JSON.stringify({error:'Sender unavailable'}),{status:503,headers});
  }
});
