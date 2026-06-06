1. **Unify state management and screen synchronization**:
   - Refactor `HijriCalendarScreen` to use `Provider.of<SettingsProvider>(context)` to get `hijriAdjustment`.
   - Remove usage of `SharedPreferences` for `hijriAdj` and rely solely on `hijriAdjustment` which corresponds to `hijri.date.correction.value`.
   - Since `HijriCalendarScreen` will rebuild when `SettingsProvider` changes (if we listen to it or use `Consumer`/`context.watch`), this fulfills the immediate reactivity requirement.
   - We must also make sure other screens showing the date (like `HomeSection`) react. `HomeSection` is using `SettingsProvider` already, we just need to ensure the Hijri date display uses it properly.
2. **Build CalendarRepository for CMS**:
   - I have created `CalendarRepository`.
   - Update it to parse the `hijri_calendar` JSON object which will have month data, `expected_gregorian_start`, `total_days`, and arrays for `events` and `astronomical_events`.
   - Add a fallback mechanism to use `hijri` library's original events if CMS data is missing. I will copy the `_events` array from `HijriCalendarScreen` to the fallback method.
3. **Update Calendar Grid UI**:
   - Modify `GridView.builder` / `GridView.count` in `HijriCalendarScreen` to get the start day and length of the month.
   - If CMS data is present (`monthData != null`), calculate the leading empty cells using `expectedGregorianStart.weekday` and `totalDays`.
   - If not present, fallback to `HijriCalendar` functions (which it currently uses, like `monthHijri.dayWeeK(1)` and `monthHijri.getDaysInMonth()`).
   - Draw event badges based on `days[day].events` from CMS or the fallback list.
4. **Update README.md**:
   - Add a section on how to add Hijri Calendar JSON data to the CMS, as requested by the user.

5. **Pre-commit and Tests**:
   - Call `pre_commit_instructions` and run tests `flutter analyze` and `flutter test`.

6. **Submit**:
   - Commit with message "Feat: Refactor Hijri calendar to use CMS JSON via CalendarRepository and unify offset state" and submit.
