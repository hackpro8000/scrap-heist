# Pack: Luau game code

Read `CLAUDE.md` ("Code style", "Design") first; `ROADMAP.md` decides layout, lifecycle and naming.

- Code lives in `src/server`, `src/client` and `src/shared`. `shared` never requires the other two.
- Systems use `init()` then `start()`. No `WaitForChild` in server module requires.
- Shared types go in `<System>Types.luau` with `export type`.
- Tabs, guard clauses, `_private` fields, practical type annotations.
- Run a single test file with `lune run <file>`. Ask the brief for the project's check command if it names none.
- Search with `rg`; edit with the Edit tool or `sd`, never `sed`.
