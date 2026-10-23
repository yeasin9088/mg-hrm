/* Confidential payloads are fetched on demand only: never DATA, localStorage, or logs. */
(function(g){
 'use strict';
 async function rpc(name,args){
  if(!g.sb)throw Error('Database connection is unavailable.');
  const r=await g.sb.rpc(name,args);if(r.error)throw Error(r.error.message||'Server save failed.');return r.data;
 }
 g.ExitService=Object.freeze({
  archive:id=>rpc('archive_exit_record',{p_exit_id:Number(id)}),
  submit:(payload,settlement,requestId)=>rpc('submit_exit_settlement',{p_exit:payload,p_settlement:settlement,p_request_id:requestId}),
  save:(id,data,version,note)=>rpc('save_exit_settlement',{p_exit_id:Number(id),p_data:data,p_version:version,p_change_note:note}),
  report:(from,to,id=null)=>rpc('get_exit_settlement_report',{p_from:from,p_to:to,p_exit_id:id==null?null:Number(id)}),
  history:id=>rpc('get_exit_settlement_history',{p_exit_id:Number(id)})
 });
})(window);
