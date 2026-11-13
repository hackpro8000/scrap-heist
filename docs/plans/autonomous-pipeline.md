# Autonomous model pipeline

Status: plan, agreed in outline on 2026-11-11. Nothing here is built yet.

## Goal

Push out high volumes of models as fast as possible, with quality and style unchanged. The pipeline watches itself, predicts problems before they happen, and improves without being asked.

## Fixed choices

- Every surface keeps its own baked, hand-painted texture, terrain included. No tiling materials.
- Hard signs stop a build. Everything else is logged and reasoned about.
- Experiments done to improve the pipeline use small samples: under 10 seconds, never a sample that may take a minute. The bar tightens itself to the best record.
- No heavy builds on the user's computer.
- Cold builds must be fast on their own. The cache is a bonus for busy sessions on warm machines, such as several revisions of a large map. It is not meant to be restored onto fresh machines, and speed is judged with the cache off.

## Autonomy rules

- Push main and upload to Roblox without asking, but only once a model is out of the previewing phase.
- The build cache stays under 5 GB.
- A failing build gets 2 minutes of machine time at most, then it is stopped. A live feed of every build is always available to check in on.
- When a task can't be done as specified: notify the user, then try to find a way.
- Small fixes (rules, checks, script guards) are applied without asking. They must not change how models look, and each must be reversible. Changes to the baker or the build workflow that could change a pixel go to the user first.
- Old cache sets are deleted; only the newest set per machine is kept.
- A run builds the general concept first, then refines it until a time the user gives.
- Changes to machine count or idle time cost money and are asked first.

`CLAUDE.md` says "if a model task can't be done, stop and report why; don't fall back". The fourth rule above replaces that for autonomous runs. `CLAUDE.md` is updated when this plan is approved.

## 1. Cost model

Every operation has a cost formula in Big O form, however small: each helper in the model scripts down to one vertex or face, each step of the baker down to one texel lookup, and the steps around them (assemble, push, machine start, cache restore, upload, placing in Studio, screenshots, critic rounds).

- A formula is written in terms of things known before a build: segments, sides, triangles, texels, layers, nearby surfaces, chunks in a part.
- Each formula has one constant, seconds (or bytes) per unit on a build machine, measured once per machine type and stored.
- A check fails the build if any function has no formula.
- Reports rank operations by total cost (cost per call times calls), so small operations that add up rise to the top.
- After each build, predicted total is compared with the real total. Time the formulas don't explain is "unaccounted". Target: under 1%. Above that opens a ledger entry.

## 2. Prediction before each build

Three modes:

| Mode | What runs | When |
|---|---|---|
| Predict | A geometry-only dry run plus the formulas. Nothing is baked, nothing is counted. | Before every build |
| Normal build | The real work. Only a start and end time per stage is recorded. | Every build |
| Calibration | A build with per-operation counters on. | Rarely: a new formula, or a prediction that missed |

The dry run executes a model script's geometry step and builds meshes in memory. It gives exact triangle counts, texture sizes and neighbour counts. From those the formulas give time, peak memory, cache growth and the list of textures the change will rebake.

## 3. Watchdog

Before a build (preflight). The build does not start unless:
- the coordinator is up with no leftover tasks;
- every machine is connected with its cache restored;
- the model check passes with zero failures;
- the cache is under its limit, tools are installed and Studio is connected.

Canary. Each build goes to one machine first, for about a minute. Wrong readings stop it there.

During a build (live readings). Every machine reports memory, time per texture and cache hits. Hard signs stop the build:
- memory above about 70%;
- a failed check;
- a stale task;
- a rebake of something whose source did not change;
- a prediction missed by a wide margin.

Soft signs are logged and reported: a slower texture, one reconnect, a quiet log.

After a build (postflight). Part count, texture sizes, uploads, objects placed in Studio and the before-and-after screenshots are checked against what was expected.

Two rules:
- No accepted failures. A warning is fixed, or written into a waiver file with a reason.
- A stoppage sends the user a notification at once.

## 4. Event log and predictor

- Every small event is recorded with a time and a measurement, even when it looks harmless.
- After each build a script extends each trend (cache size, peak memory, time per texture, cache hit rate, part count, texture area) and says how many builds remain before a limit is reached.
- At each checkpoint the recent events are read and each gets a written prediction: what it could lead to, how likely, and what sign would confirm it. That sign becomes something the watchdog watches.
- Each kind of prediction has a tracked hit rate. Kinds that never come true lose weight.

## 5. Self-improvement ledger

Triggers, each on a single occurrence:
- a stage slower than its prediction or its last run;
- a failed build, a retry or a dropped machine;
- the user having to ask for status;
- a defect the user catches that the critics did not list;
- a defect that returns after being fixed;
- a critic finding that proved wrong;
- any correction from the user.

Each trigger gets one ledger line (what happened, the number, the cause), a permanent fix (critic rule, code check, script guard or saved preference), and proof that the fix catches the original case. A regular pass merges duplicates and drops rules that never fire.

## 6. Speed tuning

- Metrics per build: textures per minute, seconds per texel by layer, cache hit rate, idle machine time, critic rounds per model, time from request to checkpoint.
- A faster alternative, once found, is tried on the small sample set and then on the canary.
- Quality lock: a change is kept only if the output textures of a fixed test set are identical to before. Anything that changes a pixel is a style question for the user.
- The sample set is a handful of tiny models that together touch every operation type. A record counts only if it holds across a few repeats.
- Problems that only appear at size are covered by the formulas and the canary, not by large test runs.

## 7. Baker and cache fixes

- Small edits cause small rebakes: strokes are placed by world position, so a chunk depends only on neighbours within reach.
- Progress is saved as it is made, into one shared, content-keyed cache that every machine reads and writes.
- Memory is capped: a chunk loads edge data only for chunks within reach.
- Cache layers are stored as 16-bit values, not 32-bit floats. The cache writes 12 bytes per texel per image today.

## 8. Review

- Measurable rules (pipe angles, parts passing through each other, shared planes, capsule clearance) are checked in code on the mesh.
- After each build the saved Studio cameras retake their shots and compare them with the last set. Critics look only at frames that changed.

## Order of work

1. Unblock the current map build (the island bake runs the machines out of memory).
2. Permanent live readings, preflight and the canary.
3. Stage timings and the event log.
4. Cost formulas and the dry-run predictor, starting with the baker.
5. Baker and cache fixes, each proven pixel-identical on the sample set.
6. Ledger, trend projection and the prediction pass.
7. Code checks and the screenshot comparison.

## Known gaps

- The cache is about 6 GB after cleanup, above the 5 GB limit. The 16-bit change is expected to bring it to about 3 GB; not yet measured.
- Whether one GPU machine beats 20 CPU machines is unmeasured.
- The cause of the island's memory use is read from the code, not yet confirmed by measurement.
