# PCC Dashboard — Agent Instructions

You are working in a workspace that includes the **PCC project dashboard** at
`/home/moataz/work/project-dashboard-PCC`.

## Reporting your work to the dashboard

At the end of any session where you did work on a tracked project, report it by
following these rules EXACTLY.

### STRICT RULES
1. DO NOT edit `projects/*.js`, `updates/overrides.json`, `hub.js`, `app.js`, or
   `index.html`. Do not touch any existing file.
2. Create ONE new file only: `updates/inbox/PROJECT-DATE.json`
   (e.g. `updates/inbox/cuopt-2026-08-10.json`).
3. Put ONLY valid JSON in it (format below).
4. If you did no project work, create nothing.

### Step 1 — discover the real IDs (never invent them)

```bash
cd /home/moataz/work/project-dashboard-PCC
node updates/validate-overrides.js --list
```

This prints every project id with its group ids (phase\*/milestone\*/m\*) and
step ids. Use those exact ids. If your project shows `groups: (none)` /
`steps: (none)`, do NOT guess ids — tell Moataz it can't be updated this way.

### Step 2 — write the inbox file

**Update an existing step** → `"PROJECT-ID"` → `"steps"` → `"STEP-ID"`:
- `status`: `pending` | `in-progress` | `done` | `blocked`
- `pending` / `in-progress` → include `"plannedDate": "YYYY-MM-DD"`
- `done` → include `"completedDate": "YYYY-MM-DD"`
- optional: `startDate`, `dueDate`, `subSteps`

**Add a new step** → `"PROJECT-ID"` → `"newSteps"` → `"GROUP-ID"`:
- each needs: `id`, `name`, `status`, and the relevant date(s)

**Create a new project** (only if not shown by `--list`) → top-level `"newProjects"`.

### Example inbox file

```json
{
  "PROJECT-ID": {
    "steps": {
      "STEP-ID":  { "status": "done", "startDate": "2026-08-10", "completedDate": "2026-08-10" },
      "STEP-ID2": { "status": "in-progress", "plannedDate": "2026-08-11" }
    },
    "newSteps": {
      "GROUP-ID": [
        {
          "id": "UNIQUE-ID", "name": "Step name", "description": "What it does",
          "status": "pending", "plannedDate": "2026-08-15",
          "subSteps": ["Detail 1", "Detail 2"]
        }
      ]
    }
  }
}
```

### Step 3 — validate before saving

```bash
node -e "JSON.parse(require('fs').readFileSync('updates/inbox/YOUR-FILE.json','utf8'))" && echo OK
```

Moataz reviews and applies your file via the dashboard — you never touch `overrides.json`.
