# Hijri Calendar Feature Audit & Gap Analysis

Based on a strict analysis of the authentic XML layout files decompiled from the Haqibat Almumin source repository, here is the detailed feature comparison between the original application and our current Flutter implementation.

## 1. Core Layout Structure (events_main.xml vs. hijri_calendar_screen.dart)

The original Android app uses a highly modular structure inside a `CoordinatorLayout` with a `NestedScrollView` containing various `CardView` components.

### Original `events_main.xml` Key Components:
- `com.hmomen.hqcore.theme.components.HijriCalendarView.HijriCalendarView` (ID: `0x7f0a0108`, name: `@+id/calendar`) - The custom calendar view itself.
- **Today's Events List:** Inside a `CardView` (ID: `0x7f0a010a`, name: `@+id/calendar_event_box`), containing a `LinearLayout` (ID: `0x7f0a0109`, name: `@+id/calendar_dayofmonth_events_list`) where the events for the selected day are dynamically loaded. The header title is defined by `eventBoxTitle` (`0x7f0a01f3`).
- **Upcoming Event (الحدث القادم):** A dedicated `CardView` (ID: `0x7f0a0112`, name: `@+id/calendar_next_event_box`) containing a title (`nextEventBoxTitle`, `0x7f0a0381`) and a container for the content (`next_event_box_container`, `0x7f0a0382`).
- **Date Converters:** There is a `HorizontalScrollView` containing two distinct `CardView` elements:
  - Hijri to Gregorian Converter (`@+id/calendar_hijiri_to_miladi`, `0x7f0a010b`) with title and caption (`calendar_hijiri_to_miladi_card_title` and `calendar_hijiri_to_miladi_card_caption`).
  - Gregorian to Hijri Converter (`@+id/calendar_miladi_to_hijri`, `0x7f0a010e`) with title and caption (`calendar_miladi_to_hijri_card_title` and `calendar_miladi_to_hijri_card_caption`).

### Our Current Flutter Implementation:
Our `lib/ui/calendar/hijri_calendar_screen.dart` is missing the modular structure.
- We have the Calendar grid.
- We have a single list for Events.
- **MISSING:** The entire `HorizontalScrollView` section containing the two Date Converter cards (`calendar_hijiri_to_miladi` and `calendar_miladi_to_hijri`).
- **MISSING:** The distinct, separate UI box for the "Next Event" (`calendar_next_event_box`). We currently just show events in a list, toggling the header text based on selection.

## 2. "Today's Events" Widget Layout (home_today_event_layout.xml)

The original app has a dedicated, reusable layout for displaying events on the home screen and inside the calendar (`home_today_event_layout.xml` and its dark variant `home_today_event_layout_dark.xml`).

### Original Layout:
- Wrapped in a `CardView`.
- Contains an `ImageView` for an icon/visual indicator.
- Contains two `TextView` elements:
  - `home_today_event_text` (`0x7f0a026b`) - For the event description.
  - `home_today_event_title` (`0x7f0a026c`) - For the event title/date.

### Our Current Flutter Implementation:
- We use a basic `ListTile` inside a `Card` in the `hijri_calendar_screen.dart`.
- **MISSING:** The specific styling and icon alignments found in the original `home_today_event_layout.xml`.

## 3. Action Buttons (Share / Reminders)

### Original App:
- **Share:** The string `@string/action_share` (and related `action_share_app`, `quran_action_share_verse`) is heavily used across the app. The ID `@+id/action_share` (`0x7f0a005f`) exists in the public definitions, indicating a global or menu-based sharing mechanism.
- **Reminders:** While not explicitly hardcoded as a prominent button in the main `events_main.xml` layout, the ecosystem supports "Reminders" via the overall notification/alarm architecture (as documented in `HAQIBAT_EXTRACTION_README.md`).

### Our Current Flutter Implementation:
- **MISSING:** We completely lack the "Share" button (`action_share`) on the Calendar screen.
- **MISSING:** There is no integration with the native AlarmManager for setting custom reminders for specific Hijri events.

## Conclusion & Gap Analysis Summary

Our Flutter app is currently lacking several key UI components and interactive elements present in the original Haqibat Almumin Hijri Calendar module:

1.  **Date Converters:** We need to implement the side-by-side (scrollable) cards for converting Hijri<->Gregorian dates.
2.  **Next Event Box:** We need a dedicated, visually distinct UI section for the "Upcoming Event" rather than just showing it in a standard list.
3.  **Share Functionality:** We need to add the ability to share events (`action_share`).
4.  **UI Fidelity:** The event list items need to be upgraded to match the structure of `home_today_event_layout.xml` (Card with Image/Icon + Title + Subtitle).
