---
name: doc
description: Write an explanatory markdown document for a feature that was just implemented. Use after finishing a non-trivial feature, or when the user asks to document how something works (/doc). Produces a walkthrough in docs/ with diagrams, aimed at someone reading the code for the first time.
---

# /doc — explain a feature that was just built

This repo forbids comments in source files (see `CLAUDE.md`). Prose lives here
instead. A `/doc` page is the replacement for the comments the code is not
allowed to carry: it explains *why* the feature is shaped the way it is and
*how* the pieces fit, so a reader can open the code and already know what they
are looking at.

Write for someone competent who has never seen this feature. Not a changelog,
not an API dump, not marketing.

## 1. Establish the scope

Decide exactly which feature is being documented before writing anything.

- If the user named it, use that.
- Otherwise infer it from the work just completed in this conversation.
- Confirm against the code — never document from memory of the conversation
  alone:
  - `git diff main...HEAD --stat` and `git log --oneline main..HEAD` for the
    branch's story
  - `git diff HEAD~1` / `git show <sha>` for a single commit
  - Read every file the feature touches, in full, including the `.tscn` scenes
    and `.gdshader` / `.gdshaderinc` files. Scene structure and exported
    properties are part of the implementation in Godot and are the part a
    reader cannot reconstruct from scripts alone.

If the change is genuinely small (a tweak, a rename, a bugfix), say so and
suggest skipping the doc rather than inflating it into one.

## 2. Where the file goes

`docs/<feature-name>.md`, kebab-case, named after the feature and not after the
commit — `docs/vision-cone.md`, not `docs/add-raycast-vision.md`. Create
`docs/` if it does not exist.

If a doc for the feature already exists, update it in place instead of adding a
second file, and keep its existing headings where they still apply.

Add a line to `docs/README.md` (create it if missing) — one bullet per doc,
`- [Title](file.md) — one-line hook`.

## 3. Shape of the document

Use `assets/template.md` as the starting skeleton. Drop sections that have
nothing real to say; an honest five-section doc beats a padded nine-section
one. Never keep a heading with filler under it.

The spine that must always be there:

1. **What it does** — two or three sentences, concrete, from the player's or
   caller's point of view. What is on screen, or what the system now supports.
2. **The problem it solves** — why the naive approach was not enough. This is
   the single most valuable paragraph in the document and the one most often
   skipped.
3. **A picture** — see below.
4. **The pieces** — a table of every file involved and its one-line job.
5. **How it works** — the walkthrough. This is the body.
6. **Decisions and tradeoffs** — what was rejected and why, what this costs.
7. **Knobs** — exported variables, shader uniforms, constants worth tuning,
   with their meaning and sensible ranges.
8. **Gotchas** — the things that will bite the next person: ordering
   requirements, assumptions about scene layout, known limits.

## 4. Diagrams

Include at least one when it helps, which is most of the time. A diagram that
restates a bulleted list helps nobody — draw the thing the prose is bad at.

**Never use ASCII art.** No box-drawing characters, no hand-aligned figures, no
text-art trees. It collapses in proportional fonts, it is unreadable to screen
readers, it cannot be scaled, and it goes stale the moment anyone reflows a
paragraph. Use a real diagram format instead — every case below has one.

Pick the form by what you are showing:

| Showing | Use |
| --- | --- |
| Data or signals moving between nodes/scripts | Mermaid `flowchart LR` |
| Per-frame ordering, who calls whom and when | Mermaid `sequenceDiagram` |
| Node hierarchy of a scene | Mermaid `flowchart TD` |
| A state machine | Mermaid `stateDiagram-v2` |
| Phases over time | Mermaid `gantt`, or a table |
| Anything geometric or on-screen — angles, rays, cones, viewport space, UV layout, pixel grids, buffer strips | An **SVG file**, see below |

Mermaid is for topology: what connects to what, in what order. The moment the
*positions* carry meaning — an angle, a distance, a spatial layout — mermaid is
the wrong tool and you write SVG.

### Writing the SVG

Save to `docs/diagrams/<name>.svg` and embed it as a normal image:

```markdown
![The ray fan, showing three rays stopped by a wall](diagrams/vision-cone-fan.svg)
```

Embed by reference, never inline `<svg>` in the markdown — GitHub strips inline
SVG, so it renders as nothing. A linked file renders everywhere. Write real alt
text describing what the diagram shows, since this is now the only form the
content takes.

Do not hand-author coordinates for anything with real geometry in it. Write a
throwaway script that computes the points and emits the file, so the angles and
distances in the picture are the angles and distances in the code. Put the
script in the scratchpad, not in the repo — the SVG is the artefact.

Requirements for every SVG:

- A `viewBox`, and no fixed `width`/`height` on the root element, so it scales.
- Readable in both light and dark themes. Never rely on the page background:
  give shapes explicit fills, and add a `prefers-color-scheme: dark` block that
  swaps the stroke and text colours. Mid-tone accents read on either.
- `font-family="system-ui, sans-serif"` and a font size of at least 13 units at
  the diagram's natural scale. No text smaller than that.
- Every quantity labelled with its name from the code and its unit —
  `half_angle = 45°`, not an unlabelled wedge.
- Nothing load-bearing conveyed by colour alone.

Label the axes, the units, and the direction of flow. An unlabelled box diagram
is decoration.

## 5. The walkthrough

Follow one path through the feature end to end, in execution order, rather than
describing files one at a time. "A frame begins → the player's input is read →
the rig lerps toward the target → the vision pass renders → the composite
shader samples it" is followable. Nine file summaries are not.

Rules:

- Cite locations as `Scripts/vision_field.gd:42` — they are clickable, and they
  let the reader verify you.
- Quote code only in short excerpts, and only where the exact expression is the
  point (a formula, a clever bit of math, a non-obvious API call). Do not paste
  whole functions; the file is right there.
- Explain the *maths* when there is any. A line like
  `angle = deg_to_rad(fov) * (float(i) / ray_count - 0.5)` deserves a sentence
  saying it spreads rays evenly across the cone centred on the facing
  direction. This is the kind of thing the no-comments rule pushes out of the
  source, so it must land here.
- Prefer naming the mechanism over narrating the diff. Write "the rig keeps a
  separate target transform and eases toward it", not "we added a target
  transform".

## 6. Accuracy rules

- Every claim must be checkable against the code you read. If you are unsure
  whether something holds, either verify it or write it as an open question
  under Gotchas.
- Do not document intentions that were not implemented, or describe planned
  work as if it exists.
- Do not invent rationale. If you do not know why a value is `0.35`, say it was
  tuned by eye rather than fabricating a derivation.
- Numbers, defaults, and node names must match the files exactly — including
  values that live in `.tscn` rather than in script.

## 7. Style

- Present tense, active voice, second person for the reader where natural.
- Short paragraphs. Tables for enumerable facts, prose for reasoning.
- Define project jargon on first use.
- No AI-tell filler: no "In today's fast-paced", no "It's worth noting that",
  no closing summary that repeats the intro. End when the content ends.
- Length follows complexity. A tricky shader pipeline may need 300 lines; a
  self-contained script may need 60.

## 8. Finish

Report to the user: the path written, a one-line summary of what it covers, and
anything you deliberately left out or flagged as uncertain. Do not commit
unless asked.
