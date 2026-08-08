# Design docs

Prose that cannot live in the source files (see `CLAUDE.md`).

- [Raycast vision cone](vision-cone.md) — how 128 raycasts become a shader mask
  that hides everything the robot cannot see.
- [Enemy AI](enemy-ai.md) — a state machine built from scene nodes, so each
  enemy type is a scene layout rather than another branch in one script. Sight,
  hearing, and how it picks somewhere to wander.
- [Dungeon generation](dungeon-generation.md) — rooms grown outward from
  doorways, DunGen style, with the entrance at the edge and the command room
  deep at the end of the main path.
