import com.ilmmizan.bilga.TaskRecurrence;
import java.time.*;
import java.util.*;

public final class TaskRecurrenceCheck {
    private static void equal(Object actual, Object expected) {
        if (!Objects.equals(actual, expected)) throw new AssertionError(actual + " != " + expected);
    }
    private static TaskRecurrence.Rule rule(TaskRecurrence.Unit unit, int interval, Integer... days) {
        return new TaskRecurrence.Rule(unit, interval, new HashSet<>(Arrays.asList(days)), null);
    }
    private static ZonedDateTime next(TaskRecurrence.Rule rule, ZonedDateTime anchor, ZonedDateTime after) {
        return TaskRecurrence.next(rule, anchor, after.toInstant());
    }
    public static void main(String[] args) {
        ZonedDateTime month = ZonedDateTime.parse("2024-01-31T08:00:00Z");
        TaskRecurrence.Rule monthly = rule(TaskRecurrence.Unit.MONTH, 1);
        ZonedDateTime feb = next(monthly, month, month);
        equal(feb, ZonedDateTime.parse("2024-02-29T08:00:00Z"));
        equal(next(monthly, month, feb), ZonedDateTime.parse("2024-03-31T08:00:00Z"));
        ZonedDateTime weekly = ZonedDateTime.parse("2026-01-06T09:00:00Z");
        TaskRecurrence.Rule custom = rule(TaskRecurrence.Unit.WEEK, 2, 1, 3);
        ZonedDateTime wed = next(custom, weekly, weekly);
        equal(wed, ZonedDateTime.parse("2026-01-07T09:00:00Z"));
        equal(next(custom, weekly, wed), ZonedDateTime.parse("2026-01-19T09:00:00Z"));
        ZoneId ny = ZoneId.of("America/New_York");
        TaskRecurrence.Rule daily = rule(TaskRecurrence.Unit.DAY, 1);
        ZonedDateTime spring = LocalDateTime.of(2026, 3, 7, 9, 0).atZone(ny);
        ZonedDateTime springNext = next(daily, spring, spring);
        equal(springNext.getHour(), 9);
        equal(Duration.between(spring, springNext).toHours(), 23L);
        ZonedDateTime fall = LocalDateTime.of(2026, 10, 31, 9, 0).atZone(ny);
        equal(Duration.between(fall, next(daily, fall, fall)).toHours(), 25L);
        ZonedDateTime gap = LocalDateTime.of(2026, 3, 7, 2, 30).atZone(ny);
        ZonedDateTime normalized = next(daily, gap, gap);
        equal(normalized.getHour(), 3);
        equal(next(daily, gap, normalized).getHour(), 2);
        ZonedDateTime overlap = LocalDateTime.of(2026, 10, 31, 1, 30).atZone(ny);
        equal(next(daily, overlap, next(daily, overlap, overlap)).getDayOfMonth(), 2);
        TaskRecurrence.Rule end = new TaskRecurrence.Rule(TaskRecurrence.Unit.DAY, 1,
            Collections.emptySet(), LocalDate.of(2026, 1, 2));
        ZonedDateTime jan = ZonedDateTime.parse("2026-01-01T23:00:00Z");
        equal(next(end, jan, jan), ZonedDateTime.parse("2026-01-02T23:00:00Z"));
        equal(next(end, jan, next(end, jan, jan)), null);
        System.out.println("PASS native calendar engine: anchored months/weeks, DST, end date");
    }
}
