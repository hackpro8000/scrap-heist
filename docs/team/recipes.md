# Recipes

Setups that beat their estimate and passed. A recipe is **unproven** until it holds on two more tasks, then **default**. Format: task kind, setup, why it was fast, evidence, status.

| Task kind | Setup | Why it was fast | Evidence | Status |
|---|---|---|---|---|
| Two-line fix with a test | One `worker`, brief with the directory and the test command | Narrow tool list; the test decides done | 9.8–13.0 s and about 33k tokens, against 13–19 s and 241k–324k on an all-tools agent (2026-11-11) | unproven |
| Lookup across named files | One `minimal-reader` or `scout`, exact file:line pointers, 6-line report | No searching; small context re-read each step | 7–8 s and about 17.6k tokens, against 31–37 s and 525k–760k (2026-11-11) | unproven |
| Archiving many cloud sessions | One `scout` does all of them, three-line report | Keeps 900 tokens per call out of the Lead's context | 23 sessions, 3 lines back (2026-11-11) | unproven |
