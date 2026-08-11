# Design docs

- [Raycast vision cone](vision-cone.md) — how seven fans of raycasts become a
  shader mask that hides everything the robot cannot see, with soft shadows and
  corner peeking falling out of an eye that is a bar rather than a point.
- [Enemy AI](enemy-ai.md) — a state machine built from scene nodes, so each
  enemy type is a scene layout rather than another branch in one script. Sight,
  hearing, and how it picks somewhere to wander.
- [Dungeon generation](dungeon-generation.md) — rooms grown outward from
  doorways, DunGen style, with the entrance at the edge and the command room
  deep at the end of the main path.
