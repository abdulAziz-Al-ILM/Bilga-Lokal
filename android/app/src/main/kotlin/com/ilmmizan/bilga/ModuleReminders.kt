package com.ilmmizan.bilga

import android.app.*
import android.content.*
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.time.*
import java.util.concurrent.Executors

/** Independent encrypted mirror; never reads or changes either user database. */
internal object ModuleReminders {
    const val OPEN="com.ilmmizan.bilga.MODULE_OPEN"
    const val WAKE="com.ilmmizan.bilga.MODULE_WAKE"
    const val STORE="modules"
    private const val QUIET_CHANNEL="bilga.modules.quiet.v1"
    private const val SOUND_CHANNEL="bilga.modules.sound.v1"
    private const val NOTIFICATION=903
    private val executor=Executors.newSingleThreadExecutor { r -> Thread(r,"bilga-module-reminders").apply { isDaemon=true } }
    private val alertEvents = setOf("taskDue","taskSoon","habitEvening","financeRecurring",
        "budgetNear","budgetExceeded","experienceReview","bookReading","bookCards")
    data class Candidate(val row:JSONObject,val at:Long,val key:String)
    fun rows(root:JSONObject):List<JSONObject> = root.optJSONArray("rows")?.let { a -> (0 until a.length()).map { a.getJSONObject(it) } } ?: emptyList()
    fun root(c:Context)=TodoStore.read(c,STORE) ?: JSONObject().put("v",1).put("rows",JSONArray())
    fun channel(c:Context,priority:Int=0):String {
        val manager=c.getSystemService(NotificationManager::class.java)
        val sound=TodoReminders.audible(TodoStore.read(c) ?: JSONObject())
        // A user block on the original module channel still applies on upgrade.
        val legacyBlocked=manager.getNotificationChannel(QUIET_CHANNEL)?.importance==NotificationManager.IMPORTANCE_NONE &&
            manager.getNotificationChannel(SOUND_CHANNEL)==null
        val audible=sound && !legacyBlocked
        if (audible && priority in 1..3 && TodoReminders.prioritySoundAllowed(manager,SOUND_CHANNEL)) {
            return TodoReminders.priorityChannel(c,priority)
        }
        val id=if(audible) SOUND_CHANNEL else QUIET_CHANNEL
        val importance=if(audible) NotificationManager.IMPORTANCE_HIGH else NotificationManager.IMPORTANCE_DEFAULT
        manager.createNotificationChannel(TodoReminders.reminderChannel(id,"Bilga",audible,importance))
        return id
    }
    private fun permittedChannel(c:Context,priority:Int=0):String? {
        if(!TodoReminders.enabled(c)) return null
        val id=channel(c,priority)
        return id.takeIf { TodoReminders.channelEnabled(c.getSystemService(NotificationManager::class.java),it) }
    }
    fun enabled(c:Context)=permittedChannel(c)!=null
    private fun alarm(c:Context)=PendingIntent.getBroadcast(c,812,Intent(c,ModuleReminderReceiver::class.java).setAction(WAKE),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun date(text:String)=LocalDate.parse(text)
    private fun spec(json:JSONObject):ModuleReminderMath.Schedule {
        val days=json.optJSONArray("weekdays") ?: JSONArray(listOf(1,2,3,4,5,6,7))
        val pauses=json.optJSONArray("pauses") ?: JSONArray()
        return ModuleReminderMath.Schedule(json.optString("type","weekdays"),(0 until days.length()).map { days.getInt(it) }.toSet(),json.optInt("interval",1),json.optInt("quota",1),json.optString("start").takeIf { it.isNotEmpty()&&it!="null" }?.let(::date),json.optString("end").takeIf { it.isNotEmpty()&&it!="null" }?.let(::date),(0 until pauses.length()).map { val p=pauses.getJSONObject(it);ModuleReminderMath.Break(date(p.getString("from")),date(p.getString("until"))) })
    }
    private fun scheduleFor(row:JSONObject,day:LocalDate):ModuleReminderMath.Schedule {
        val windows=row.getJSONArray("windows");require(windows.length() in 1..36501)
        var value=windows.getJSONObject(0).getJSONObject("schedule")
        for(i in 0 until windows.length()) {val w=windows.getJSONObject(i);if(!date(w.getString("from")).isAfter(day))value=w.getJSONObject("schedule")}
        return spec(value)
    }
    fun validate(row:JSONObject,review:Boolean=false) {
        require(row.getString("id").length in 1..2048 && row.getString("target").length in 1..2048 && row.getString("config").length<=1024*1024)
        if (row.has("event")) {
            require(row.getString("event") in alertEvents &&
                row.getString("kind") in setOf("task","finance","center","experience","book"))
            date(row.getString("date"))
            require(row.getInt("minute") in 0..1439 && row.optInt("cadence") in setOf(0,1,7))
            return
        }
        when(row.getString("kind")) {
            "habit" -> { require(row.getInt("minute") in 0..1439);date(row.getString("created"));scheduleFor(row,LocalDate.now());val a=row.getJSONArray("completed");require(a.length()<=400);for(i in 0 until a.length())date(a.getString(i)) }
            "finance" -> { date(row.getString("date"));require(row.getInt("minute") in 0..1439) }
            "review" -> require(review && row.getString("id").startsWith("bilga-review-module-") && row.getLong("at")>0)
            else -> error("module_kind")
        }
    }
    private fun fired(root:JSONObject,id:String,key:String):Boolean {val a=root.optJSONObject("delivered")?.optJSONArray(id) ?: return false;return (0 until a.length()).any { a.getString(it)==key }}
    fun next(root:JSONObject,row:JSONObject,now:Long):Candidate? {
        val id=row.getString("id")
        if (row.has("event")) {
            val zone = ZoneId.systemDefault()
            val minute = row.getInt("minute")
            val cadence = row.optInt("cadence")
            var day = date(row.getString("date"))
            val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
            if (cadence > 0 && day.isBefore(today)) {
                val difference = java.time.temporal.ChronoUnit.DAYS.between(day, today)
                day = day.plusDays((difference / cadence) * cadence)
            }
            val first = ModuleReminderMath.atMillis(day, minute, zone)
            val at = when {
                row.optBoolean("immediate") -> row.getLong("notBefore")
                row.optLong("at") > 0L -> row.getLong("at")
                else -> first
            }
            val key = if (cadence > 0) "repeat:$day" else "once:alert"
            if (!fired(root,id,key) && at >= row.optLong("notBefore")) {
                return Candidate(row,at,key)
            }
            if (cadence > 0) {
                val later = day.plusDays(cadence.toLong())
                return Candidate(row,ModuleReminderMath.atMillis(later,minute,zone),"repeat:$later")
            }
            return null
        }
        if(row.getString("kind")!="habit") {
            val at=if(row.getString("kind")=="finance")ModuleReminderMath.atMillis(date(row.getString("date")),row.getInt("minute"),ZoneId.systemDefault()) else row.getLong("at")
            val key=if(row.getString("kind")=="finance")"once:${row.getString("date")}/${row.getInt("minute")}" else "once:$at"
            return if(!fired(root,id,key)&&at>=row.optLong("notBefore"))Candidate(row,at,key) else null
        }
        val zone=ZoneId.systemDefault();val today=Instant.ofEpochMilli(now).atZone(zone).toLocalDate();val created=date(row.getString("created"));val minute=row.getInt("minute")
        val a=row.getJSONArray("completed");val completed=(0 until a.length()).map { date(a.getString(it)) }.toSet()
        val lower=Instant.ofEpochMilli(row.optLong("notBefore")).atZone(zone).toLocalDate()
        var day=maxOf(today,created,lower)
        for(i in 0 until 1024) {
            val s=scheduleFor(row,day)
            val windows=row.getJSONArray("windows")
            val change=(0 until windows.length()).map { date(windows.getJSONObject(it).getString("from")) }.filter { it.isAfter(day) }.minOrNull()
            val eligible=ModuleReminderMath.nextEligible(day,s)
            day=if(change!=null&&(eligible==null||change.isBefore(eligible)))change else eligible?:return null
            val actual=scheduleFor(row,day)
            if(!ModuleReminderMath.eligible(day,actual)) {day=day.plusDays(1);continue}
            val key="$day/$minute";val at=ModuleReminderMath.atMillis(day,minute,zone)
            if(at<row.optLong("notBefore") || fired(root,id,key) || completed.contains(day)) {day=day.plusDays(1);continue}
            if(ModuleReminderMath.quotaMet(day,actual,actual.start?:created,completed)) {day=minOf(ModuleReminderMath.periodEnd(day,actual.type),change?:LocalDate.MAX);continue}
            return Candidate(row,at,key)
        }
        return null
    }
    @Synchronized fun publish(c:Context,incoming:List<Map<String,Any?>>,labels:Map<String,String>) {
        require(incoming.size<=5000)
        val old=root(c);val previous=rows(old).associateBy { it.getString("id") };val ids=mutableSetOf<String>();val values=JSONArray();val now=System.currentTimeMillis()
        for(item in incoming){val row=JSONObject(item);validate(row);val id=row.getString("id");require(ids.add(id));val p=previous[id];val unchanged=p?.optString("config")==row.getString("config") && p?.optJSONArray("completed")?.toString()==row.optJSONArray("completed")?.toString();row.put("notBefore",if(unchanged)p!!.optLong("notBefore",now) else now);values.put(row)}
        val retained=JSONObject();val delivered=old.optJSONObject("delivered")?:JSONObject()
        for(id in ids)if(delivered.has(id))retained.put(id,delivered.getJSONArray(id))
        val updated=JSONObject().put("v",1).put("rows",values).put("labels",JSONObject(labels)).put("delivered",retained)
        TodoStore.write(c,updated,STORE)
        val next=rows(updated).associateBy { it.getString("id") }
        for((id,p) in previous) {
            val row=next[id];val a=row?.optJSONArray("completed");val doneToday=a!=null&&(0 until a.length()).any { a.getString(it)==LocalDate.now().toString() }
            if(row==null||row.getString("config")!=p.getString("config")||doneToday)c.getSystemService(NotificationManager::class.java).cancel(id,NOTIFICATION)
        }
        schedule(c,updated)
    }
    @Synchronized fun schedule(c:Context,value:JSONObject=root(c)) {
        val manager=c.getSystemService(AlarmManager::class.java);val now=System.currentTimeMillis()
        val at=rows(value).mapNotNull { next(value,it,now)?.at }.minOrNull()
        if(at==null){manager.cancel(alarm(c));return}
        try {if(TodoReminders.exact(c))manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,maxOf(now+1000,at),alarm(c))else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,maxOf(now+1000,at),alarm(c))}
        catch(_:SecurityException){manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,maxOf(now+1000,at),alarm(c))}
    }
    @Synchronized fun fire(c:Context) {
        val root=root(c);val now=System.currentTimeMillis();val due=rows(root).mapNotNull { next(root,it,now) }.filter { it.at<=now }
        val delivered=root.optJSONObject("delivered")?:JSONObject().also { root.put("delivered",it) }
        for(item in due){val id=item.row.getString("id");val old=delivered.optJSONArray(id)?:JSONArray();val keep=JSONArray();val cutoff=LocalDate.now().minusDays(35).toString();for(i in 0 until old.length()){val key=old.getString(i);if(key.startsWith("once:")||key.removePrefix("repeat:").take(10)>=cutoff)keep.put(key)};keep.put(item.key);delivered.put(id,keep)}
        TodoStore.write(c,root,STORE) // Claim delivery before posting; reboot cannot replay it.
        val channels=mutableMapOf<Int,String?>()
        for(item in due){val row=item.row;val labels=root.optJSONObject("labels")?:JSONObject();val kind=row.getString("kind");val label=labels.optString(row.optString("event").ifEmpty { if(kind=="finance")"financeDebt" else "habit" },"Bilga");val text=labels.optString("message","Bilga")
            val priority=if(kind=="task") row.optInt("priority").coerceIn(0,3) else 0
            if(!channels.containsKey(priority)) channels[priority]=permittedChannel(c,priority)
            val channel=channels[priority] ?: continue
            val open=Intent(c,MainActivity::class.java).setAction(OPEN).setData(Uri.parse("bilga-module://$kind/${Uri.encode(row.getString("target"))}/${Uri.encode(row.optString("event"))}")).putExtra("module_kind",if(kind=="review")"habit" else kind).putExtra("module_target",row.getString("target")).putExtra("module_event",row.optString("event",if(kind=="finance")"financeDebt" else ""))
            val intent=PendingIntent.getActivity(c,813,open,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification=Notification.Builder(c,channel).setSmallIcon(R.drawable.todo_notification).setContentTitle("Bilga · $label").setContentText(text).setVisibility(Notification.VISIBILITY_PRIVATE).setGroup("bilga.module.$kind").setCategory(Notification.CATEGORY_REMINDER).setOnlyAlertOnce(true).setAutoCancel(true).setContentIntent(intent).build()
            c.getSystemService(NotificationManager::class.java).notify(row.getString("id"),NOTIFICATION,notification)
        }
        schedule(c,root)
    }
    fun enqueue(action: () -> Unit) { executor.execute(action) }
    fun receive(c:Context,intent:Intent,pending:BroadcastReceiver.PendingResult){executor.execute {try{if(intent.action==WAKE)fire(c)else schedule(c)}catch(_:Exception){/* Keep encrypted state; never use plaintext/DB fallback. */}finally{pending.finish()}}}
}
class ModuleReminderReceiver:BroadcastReceiver(){override fun onReceive(c:Context,intent:Intent){ModuleReminders.receive(c,intent,goAsync())}}
