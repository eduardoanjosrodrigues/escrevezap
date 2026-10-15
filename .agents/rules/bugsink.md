# Error Tracking (Bugsink)

Production errors go to a self-hosted Bugsink (Sentry-compatible) at https://escrevezap.bugsink.com/.
The app reports via the Sentry SDK (`Sentry.capture_exception`). Project `EscreveZap` has id `1`.

Agents may query the Bugsink API freely to investigate errors — it is read access to our own data.

---

# Access

- The API token is NOT in the repo. It lives at `~/.config/bugsink/escrevezap_token` (chmod 600) on the developer machine.
- Auth header: `Authorization: Bearer <token>`
- API root: `https://escrevezap.bugsink.com/api/canonical/0/`

```bash
T=$(cat ~/.config/bugsink/escrevezap_token)
curl -s -H "Authorization: Bearer $T" "https://escrevezap.bugsink.com/api/canonical/0/issues/?project=1"
```

---

# Endpoints

- `projects/` — list projects
- `issues/?project=1` — paginated (cursor in `next`, 250 per page). Fields: `calculated_type`, `calculated_value`, `transaction`, `first_seen`, `last_seen`, `digested_event_count`, `is_resolved`, `is_muted`
- `events/?issue=<issue_id>` — events of an issue; `events/<event_id>/` has the full payload (`data.exception.values[].stacktrace.frames`)
- Only the latest ~1000 events are stored (`retention_max_event_count`), so old issues may have no events left.

---

# Triage Tips

- Many Meta errors embed `fbtrace_id` in the message, so the same error splits into many issues. Group by message with ids/numbers normalized before counting.
- Cross-check with production logs and the `TranscriptionError` table (see `production.md`).
- Resolving/muting issues changes shared state — ask the user first.
