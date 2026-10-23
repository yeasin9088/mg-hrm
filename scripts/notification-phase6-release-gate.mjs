// Run `node scripts/notification-phase6-release-gate.mjs [--assert-ready]`
// Refuses to authorize live activation without independently recorded evidence.
// It NEVER connects to or writes the production database.
import fs from 'node:fs';
const ledger=JSON.parse(fs.readFileSync('docs/notifications/rulebook-acceptance-catalogue.json','utf8'));
const snapshot=JSON.parse(fs.readFileSync('docs/notifications/phase6-production-checkpoint.json','utf8'));
const rows=ledger.scenarios;
const ids=rows.map(x=>x.id);
const unique=new Set(ids);
if(rows.length!==69||unique.size!==69||Array.from({length:69},(_,i)=>'AT-'+String(i+1).padStart(3,'0')).some(x=>!unique.has(x)))throw Error('Rulebook AT inventory corrupted; expected 69 unique acceptance IDs.');
const states=new Set(['PASS_SYNTHETIC','PARTIAL','BLOCKED','ACCEPTED']);
if(rows.some(x=>!states.has(x.acceptance_status)))throw Error('Unknown acceptance status');
const blocked=rows.filter(x=>x.acceptance_status==='BLOCKED').length;
const partial=rows.filter(x=>x.acceptance_status==='PARTIAL').length;
const synthetic=rows.filter(x=>x.acceptance_status==='PASS_SYNTHETIC').length;
const required=[
 'phase3_4_5_migrations_applied','staging_policy_readback_verified',
 'source_adapters_complete','atomic_push_rate_cap_enforced',
 'all_rulebook_acceptance_proven',
 'operator_end_to_end_android_push_proven','operator_end_to_end_desktop_push_proven',
 'service_worker_click_on_real_devices_proven','cron_recovery_live_proven',
 'concurrent_worker_provider_quota_proven',
 'owner_final_release_approval','phase6_responsive_ux_verified'
];
const unverified=required.filter(x=>snapshot[x]!==true);
if(blocked||partial)unverified.push(partial+' Rulebook scenarios remain Partial; '+blocked+' remain Blocked');
if(snapshot.governance_enabled||snapshot.digest_bridge_enabled)
 unverified.push('Production V2 is already enabled; manual incident review required');
const ready=unverified.length===0;
const output={release_id:snapshot.release_id,status:ready?'READY':'NOT_READY',
 rulebook_scenarios:rows.length,synthetic_pass_scenarios:synthetic,partial_scenarios:partial,blocked_scenarios:blocked,
 production_flags:{governance:snapshot.governance_enabled,bridge:snapshot.digest_bridge_enabled},
 unverified,verified_at:snapshot.evidence_snapshot_date};
console.log(JSON.stringify(output,null,2));
if(process.argv.includes('--assert-ready')&&!ready)process.exitCode=1;
