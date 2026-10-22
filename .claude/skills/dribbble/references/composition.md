# Composition

Every layout in `assets/shot-template.html` is a 1600×1200 section. The feed
shows it at around 400×300, so design for that size first and let the 2× render
reward people who open the shot.

## The thumbnail test

Before showing a shot, render it and look at it shrunk to 400 px wide (the
render script also writes `*-thumb.png` for this). Ask:

1. Is there **one** thing the eye lands on?
2. Is that thing **at least a third** of the frame?
3. Is the shot recognisable **by colour alone** next to others?
4. Is any text that matters still **readable**? If not, cut it or move it to
   the description.

## Layouts

| Layout | Series step | Composition |
|---|---|---|
| `mark` | 1 · Mark | Logo centred at 35–55% of the frame width on a full-bleed brand colour. Optional small label bottom-left. Nothing else. |
| `idea` | 2 · Idea | Two to three steps left to right (sketch → construction → final), or the mark over its construction grid. Thin lines, the final in full colour. |
| `system` | 3 · System | Bento grid: big mark tile, colour swatches with names and hex values, one type specimen tile, one pattern tile. 24 px gaps, one radius throughout. |
| `applications` | 4 · Applications | One hero touchpoint large (60% of the frame), two small ones beside it. Real photos or mockups the user supplied. |
| `split` | any | Two equal halves: before/after, light/dark, print/digital. |
| `specimen` | type | Type at display size cropped by the frame edge, character set below, name and weight small. |

## Rules

- **Margins**: 96 px minimum on all sides at 1600×1200. Thumbnails crop
  slightly in some views.
- **Grid**: 12 columns, 24 px gutter. The template sets this up as tokens.
- **Colour**: background is a brand colour in at least half of a series. White
  backgrounds disappear in the feed, which is mostly white.
- **Type in the image**: one family (the brand's), maximum two sizes.
- **Mockups**: one perspective per series. Mixing flat and 3D mockups makes a
  series look assembled from stock.
- **Consistency across a series**: same margins, label position and radius.
  Seen together on the profile, the shots should form one identity.
- **Motion**: 4:3, 1600×1200, loop seamlessly, 6–15 seconds, MP4 (H.264),
  under 20 MB. The first frame is the thumbnail, so it has to work as a still.

## Multi-block case study

For the web uploader's long shot, stack blocks in this order: mark (also
thumbnail), short text block, idea, system, applications, motion, closing
text with credits. Wider blocks such as 1600×900 are fine after the first,
because only the first one has to survive the 4:3 crop.
