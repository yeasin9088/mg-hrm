#!/bin/bash
apk add postgresql-client
# create a quick local postgres instance to test
mkdir -p /tmp/pgdata
initdb -D /tmp/pgdata
pg_ctl -D /tmp/pgdata -l logfile start
sleep 2
createdb testdb
psql -d testdb -f supabase_setup.sql
pg_ctl -D /tmp/pgdata stop
