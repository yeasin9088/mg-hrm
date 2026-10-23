import assert from 'node:assert/strict';
import test from 'node:test';
import {privatePayload} from '../supabase/functions/web-push-sender/worker.mjs';

test('Phase 4 grouped digest uses original inbox and never exposes HR details on device', () => {
 const notification={
   id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
   category:'System', entity_type:'digest',entity_id:'42',
   title:'SENSITIVE SALARY DETAILS',message:'Employee salary and disciplinary notes',
   priority:'Normal',action_route:'notifications',
 };
 const payload=JSON.parse(privatePayload(notification,{
   enabled:true,todo_note:'CONFIDENTIAL PAYROLL CONTENT',todo_id:33,
 }));
 assert.equal(payload.title,'MG-HRM · Work Digest');
 assert.match(payload.body,/scheduled work summary/i);
 assert.equal(payload.action_route,'notifications');
 assert.equal(payload.entity_type,null);
 assert.equal(payload.entity_id,null);
 assert.ok(!JSON.stringify(payload).includes('SENSITIVE SALARY'));
 assert.ok(!JSON.stringify(payload).includes('CONFIDENTIAL PAYROLL'));
 assert.ok(!JSON.stringify(payload).includes('disciplinary notes'));
});
test('Phase 4 existing normal To-Do private preview stays functional',()=>{
 const payload=JSON.parse(privatePayload({
   id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',category:'ToDo',
   entity_type:'todo',entity_id:'33',priority:'Normal'
 },{enabled:true,todo_note:'General reminder',todo_id:33}));
 assert.equal(payload.action_route,'todo');
 assert.equal(payload.body,'General reminder');
});
