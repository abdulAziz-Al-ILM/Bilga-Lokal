package com.ilmmizan.bilga;

import java.time.*;
import java.util.*;

/** Calendar-only policy shared with the Dart Habit schedule contract. */
public final class ModuleReminderMath {
    public static final class Break {
        public final LocalDate from, until;
        public Break(LocalDate from, LocalDate until) { this.from=from; this.until=until; }
    }
    public static final class Schedule {
        public final String type;
        public final Set<Integer> weekdays;
        public final int interval, quota;
        public final LocalDate start, end;
        public final List<Break> pauses;
        public Schedule(String type, Set<Integer> weekdays, int interval, int quota, LocalDate start, LocalDate end, List<Break> pauses) {
            if(!Arrays.asList("weekdays","interval","weekly","monthly").contains(type) || weekdays.isEmpty() || weekdays.stream().anyMatch(d->d<1||d>7) || interval<1 || interval>365 || quota<1 || quota>(type.equals("weekly")?7:31) || (type.equals("interval")&&start==null) || (start!=null&&end!=null&&end.isBefore(start)) || pauses.size()>100) throw new IllegalArgumentException("schedule");
            for(Break p:pauses) if(p.until.isBefore(p.from)) throw new IllegalArgumentException("pause");
            this.type=type; this.weekdays=new HashSet<>(weekdays); this.interval=interval; this.quota=quota; this.start=start; this.end=end; this.pauses=new ArrayList<>(pauses);
        }
    }
    public static boolean active(LocalDate date, Schedule s) {
        if(s.start!=null&&date.isBefore(s.start) || s.end!=null&&date.isAfter(s.end)) return false;
        for(Break p:s.pauses) if(!date.isBefore(p.from)&&!date.isAfter(p.until)) return false;
        return true;
    }
    public static boolean eligible(LocalDate date, Schedule s) {
        if(!active(date,s)) return false;
        if(s.type.equals("weekdays")) return s.weekdays.contains(date.getDayOfWeek().getValue());
        if(s.type.equals("interval")) return Math.floorMod(date.toEpochDay()-s.start.toEpochDay(),(long)s.interval)==0;
        return true;
    }
    /** Jumps over long breaks instead of scanning years of individual days. */
    public static LocalDate nextEligible(LocalDate floor, Schedule s) {
        LocalDate date=s.start!=null&&floor.isBefore(s.start)?s.start:floor;
        for(int i=0;i<1024;i++) {
            if(s.end!=null&&date.isAfter(s.end)) return null;
            LocalDate jump=null;
            for(Break p:s.pauses) if(!date.isBefore(p.from)&&!date.isAfter(p.until)) { jump=p.until.plusDays(1); break; }
            if(jump!=null) { date=jump; continue; }
            if(s.type.equals("weekdays")&&!s.weekdays.contains(date.getDayOfWeek().getValue())) { date=date.plusDays(1); continue; }
            if(s.type.equals("interval")) {
                long remainder=Math.floorMod(date.toEpochDay()-s.start.toEpochDay(),(long)s.interval);
                if(remainder!=0) { date=date.plusDays(s.interval-remainder); continue; }
            }
            return date;
        }
        throw new IllegalArgumentException("schedule_complexity");
    }
    public static LocalDate periodStart(LocalDate date, String type) {
        if(type.equals("monthly")) return date.withDayOfMonth(1);
        if(type.equals("weekly")) return date.minusDays(date.getDayOfWeek().getValue()-1);
        return date;
    }
    public static LocalDate periodEnd(LocalDate date, String type) {
        LocalDate first=periodStart(date,type);
        return type.equals("monthly")?first.plusMonths(1):type.equals("weekly")?first.plusWeeks(1):first.plusDays(1);
    }
    public static boolean quotaMet(LocalDate date, Schedule s, LocalDate created, Set<LocalDate> completed) {
        if(!s.type.equals("weekly")&&!s.type.equals("monthly")) return false;
        LocalDate end=periodEnd(date,s.type); int available=0,done=0;
        for(LocalDate d=periodStart(date,s.type);d.isBefore(end);d=d.plusDays(1)) {
            if(!d.isBefore(created)&&eligible(d,s)) { available++; if(completed.contains(d)) done++; }
        }
        int required=Math.min(s.quota,available);
        return required>0&&done>=required;
    }
    /** atZone resolves spring gaps forward; fall overlaps use the first instant. */
    public static long atMillis(LocalDate date, int minute, ZoneId zone) {
        if(minute<0||minute>=1440) throw new IllegalArgumentException("minute");
        return date.atTime(minute/60,minute%60).atZone(zone).toInstant().toEpochMilli();
    }
    private ModuleReminderMath() {}
}
