---
name: design
description: IBIT Rooms UI/UX design system and review workflow. Use for any change to screens, widgets, theme, colours, typography, spacing, layout, copy or accessibility in this Flutter app (lib/features, lib/widgets, lib/core/theme.dart), and whenever asked to design, redesign, polish, or review the app's UI/UX.
---

# IBIT Rooms design

IBIT Rooms lets ITD (KMUTNB) students and staff find a free room and reserve a
time in under a minute, then check or cancel the booking later. 13 classrooms
and computer rooms are bookable; 5 specialized rooms are information only.
Bookings are Monday–Friday, 8:00 AM–12:00 PM and 1:00–4:00 PM, Bangkok time,
to the minute. The server is authoritative; the UI prevents and explains.

## UX principles, in priority order

1. **Task first.** Every tab opens on the job, not on branding. The logo is a
   compact `ScreenHeader`; never add hero banners or slogans to task screens.
2. **Availability is the content.** Say it in words ("Free now until 10:30 AM",
   "Free all day", "Fully booked") and back it with the availability bars.
   Never rely on colour alone.
3. **One primary action per screen.** Filled navy = primary, outlined =
   secondary, text button = tertiary. Destructive actions use
   `AppColors.danger` and always go through a confirm dialog that names the
   exact thing being removed.
4. **Prevent, then explain.** Offer valid choices first (suggested slots,
   weekday-only pickers, disabled impossible actions). Validate live, show one
   problem at a time next to the action that triggers it, and never discard
   input after an error.
5. **Design all four states** of every async view: loading (skeleton or
   spinner), empty (with a next step), error (plain cause plus "Try again"),
   and content.
6. **Close the loop.** Review sheet before committing, success screen with a
   reference, snackbar after cancelling.
7. **Works for everyone:** 320×568 at 200% text, TalkBack, 48 dp targets.

## Visual language

All tokens live in `lib/core/theme.dart`. Screens never hard-code
`Color(0x…)`, font sizes, radii or font families. If a value is missing, add a
token with a documented role first.

| Token | Role |
| --- | --- |
| `AppColors.ink` #192F59 | ITD navy: text, primary buttons, selected chips/days |
| `AppColors.orange` | Brand decoration only (bars, dots). Fails contrast as text |
| `AppColors.accent` | Orange for text/icons: countdowns, official-listing link |
| `AppColors.canvas` | Page background. Cards sit on it in `surface` (white) |
| `AppColors.panel` | Placeholders, neutral pills, disabled fills |
| `AppColors.navyTint` | Highlight fills: nav indicator, info notices, icon tiles |
| `AppColors.line` | Hairline borders and dividers |
| `AppColors.muted` | Secondary text; the lightest colour allowed for text |
| `available` / `availableTint` | Free time, confirmed, success |
| `reserved` / `past` | Booked and elapsed time on availability bars |
| `danger` / `dangerTint` | Errors and destructive actions |

- **Type:** Mitr only, through `Theme.of(context).textTheme`.
  `headlineMedium` screen titles, `headlineSmall` sheet titles, `titleMedium`
  card titles, `titleSmall` group labels, `bodyMedium` text, `bodySmall`
  meta (muted), `labelSmall` pills. Mitr ships 400/600/700 only. Do not use
  `TextStyle(...)` without starting from a theme style, or Mitr is lost.
- **Spacing:** `AppSpace` (4/8/12/16/24/32). Screen gutter is
  `AppSpace.gutter` (20). 24 between sections, 12–16 inside them.
- **Shape:** cards 16 (`AppRadius.lg`), buttons and inputs 14, pills fully
  round, sheets and dialogs 24. Flat: separate with canvas vs surface and a
  `line` border, never shadows.
- **Imagery:** `RoomArtwork` only: official ITD photo, bundled illustration as
  fallback, cover-fit, rounded. The ITD logo (`ItdLogo`) is never recoloured,
  cropped or stretched.
- **Icons:** Material rounded/outlined, 16–24 px, `ink` or `muted`.

## Components (`lib/widgets`)

| Component | Use for |
| --- | --- |
| `ScreenHeader` | Top of each tab: logo, title, one line of context |
| `SectionHeader` | Group titles; pass `step:` for numbered form steps |
| `SurfaceCard` | Every card; `onTap` makes it a tappable row |
| `StatusPill` + `PillTone` | Short status: availability, booking state, facts |
| `Notice` + `NoticeTone` | Inline messages; `isError: true` announces to TalkBack |
| `EmptyState` | Empty and error states, with an action |
| `InfoRow` | Icon + label + value facts (rules, details) |
| `DetailLine` | Label/value rows in review and confirmation cards |
| `DayStrip` | Weekday-only horizontal date picker on the rooms tab |
| `DayStepper` | Previous / pick / next weekday inside a flow |
| `AvailabilityTimeline` | Morning/afternoon bars, legend, free times, selection |
| `AvailabilityBar` | A single session bar (used for the mini bar on room cards) |
| `RoomArtwork` | Room photos with fade-in and fallbacks |

Helpers in `common.dart`: `timeLabel`, `rangeLabel`, `dateLabel`,
`relativeDayLabel`, `roomTypeLabel`, `shiftWeekday`, `pickBookingDate`.
Free-time logic is `BookingTime.freeWindows`; never re-implement it in a
widget.

## Screen patterns

- **Tab root** (`RoomsScreen`, `BookingsScreen`, `AccountScreen`):
  `SafeArea(bottom: false)` → scroll view → `ScreenHeader` → controls →
  content. `AppShell` owns the `NavigationBar` (labels: Rooms, Bookings,
  Account).
- **Detail** (`RoomDetailScreen`): `AppBar` with a short title, content, then
  a sticky bottom bar (white, top `line` border, `SafeArea`) for the primary
  action.
- **Form** (`ReservationScreen`): numbered `SectionHeader`s; the sticky bottom
  bar holds the live summary or the single current problem, plus the primary
  button. Commit through a review bottom sheet.
- **Confirmation**: success icon, title, summary card with reference, the next
  action as primary and "explore more" as a text button.

## Copy

- Sentence case, plain words, no slogans in task flows.
- Buttons are verbs: "Reserve this room", "Review reservation",
  "Cancel reservation", "Try again".
- Times through `rangeLabel`: "8:00–9:30 AM", "11:00 AM–1:00 PM". Durations
  through `BookingTime.durationLabel`: "1 hr 25 min". Dates: "Mon, 5 Oct
  2026" in details, `relativeDayLabel` ("Today", "Tomorrow", "Wed, 7 Oct")
  in lists.
- Errors say what happened and what to do next. Say "Bangkok time" wherever
  booking rules are stated.

## Accessibility checklist

- Tap targets ≥ 48 dp. Colour contrast: text ≥ 4.5:1 (`muted` is the floor).
- No overflow at 320×568 with 200% text. Use `Wrap` or a stacked layout
  instead of `Row` when two text items share a line.
- Headings use `Semantics(header: true)`. Errors use `Notice(isError: true)`.
  Decorative visuals are excluded or labelled (`ExcludeSemantics`,
  `Semantics(label:)`).
- Status never by colour alone: always a word in the pill or text.

## Contracts the tests rely on

Keys: `start_time`, `end_time`, `booking_purpose`, `review_reservation`,
`confirm_reservation`, `reservation_date`, `view_bookings`, `sign_out`.

Visible strings used by `integration_test/app_flow_test.dart` and `test/`:
"New to IBIT Rooms? Create account", "Create account", "Sign in",
"Forgot password?", "Send reset link", "Check your email",
"Try simulated Google account", "One last step.", "I’ve verified my email",
"Reserve this room", "Reservation confirmed", "View my bookings",
"Confirmed", "Cancel reservation", "Cancel booking", "No upcoming bookings",
"Cancelled", "Account", "Sign out", "Couldn’t load rooms", "Try again",
"Afternoon", "Official ITD room listing" (exactly once), "information only"
(lowercase, exactly once on a specialized room),
"Choose a start time and an end time.", suggested slot "8:00–9:00 AM", and
exactly one "1 hr" on the reservation screen after picking it. The day number
in each `DayStrip` tile is its own `Text`. Auth fields keep their order
(name, email, password). If you change one of these, update the tests in the
same change.

## Workflow

1. Read `lib/core/theme.dart` and `lib/widgets/common.dart` before touching UI.
2. Reuse a component or extend it. New tokens and components get a documented
   role here.
3. Implement, then run `dart format lib test`, `flutter analyze` and
   `flutter test`. The large-text widget tests catch overflows.
4. **Look at it.** Run `.\scripts\design-preview.ps1` (or
   `flutter test test/design_preview_test.dart --dart-define=DESIGN_PREVIEW=true`).
   It renders every main screen with fake data into
   `build/design_preview/*.png`. Open the PNGs with the Read tool and check
   them against the principles and the accessibility checklist. For a
   before/after, first render the old state with
   `.\scripts\design-preview.ps1 -OutDir build/design_preview_before`.
   Solid black blocks in a screenshot mean a `TextStyle` lost the Mitr family.
5. When you add a screen or state, add a scenario to
   `test/design_preview_test.dart`.
6. Report what changed with the screenshots, and list any test strings you
   changed.

## Review mode

When asked to review the UI rather than change it, render the previews and
report findings ordered by user impact. For each finding, give the screen, what
the user experiences, the principle it breaks, and a concrete fix using the
components above.
