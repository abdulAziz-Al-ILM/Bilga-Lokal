package com.ilmmizan.bilga;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Collections;
import java.util.Set;
import java.util.TreeSet;

/** Calendar engine for background task actions; mirrors Dart RecurrenceRule.
 * Pure java.time so its behavior can be checked without an Android emulator.
 */
public final class TaskRecurrence {
    private TaskRecurrence() {}
    public enum Unit { DAY, WEEK, MONTH, YEAR }

    public static final class Rule {
        public final Unit unit;
        public final int interval;
        public final Set<Integer> weekdays;
        public final LocalDate until;

        public Rule(Unit unit, int interval, Set<Integer> weekdays, LocalDate until) {
            if (unit == null || interval < 1 || interval > 365 || weekdays == null ||
                weekdays.stream().anyMatch(d -> d == null || d < 1 || d > 7) ||
                (unit != Unit.WEEK && !weekdays.isEmpty()) ||
                (until != null && (until.getYear() < 1 || until.getYear() > 9999))) {
                throw new IllegalArgumentException("recurrence_invalid");
            }
            this.unit = unit;
            this.interval = interval;
            this.weekdays = Collections.unmodifiableSet(new TreeSet<>(weekdays));
            this.until = until;
        }
    }

    private static ZonedDateTime wall(Rule rule, ZonedDateTime anchor, long year, int month, int day) {
        if (year < 1 || year > 9999) return null;
        LocalDate first = LocalDate.of((int) year, month, 1);
        return allowed(rule, first.withDayOfMonth(Math.min(day, first.lengthOfMonth()))
            .atTime(anchor.toLocalTime()).atZone(anchor.getZone()));
    }

    private static ZonedDateTime allowed(Rule rule, ZonedDateTime candidate) {
        if (candidate.getYear() < 1 || candidate.getYear() > 9999 ||
            (rule.until != null && candidate.toLocalDate().isAfter(rule.until))) return null;
        return candidate;
    }

    private static ZonedDateTime day(Rule rule, ZonedDateTime anchor, LocalDate date) {
        return allowed(rule, date.atTime(anchor.toLocalTime()).atZone(anchor.getZone()));
    }

    public static ZonedDateTime next(Rule rule, ZonedDateTime anchor, Instant after) {
        if (anchor.getYear() < 1 || anchor.getYear() > 9999) {
            throw new IllegalArgumentException("recurrence_invalid");
        }
        ZoneId zone = anchor.getZone();
        ZonedDateTime cutoff = after.atZone(zone);
        if (after.isBefore(anchor.toInstant())) return allowed(rule, anchor);
        if (cutoff.getYear() > 9999) return null;
        LocalDate first = anchor.toLocalDate(), current = cutoff.toLocalDate();
        long period;
        switch (rule.unit) {
            case DAY:
                period = Math.max(0, ChronoUnit.DAYS.between(first, current) / rule.interval);
                for (int i = 0; i < 2; i++, period++) {
                    ZonedDateTime candidate = day(rule, anchor, first.plusDays(period * rule.interval));
                    if (candidate == null) return null;
                    if (candidate.toInstant().isAfter(after)) return candidate;
                }
                break;
            case WEEK:
                LocalDate monday = first.minusDays(first.getDayOfWeek().getValue() - 1);
                Set<Integer> weekdays = rule.weekdays.isEmpty()
                    ? Collections.singleton(first.getDayOfWeek().getValue()) : rule.weekdays;
                period = Math.max(0, ChronoUnit.DAYS.between(monday, current) / (7L * rule.interval));
                for (int i = 0; i < 2; i++, period++) {
                    for (int weekday : weekdays) {
                        ZonedDateTime candidate = day(rule, anchor,
                            monday.plusDays(period * rule.interval * 7 + weekday - 1));
                        if (candidate == null) return null;
                        if (!candidate.toInstant().isBefore(anchor.toInstant()) && candidate.toInstant().isAfter(after)) {
                            return candidate;
                        }
                    }
                }
                break;
            case MONTH:
                long firstMonth = first.getYear() * 12L + first.getMonthValue() - 1;
                long currentMonth = current.getYear() * 12L + current.getMonthValue() - 1;
                period = Math.max(0, (currentMonth - firstMonth) / rule.interval);
                for (int i = 0; i < 2; i++, period++) {
                    long month = firstMonth + period * rule.interval;
                    ZonedDateTime candidate = wall(rule, anchor, month / 12, (int) (month % 12) + 1, first.getDayOfMonth());
                    if (candidate == null) return null;
                    if (candidate.toInstant().isAfter(after)) return candidate;
                }
                break;
            case YEAR:
                period = Math.max(0, (current.getYear() - first.getYear()) / rule.interval);
                for (int i = 0; i < 2; i++, period++) {
                    ZonedDateTime candidate = wall(rule, anchor, first.getYear() + period * rule.interval,
                        first.getMonthValue(), first.getDayOfMonth());
                    if (candidate == null) return null;
                    if (candidate.toInstant().isAfter(after)) return candidate;
                }
                break;
        }
        return null;
    }
}
