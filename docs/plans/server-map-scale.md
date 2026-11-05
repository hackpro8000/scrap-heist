# ServerMap scale plan

Goal: fix passage clearance and proportions so the avatar fits under gates and
bridge bars, while keeping the look the user likes.

## Scale factors

| Element | Change |
| --- | --- |
| Plaza island | Keep as is |
| Shop and surrounding props | 2.606× larger, except scrap vegetation (ScrapPalm, ScrapTreeLamppost), which stays as is |
| Arena island and related elements | 1.65× larger |
| Bridges | 1.5× wider |
| Bridge gate frames | Higher than now (exact height to be set with the user) |
| Yard islands and yards | 1.5× larger |

## Layout work

Changing island sizes will make islands collide with each other and swallow
nearby pieces. After resizing, adjust `art/src/layouts/ServerMap.luau` so:

- Islands do not overlap or intersect each other.
- Props and pieces stay on their islands, not inside neighbours.
- Bridges still land on their islands, and the bridge ends still meet the
  kerb and end posts.
- Yard spacing (`PAD_XS`, `YARD_OFFSET`, `MARKET_X`) and the road ring
  (`ROAD_INNER`, `ROAD_OUTER`) still fit together.

## Process

- Model changes are made in the main session, one model and one change at a
  time. Each model change ends with a checkpoint and a screenshot.
- Layout-only changes are made in `art/src/layouts/ServerMap.luau`, then the
  ServerMap is rebuilt and checked.
- Studio check after each stage: avatar walks under the yard gate and the
  bridge gate frames, and nothing is swallowed.

## Open questions

- Exact height for the raised bridge gate frames.
- Whether the shop's 2.606× applies to its footprint and height together.
