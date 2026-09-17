#!/bin/bash
su - postgres -c "mkdir -p /tmp/pgdata && /usr/lib/postgresql/15/bin/initdb -D /tmp/pgdata && /usr/lib/postgresql/15/bin/pg_ctl -D /tmp/pgdata start && sleep 2 && createdb testdb && psql -d testdb -f /supabase_setup.sql && /usr/lib/postgresql/15/bin/pg_ctl -D /tmp/pgdata stop"
