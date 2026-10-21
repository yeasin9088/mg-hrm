"""Synthetic PostgreSQL tests. Fixed isolated loopback target; no production mode."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LOCAL = Path(os.environ.get('LOCALAPPDATA', ''))
CLIENT = os.environ.get('MGHRM_LOCAL_PSQL', str(LOCAL / 'Programs/PostgreSQL/18.6-client/bin/psql.exe'))
ENV = {k: v for k, v in os.environ.items() if not k.startswith('PG')}
ENV.update(PGPASSFILE=str(LOCAL / 'MGHRM/local-postgres18/pgpass-local.conf'), PGSSLMODE='disable', PGCONNECT_TIMEOUT='5', PGCLIENTENCODING='UTF8')

def sql(text):
    result = subprocess.run([CLIENT, '-X', '-w', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1',
        '-h', '127.0.0.1', '-p', '55432', '-U', 'postgres', '-d', 'mghrm_test'],
        input=text.encode(), capture_output=True, env=ENV)
    if result.returncode:
        # Only synthetic local SQL is executed; employee data is never selected.
        raise RuntimeError(result.stderr.decode(errors='replace')[:1500])
    return result.stdout.decode().strip()

def run():
    assert sql("SELECT current_database()='mghrm_test' AND host(inet_server_addr())='127.0.0.1' AND inet_server_port()=55432;") == 't'
    sql((ROOT / 'tests/notification-integration.sql').read_text(encoding='utf-8'))
    uid = '33333333-3333-4333-8333-333333333333'
    todo = '900000000002'
    assert sql("SELECT count(*) FROM public.todos WHERE id=" + todo) == '0', 'Synthetic fixture ID occupied'
    due = sql("SELECT (now()-interval '1 hour')::text")
    try:
        sql("INSERT INTO public.profiles(id,role,is_active) VALUES ('"+uid+"','admin',true);"
            "INSERT INTO public.todos(id,note,status,reminder_enabled,next_reminder_at) VALUES ("+todo+",'LOCAL CONCURRENCY TEST','open',true,'"+due+"');")
        def claim(_):
            return json.loads(sql("BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claims='{\"sub\":\""+uid+"\",\"role\":\"authenticated\"}';"
                "SELECT public.notification_claim_todo_reminder("+todo+",'"+due+"',now()+interval '1 hour'); COMMIT;"))
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(claim, range(2)))
        assert sum(row['claimed'] for row in results) == 1, 'Concurrent devices both claimed'
        assert sql("SELECT count(*) FROM public.notification_events WHERE entity_id='"+todo+"'") == '1'
        # Distinct later due cycles remain distinguishable.
        next_due = sql("SELECT (now()-interval '1 minute')::text")
        sql("UPDATE public.todos SET next_reminder_at='"+next_due+"' WHERE id="+todo)
        result = json.loads(sql("BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claims='{\"sub\":\""+uid+"\",\"role\":\"authenticated\"}';"
            "SELECT public.notification_claim_todo_reminder("+todo+",'"+next_due+"',null); COMMIT;"))
        assert result['claimed']
        assert sql("SELECT count(*) FROM public.notification_events WHERE entity_id='"+todo+"'") == '2'
        assert sql("SELECT reminder_enabled FROM public.todos WHERE id="+todo) == 'f', 'Completed schedule must not restart'
    finally:
        # Fixed synthetic IDs in the guarded local database only. No production path.
        sql("DELETE FROM public.notification_events WHERE entity_id='"+todo+"' AND actor_user_id='"+uid+"';"
            "DELETE FROM public.todos WHERE id="+todo+"; DELETE FROM public.profiles WHERE id='"+uid+"';")
    print('PASS local PostgreSQL: event pipeline, retry, read/snooze/dismiss, ownership/RLS, anon/viewer rejection, rollback, two-device concurrency, future cycles and one-shot completion')

if __name__ == '__main__':
    run()
