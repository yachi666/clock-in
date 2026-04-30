# Dashboard Popover Soft Glass Design

## Problem

The dashboard date popover works functionally, but its current plain card feels flatter than the rest of the Figma-inspired interface. The user selected the **Soft Glass** direction: a restrained glass-style floating card with better hierarchy and a status pill, while keeping the dashboard minimal.

## Scope

This change only updates the dashboard day popover shown while pressing or dragging across calendar dates. It does not change attendance persistence, holiday loading, setup flow, month navigation, or calendar data rules.

## Design

The popover becomes a soft glass micro-card anchored near the selected date. It keeps the existing adaptive positioner and date-near behavior, but updates the visual treatment:

- Use a translucent white material-style background, rounded corners, subtle border, and softer shadow.
- Add a compact status pill at the top so the user can understand the day at a glance: `Present`, `Pending`, `Holiday`, `Future`, or `No record`.
- Preserve the simple information hierarchy: date and optional holiday line first, then arrival and leave rows only when data exists.
- Keep copy short and scannable. Holiday labels remain visible but secondary.
- Animate with the existing fade/scale transition, tuned to feel attached to the date rather than like a modal.

## Interaction

The popover continues to appear only while the user presses a current-month date and follows the selected cell while dragging. Moving into a new date keeps the existing light haptic feedback. Releasing the touch clears the popover.

## Components

- `DashboardView`: owns SwiftUI presentation, visual style, status pill, copy, and transition.
- `DayTimePopover`: becomes the focused visual component for the glass card.
- `DashboardPopoverPositioner`: remains the pure positioning helper unless tests show the larger card needs adjusted dimensions.

## Testing

Unit tests should cover any pure logic changes such as popover sizing or status derivation if extracted. UI-only styling changes are verified through existing dashboard tests plus the full test suite to ensure existing calendar, holiday, and gesture behavior remains stable.
