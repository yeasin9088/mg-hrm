// Existing service-only claim/dispatch/result/finalize contracts remain authoritative.
// Never log provider errors: they can contain endpoints, headers or encryption material.
export function retryAfter(attempt, random = Math.random) {
  return `${Math.min(3600, 60 * 2 ** Math.max(0, Math.min(6, attempt - 1)) + Math.floor(random() * 30))} seconds`;
}
const GENERIC = 'You have a new notification. Open MG-HRM to review it.';
const categories = {
  recruitment:['Recruitment Update','A recruitment update is ready for review.'],
  transfer:['Transfer Update','A transfer update is ready for review.'],
  leave:['Leave Update','A leave request or decision is ready for review.'],
  exit:['Exit Update','An exit workflow update is ready for review.'],
  disciplinary:['Disciplinary Update','A confidential disciplinary update is ready for review.'],
  uniform:['Uniform Update','A uniform management update is ready for review.'],
  meeting:['Meeting Update','A meeting update is ready for review.']
};
function clean(value, limit) {
  if(typeof value !== 'string') return '';
  const plain=value.replace(/<[^>]*>/g,' ').replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e]/g,' ')
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi,'[contact hidden]')
    .replace(/(?:https?:\/\/|www\.)\S+/gi,'[link hidden]')
    .replace(/(?:\+?\d[\d\s().-]{8,}\d)/g,'[contact hidden]')
    .replace(/\b(?:password|api[_ -]?key|secret|token)\s*[:=]\s*\S+/gi,'[private detail hidden]')
    .replace(/\s+/gu,' ').trim();
  const chars=typeof Intl.Segmenter==='function'
    ? Array.from(new Intl.Segmenter(undefined,{granularity:'grapheme'}).segment(plain),part=>part.segment)
    : Array.from(plain);
  return chars.length>limit ? chars.slice(0,limit-1).join('').trimEnd()+'…' : plain;
}
export function privatePayload(n, preview = {}) {
  const category=String(n.category||'').toLowerCase();
  const enabled=preview.enabled===true;
  let title='MG-HRM', body=GENERIC, route='notifications', entityId=null;
  if(n.entity_type==='device_test' && category==='system') {
    title='MG-HRM · Device push test';
    body='Device notifications and content preview are working.';
  } else if(enabled && category==='todo' && preview.todo_id != null) {
    const note=clean(preview.todo_note,180);
    if(note) { title='MG-HRM · To-Do Reminder'; body=note; route='todo'; entityId=String(preview.todo_id); }
  } else if(n.entity_type==='digest' && category==='system') {
    // Safe summary content only. The private snapshot and HR details never
    // leave Postgres; clicking opens the EXISTING Notification Center.
    title='MG-HRM · Work Digest';
    body='Your scheduled work summary is ready. Open MG-HRM to review pending actions.';
    route='notifications';
  } else if(enabled && category==='transfer' && n.entity_type==='transfer' &&
      n.action_label==='Review Transfer' && /^\d{1,18}$/.test(String(n.entity_id||''))) {
    // Only this explicitly authorized, non-sensitive order identifier is visible on devices.
    // Never expose employee names, projects, notes, or reasons in Web Push previews.
    title='MG-HRM · Transfer Joining Due';
    body='Transfer order #'+String(n.entity_id)+' needs Joined / Not Joined confirmation.';
    route='transfer';
  } else if(enabled && categories[category]) {
    title='MG-HRM · '+categories[category][0];body=categories[category][1];
    route=['recruitment','transfer','leave','disciplinary','uniform','meeting'].includes(category)?category:'notifications';
  }
  return JSON.stringify({notification_id:n.id,title,body,action_route:route,
    priority:n.priority||'Normal',entity_type:entityId?'todo':null,entity_id:entityId,
    ...(/^[0-9a-f]{64}$/.test(preview.action_token||'')?{action_token:preview.action_token,task_actions:true}:{})});
}
export async function runSender({rpc, send, workerId, batchSize = 5, now = Date.now, random = Math.random}) {
  const call = async (name, params) => { const {data,error} = await rpc(name,params); if(error) throw Error('RPC_FAILURE'); return data; };
  const jobs = await call('notification_claim_web_push_jobs',{p_worker_id:workerId,p_batch_size:Math.max(1,Math.min(5,Math.floor(batchSize)||2))});
  const summary = {claimed:jobs.length, finalized:0, providerAccepted:0, failed:0, revoked:0, jobErrors:0};
  const deadline = now()+45000;
  for (const job of jobs) {
    const identity = {p_job_id:job.id,p_worker_id:workerId};
    const retry = retryAfter(job.attempt_count,random);
    try {
      const dispatch = await call('notification_get_web_push_dispatch',identity);
      if(dispatch.deferred) continue;
      // One authorized content lookup per notification, never once per subscription.
      const preview = (dispatch.deliveries||[]).length ? await call('notification_web_push_preview',identity) : {};
      const payload=privatePayload(dispatch.notification,preview);
      const queue = [...(dispatch.deliveries||[])];
      let exceeded = false, deferred = false;
      await Promise.all(Array.from({length:Math.min(4,queue.length)},async()=>{
        while(queue.length) {
          if(now()>deadline) { exceeded=true; return; }
          const delivery = queue.shift();
          // Recheck source/presence before each network send, not only once per large batch.
          const fresh = await call('notification_get_web_push_dispatch',identity);
          if(fresh.deferred) {deferred=true;queue.length=0;return;}
          if(!(fresh.deliveries||[]).some(d=>String(d.delivery_id)===String(delivery.delivery_id))) continue;
          let status=null, accepted=false;
          try {
            const result = await send({endpoint:delivery.endpoint,keys:delivery.keys},payload,
              {TTL:dispatch.notification.category==='ToDo'?1800:86400,urgency:dispatch.notification.priority==='Urgent'?'high':'normal',timeout:8000});
            status=Number(result.statusCode); accepted=status>=200&&status<300;
          } catch(error) { const code=Number(error?.statusCode); status=Number.isInteger(code)&&code>=100&&code<=599?code:null; }
          const revoke=status===404||status===410;
          await call('notification_record_web_push_result',{...identity,p_delivery_id:delivery.delivery_id,
            p_success:accepted,p_provider_status:status===null?null:String(status),p_provider_message_id:null,
            p_error_code:accepted?null:status?`HTTP_${status}`:'PUSH_TRANSPORT_ERROR',
            p_error_message:accepted?null:'Push provider did not accept this attempt',
            p_response_metadata:{http_status:status},p_revoke_subscription:revoke});
          if(accepted) summary.providerAccepted++; else summary.failed++;
          if(revoke) summary.revoked++;
        }
      }));
      if(deferred) continue;
      if(exceeded) throw Error('BATCH_TIME_BUDGET');
      await call('notification_finalize_web_push_job',{...identity,p_retry_after:retry});
      summary.finalized++;
    } catch {
      summary.jobErrors++;
      // A bounded generic diagnostic, never an interpolated provider/database error.
      try { await call('notification_fail_job',{...identity,p_error:'Web Push batch incomplete; retry eligible devices',p_retry_after:retry}); }
      catch { /* A source cancellation/defer may already have released ownership. Stale-lock recovery handles uncertain writes. */ }
    }
  }
  return summary;
}
