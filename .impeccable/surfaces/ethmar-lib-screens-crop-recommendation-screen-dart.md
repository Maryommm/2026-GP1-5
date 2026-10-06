---
version: 1
slug: "ethmar-lib-screens-crop-recommendation-screen-dart"
primary_target: "ethmar/lib/screens/crop_recommendation_screen.dart"
related_targets: []
---

# Crop recommendation screen

Scope: `ethmar/lib/screens/crop_recommendation_screen.dart` (results, loading, error states). Mode: Operate (browse-only). Audience: beginner home gardeners, Arabic/English. Job: see which crops suit today's weather and understand why. No planting/saving action yet.

## Direction contract

THESIS: Each recommended crop is a seed packet, one per swipe, held in a snap carousel. Refuses the category default: a long stack of expandable list cards where the details hide behind a tap.

OWN-WORLD: The Ethmar world, unchanged: beach-sand ground, forest ink, Baloo titles, Readex body, coral handwriting accent. The packet face takes its category tint (sea/coral/success/sun/info) with a large category glyph, and there's a crimped top edge. The packet back is a white care strip with four icon facts. Radius 24, no shadows beyond a soft tonal lift.

STORY: The beginner sees today's conditions, sees one crop at a time with a plain reason it suits today, learns how to care for it, and swipes through the rest.

FIRST VIEWPORT: Back button and title row, with the weather character small at the end. Below it, a conditions line (city · 31°C sunny · 22%). The packet fills about 70% of the height, about 86% of the width, and the next packet peeks at the end edge. Its face shows the glyph, name and category chip, then the reason in the accent style. The care strip runs along its base. Below the packet: a "1 / 6" counter and dots. No primary action (browse-only).

FORM: Seed packet deck, position 3 on the ordered list; seed key 5ae8c231. Raise from the vertical media feed: hard snap, one packet owns the frame, and the next one is already loaded.

Signature interaction: on swipe, the active packet scales to 1 and its neighbours sit at 0.92 and lower opacity. The dots morph to a pill on the active one. Reduce-motion turns this into a plain page change.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
