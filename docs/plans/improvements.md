### GUI:
- move the GUI onto Roblox React instead of the hand-built widgets in `src/client/UI/`. this needs a roadmap tooling update first.
- remove unnecessary UIStrokes on ImageLabels.
- shop items need improved icons.
- move frame bolts within the rounding radius, it clips into the border.
- too much unused space in the weapons preview in shop, repack the information neatly without leaving too much space.
- tab rows also have too much unused space.
- pop-in animation should be from the center, not the top-left corner
- gui stroke sizes should be consistent with the wood parts label frame.
- trade button's yellow arrow seems to bleed into the red arrow's head.
- nested rounded frames use the same corner radius, so the gap between them looks uneven at the corners. make the inner radius the outer radius minus the padding (concentric corners).
- proximity prompts should pop in and out with an animation instead of appearing abruptly. add a subtle pulse while shown.
- compact the title bar: keep the title and close button tighter together in the header, with an icon to the left of the title.
- shop weapon cards should convey information visually rather than with text. show stats as icons or bars, and reduce the description text.
- shop item preview is hard to see and barely contrasts with its background. increase contrast or add a backing behind the preview.
- shop title bar: the close button overhangs the panel's top-right corner, and the orange banner is taller than its text needs. move the close button inside the header and reduce the banner height.

### Map:
- yard fence frames on the starboard side face outward. they should all face inward. placement ignores the direction each fence is meant to face.
- machines float off their pads. seat each machine flush on its pad.

### Combat:
- bots are too hard to kill and feel too small. players barely get a chance to hit them or run away. increase their scale and tune their health or damage so encounters last long enough to react.

### Islands:
- plaza island is too close to the nearby pad island and yard islands. increase the spacing between them.
- the trophy icon on the top right should have the same visual weight as the cloud, shield, and bot survivors icons.
