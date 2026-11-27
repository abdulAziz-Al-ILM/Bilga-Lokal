import com.ilmmizan.bilga.ModuleReminderMath;
import java.time.*;
import java.util.*;
class ModuleReminderMathCheck {
 static LocalDate d(String x){return LocalDate.parse(x);}
 public static void main(String[] args){
  var all=new HashSet<Integer>(Arrays.asList(1,2,3,4,5,6,7));
  var interval=new ModuleReminderMath.Schedule("interval",all,2,1,d("2024-02-28"),d("2024-03-31"),List.of());
  assert ModuleReminderMath.nextEligible(d("2024-02-29"),interval).equals(d("2024-03-01"));
  var paused=new ModuleReminderMath.Schedule("weekdays",Set.of(1),1,1,d("2020-01-01"),null,List.of(new ModuleReminderMath.Break(d("2020-01-01"),d("2040-01-01"))));
  assert ModuleReminderMath.nextEligible(d("2026-11-16"),paused).getYear()==2040;
  var quota=new ModuleReminderMath.Schedule("weekly",all,1,3,d("2026-11-16"),null,List.of(new ModuleReminderMath.Break(d("2026-11-18"),d("2026-11-20"))));
  assert !ModuleReminderMath.quotaMet(d("2026-11-16"),quota,d("2026-11-16"),Set.of(d("2026-11-16"),d("2026-11-17"),d("2026-11-18")));
  assert ModuleReminderMath.quotaMet(d("2026-11-16"),quota,d("2026-11-16"),Set.of(d("2026-11-16"),d("2026-11-17"),d("2026-11-21")));
  var monthly=new ModuleReminderMath.Schedule("monthly",all,1,31,d("2024-02-27"),null,List.of());
  assert ModuleReminderMath.quotaMet(d("2024-02-29"),monthly,d("2024-02-27"),Set.of(d("2024-02-27"),d("2024-02-28"),d("2024-02-29")));
  ZoneId ny=ZoneId.of("America/New_York");
  assert Instant.ofEpochMilli(ModuleReminderMath.atMillis(d("2026-03-08"),150,ny)).atZone(ny).getHour()==3;
  assert Instant.ofEpochMilli(ModuleReminderMath.atMillis(d("2026-11-01"),90,ny)).atZone(ny).getOffset().equals(ZoneOffset.ofHours(-4));
  assert ModuleReminderMath.atMillis(d("2026-03-09"),150,ny)-ModuleReminderMath.atMillis(d("2026-03-08"),150,ny)==23L*3600000;
  System.out.println("PASS Java reminder policy: leap/interval, long pause jump, actual quotas, partial months, DST gap/overlap");
 }
}
