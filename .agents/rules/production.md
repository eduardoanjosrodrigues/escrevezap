# Production Access

Direct SSH access to the production machine is a normal, expected part of working on EscreveZap.
Agents may SSH into production to inspect logs, query the database, run Rails console/runner
commands and deploy — no need to ask for permission just to look.

---

# Connection

- Host: `eduardo@server` (key-based auth, no password)
- App directory: `~/microsaas/escrevezap`
- Compose file: `docker-compose-production.yml`
- The `eduardo` user is in the `docker` group — **never use `sudo`** for docker commands.

```bash
ssh eduardo@server 'cd ~/microsaas/escrevezap && docker compose -f docker-compose-production.yml ps'
```

Services: `web`, `worker`, `db`, `redis`, `waha`, `db-waha`, `cloudflared`.

---

# Common Commands

Always `cd ~/microsaas/escrevezap` first and use `docker compose -f docker-compose-production.yml` (abbreviated `dc` below).

- Logs: `dc logs --since 2h web worker | grep -i <term>`
- Rails runner (read-only queries): `dc exec -T web bin/rails runner 'puts User.count'`
- Rails console: `dc exec web bin/rails console`
- Deploy: run `./local-deploy.sh` locally (SSH + `deploy.sh` on the server: git pull, build, up -d)

---

# Rules

- Reading (logs, `ps`, SELECT-style queries, runner scripts that only print) is fine without asking.
- Writes to production data, restarts, deploys and anything destructive still require explicit confirmation from the user.
- Production data contains customer PII (phone numbers, transcriptions): only pull what the task needs and don't copy it outside the server/conversation.
