// Existing service-only claim/dispatch/result/finalize contracts remain authoritative.
// Never log provider errors: they can contain endpoints, headers or encryption material.
export function retryAfter(attempt, random = Math.random) {
  return `${Math.min(3600, 60 * 2 ** Math.max(0, Math.min(6, attempt - 1)) + Math.floor(random() * 30))} seconds`;
}
export function privatePayload(n) {
  return JSON.stringify({notification_id:n.id, title:'MG-HRM',
    body:'You have a new notification. Open MG-HRM to review it.',
    action_route:'notifications', priority:n.priority||'Normal', entity_type:null, entity_id:null});
}
export async function runSender({rpc, send, workerId, batchSize = 2, now = Date.now, random = Math.random}) {
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
            const result = await send({endpoint:delivery.endpoint,keys:delivery.keys},privatePayload(dispatch.notification),
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
