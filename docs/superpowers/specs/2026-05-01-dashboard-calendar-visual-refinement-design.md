# Dashboard Calendar Visual Refinement Design

## Problem

The dashboard calendar is functionally correct, but three visual issues reduce clarity:

1. On the current day, the `休` marker can visually collide with the today outline and feel partially covered.
2. The day detail popover uses a palette with insufficient contrast, so key text is harder to scan than it should be.
3. Days where the user has already been to the company do not stand out enough from the surrounding dates.

The goal is to improve legibility and state recognition while preserving the product's minimal, airy visual style.

## Scope

This change only refines dashboard calendar presentation:

- Current-day date styling
- Holiday rest-day badge styling and placement
- Present-day visual treatment in the month grid
- Day detail popover colors, hierarchy, and readability

This change does **not** modify month navigation, gesture behavior, attendance persistence, holiday calculation rules, setup flow, or location tracking.

## Selected Direction

The approved direction is **Quiet Halo**: keep the calendar visually light and minimal, but make meaningful states easier to recognize through subtle structure, contrast, and hierarchy rather than heavy fills.

This direction was chosen because it matches the existing product tone better than a strong dark-tile treatment while still making attended dates clearly distinct.

## Visual Design

### Calendar Date Cell

- Keep the grid background white and uncluttered.
- Keep date numbers as the primary anchor.
- Refine the **today** treatment into an inset, thin outline so it frames the date without fighting nearby status markers.
- Preserve generous whitespace and avoid turning the calendar into a heatmap-style block UI.

### Holiday Badge

- Replace the current floating `休` text treatment with a compact badge anchored to the upper-right corner of the date cell.
- Use a soft red-tinted capsule or rounded badge with stronger foreground contrast than the current tiny text.
- Ensure the badge sits above the today outline visually so the label never appears clipped or covered.
- Keep transfer-workday and holiday semantics intact; this is a presentation change only.

### Present-Day Emphasis

- Give attended days a **restrained but obvious** distinction.
- Avoid full dark tiles or loud color fills.
- Use a combination of slightly stronger date emphasis and a subtle grounded signal beneath the date, such as a short ink-toned underline or micro-indicator.
- The effect should read as “visited” immediately while staying consistent with the product's calm, premium minimalism.

## Day Detail Popover

- Keep the popover as a light glass-style floating card rather than switching to a heavy dark card.
- Increase text readability by strengthening contrast across all content layers:
  - primary title/date: deep foreground
  - time values: strongest contrast, easy to scan
  - supporting copy and labels: controlled mid-gray
  - holiday text: semantic tint, but still readable
- Keep the status pill at the top as the first recognition layer.
- Slightly strengthen the card surface so the popover reads clearly above the white dashboard background.
- Preserve the existing compact size behavior unless content spacing changes require a small height adjustment.

## Interaction

- Continue using the existing press-and-drag interaction model for day selection.
- Continue showing the popover only for current-month dates.
- Continue clearing the popover on release.
- Keep current haptic behavior when moving across dates.
- Do not introduce additional taps, toggles, or gesture changes.

## Components

- `FigmaDayCell`
  - Owns the updated visual treatment for today, holiday badge placement, and present-day emphasis.
- `DayTimePopover`
  - Owns the updated glass card, contrast improvements, and hierarchy refinements.
- `DashboardView`
  - Continues to own presentation and positioning of the popover.
- `DashboardCalendarLayout`
  - Remains the source of day status semantics; no behavioral rule changes are expected.

## Testing

- Preserve existing dashboard behavior and gesture coverage.
- Add or update pure logic tests only if visual refinements require new derived state or status helpers.
- Validate that holiday days, present days, incomplete days, and future days still map correctly to their intended display states.
- No new persistence or tracking tests are required because behavior is unchanged.

## Notes

- The design should feel like a polish pass on the existing dashboard, not a redesign into a different visual language.
- If implementation reveals that the present-day emphasis is still too weak, increase contrast incrementally before introducing heavier fills.
