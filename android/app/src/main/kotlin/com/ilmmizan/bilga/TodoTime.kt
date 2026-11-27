package com.ilmmizan.bilga

import org.json.JSONObject
import java.time.*
import java.time.temporal.ChronoUnit

internal object TodoTime {
    fun instant(text: String, zone: ZoneId = ZoneId.systemDefault()): Long? = try {
        try { OffsetDateTime.parse(text).toInstant().toEpochMilli() }
        catch (_: Exception) { LocalDateTime.parse(text).atZone(zone).toInstant().toEpochMilli() }
    } catch (_: Exception) { null }
    fun state(task: JSONObject, now: Long, zone: ZoneId = ZoneId.systemDefault()): String {
        if (task.optBoolean("done")) return "completed"
        val due=instant(task.optString("due"),zone) ?: return "neutral"
        if (due<=now) return "overdue"
        val days=ChronoUnit.DAYS.between(Instant.ofEpochMilli(now).atZone(zone).toLocalDate(),Instant.ofEpochMilli(due).atZone(zone).toLocalDate())
        return if (days>=3) "green" else if (days==2L) "yellow" else "red"
    }
    fun snooze(minutes: Int, now: Long = System.currentTimeMillis(), zone: ZoneId = ZoneId.systemDefault()): String {
        require(minutes in listOf(5,10,30,60,-1))
        val time=Instant.ofEpochMilli(now).atZone(zone)
        // Tomorrow keeps local clock time, including 23/25-hour DST days.
        return (if (minutes==-1) time.plusDays(1) else time.plusMinutes(minutes.toLong())).toOffsetDateTime().toString()
    }
    fun dueNow(task: JSONObject, now: Long): Boolean {
        val reminder=task.optJSONObject("reminder") ?: return false
        val at=instant(reminder.optString("at")) ?: return false
        return !task.optBoolean("done") && !reminder.optBoolean("fired") && at<=now
    }
}
