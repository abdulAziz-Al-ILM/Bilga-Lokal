package com.ilmmizan.bilga

import android.app.*
import android.content.*
import android.os.Build
import android.net.Uri
import android.provider.Settings
import org.json.JSONObject
import org.json.JSONArray
import java.time.*
import java.util.UUID

internal object TodoReminders {
    const val WAKE="com.ilmmizan.bilga.TODO_WAKE"
    const val ACTION="com.ilmmizan.bilga.TODO_ACTION"
    const val OPEN="com.ilmmizan.bilga.TODO_OPEN"
    var foreground=false
    var bridge: TodoBridge?=null
    fun items(root: JSONObject) = root.optJSONArray("tasks") ?: JSONArray()
    fun tasks(root: JSONObject): List<JSONObject> = items(root).let { a -> (0 until a.length()).map { a.getJSONObject(it) } }
    fun settings(root: JSONObject) = root.optJSONObject("settings") ?: JSONObject()
    fun label(root: JSONObject,key: String) = root.optJSONObject("labels")?.optString(key)?.takeIf { it.isNotEmpty() } ?: "Bilga"
    fun locked(c: Context) = c.getSystemService(KeyguardManager::class.java).isDeviceLocked
    fun private(c: Context,root: JSONObject) = locked(c) || root.optBoolean("redacted",true)
    fun exact(c: Context) = Build.VERSION.SDK_INT<31 || c.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    fun enabled(c: Context): Boolean = c.getSystemService(NotificationManager::class.java).areNotificationsEnabled() &&
        (Build.VERSION.SDK_INT<33 || c.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)==android.content.pm.PackageManager.PERMISSION_GRANTED)
    fun audible(c: Context,root: JSONObject): Boolean {
        val options=settings(root)
        val canSpeak=!private(c,root) && (foreground || exact(c)) && (Build.VERSION.SDK_INT<37 || foreground)
        return options.optBoolean("sound",true) || (options.optBoolean("tts") && !canSpeak)
    }
    fun permitted(c: Context,root: JSONObject): Boolean {
        if(!enabled(c)) return false
        val sound=audible(c,root)
        return c.getSystemService(NotificationManager::class.java).getNotificationChannel(if(sound) "bilga.todo.sound.v1" else "bilga.todo.quiet.v1")?.importance!=NotificationManager.IMPORTANCE_NONE
    }
    fun alarm(c: Context) = PendingIntent.getBroadcast(c,810,Intent(c,TodoReceiver::class.java).setAction(WAKE),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    @Synchronized fun schedule(c: Context, root: JSONObject? = TodoStore.read(c)) {
        val manager=c.getSystemService(AlarmManager::class.java)
        if (root==null) { manager.cancel(alarm(c)); return }
        val now=System.currentTimeMillis()
        val pending=pendingTimes(root)
        val widget=TodoWidget.ids(c).isNotEmpty()
        val transitions=if(widget) tasks(root).filter { !it.optBoolean("done") }.mapNotNull { TodoTime.instant(it.optString("due"))?.takeIf { d -> d>now } } else emptyList()
        val midnight=Instant.ofEpochMilli(now).atZone(ZoneId.systemDefault()).toLocalDate().plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val next=(pending+transitions+if(widget) listOf(midnight) else emptyList()).minOrNull()
        if (next==null) { manager.cancel(alarm(c)); return }
        val at=maxOf(now+1000,next)
        try {
            if(exact(c)) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,alarm(c))
            else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,alarm(c))
        } catch (_: SecurityException) { manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,alarm(c)) }
    }
    internal fun pendingTimes(root:JSONObject):List<Long> =
        if(!settings(root).optBoolean("enabled",true)) emptyList() else tasks(root).filter {
            it.optString("id")!=root.optString("blockedTask")
        }.mapNotNull {
            val r=it.optJSONObject("reminder")
            if(it.optBoolean("done") || r==null || r.optBoolean("fired")) null else TodoTime.instant(r.optString("at"))
        }
    fun event(root: JSONObject,task: JSONObject,kind: String) {
        val reminder=task.getJSONObject("reminder")
        val events=root.optJSONObject("events") ?: JSONObject().also { root.put("events",it) }
        events.put(task.getString("id"),JSONObject().put("eventId",UUID.randomUUID().toString()).put("id",task.getString("id"))
            .put("revision",reminder.getString("revision")).put("at",reminder.getString("at")).put("kind",kind))
    }
    /** Persist delivery before posting, so repeated broadcasts cannot duplicate it. */
    @Synchronized fun fire(c: Context) {
        val root=TodoStore.read(c) ?: return
        val due=claim(root,System.currentTimeMillis())
        TodoStore.write(c,root)
        for(task in due) {
            if(permitted(c,root)) c.getSystemService(NotificationManager::class.java).notify(task.getString("id"),901,notification(c,root,task))
            if(foreground) bridge?.due(task.getString("id"))
            val options=settings(root)
            val wantsPanel=options.optBoolean("overlay") && !foreground && Settings.canDrawOverlays(c)
            val wantsSpeech=options.optBoolean("tts") && (Build.VERSION.SDK_INT<37 || foreground)
            if((foreground || exact(c)) && permitted(c,root) && !private(c,root) && (wantsPanel || wantsSpeech)) {
                try { c.startForegroundService(Intent(c,TodoOverlayService::class.java).putExtra("todo_id",task.getString("id"))) }
                catch (_: Exception) { /* Normal action notification already posted. */ }
            }
        }
        TodoWidget.refresh(c); schedule(c,root)
    }
    internal fun claim(root: JSONObject,now: Long): List<JSONObject> {
        val due=if(settings(root).optBoolean("enabled",true)) tasks(root).filter { it.optString("id")!=root.optString("blockedTask") && TodoTime.dueNow(it,now) } else emptyList()
        for(task in due) {
            task.getJSONObject("reminder").put("fired",true)
            event(root,task,"fired")
        }
        return due
    }
    fun channel(c: Context,sound: Boolean): String {
        val id=if(sound) "bilga.todo.sound.v1" else "bilga.todo.quiet.v1"
        val ch=NotificationChannel(id,c.getString(R.string.tw_reminders),NotificationManager.IMPORTANCE_HIGH)
        ch.description=c.getString(R.string.tw_limits)
        if(!sound) { ch.setSound(null,null); ch.enableVibration(false) }
        ch.lockscreenVisibility=Notification.VISIBILITY_PRIVATE
        c.getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        return id
    }
    fun notification(c: Context,root: JSONObject,task: JSONObject, ongoing: Boolean=false,snoozeMenu: Boolean=false): Notification {
        val id=task.getString("id"); val r=task.getJSONObject("reminder")
        val generic=label(root,"reminderMessage")
        val text=if(!private(c,root) && settings(root).optBoolean("showTitles")) task.optString("title").ifBlank { generic } else generic
        val public=Notification.Builder(c,channel(c,false)).setSmallIcon(R.drawable.todo_notification).setContentTitle("Bilga").setContentText(generic).build()
        return Notification.Builder(c,channel(c,audible(c,root)))
            .setSmallIcon(R.drawable.todo_notification).setContentTitle("Bilga · ${label(root,"todos")}").setContentText(text)
            .setVisibility(Notification.VISIBILITY_PRIVATE).setPublicVersion(public).setCategory(Notification.CATEGORY_REMINDER)
            .setOnlyAlertOnce(true).setAutoCancel(true).setOngoing(ongoing)
            .setContentIntent(TodoHandoff.pending(c,"open",id))
            .addAction(Notification.Action.Builder(null,label(root,"reminderDone"),TodoNativeActions.pending(c,-1,task,"done")).build())
            .addAction(Notification.Action.Builder(null,label(root,"reminderSnooze"),TodoNativeActions.pending(c,-1,task,"reminderMenu")).build())
            .apply {
                if(snoozeMenu) {
                    val choices=android.widget.RemoteViews(c.packageName,R.layout.todo_widget_snooze)
                    choices.setInt(R.id.todo_snooze_root,"setBackgroundColor",WidgetTheme.background(c))
                    for((view,pair) in listOf(R.id.todo_snooze5 to (5 to "snooze5"),R.id.todo_snooze10 to (10 to "snooze10"),R.id.todo_snooze30 to (30 to "snooze30"),R.id.todo_snooze60 to (60 to "snooze60"),R.id.todo_snoozeTomorrow to (-1 to "tomorrow"))) {
                        choices.setTextViewText(view,label(root,pair.second))
                        choices.setTextColor(view,WidgetTheme.foreground(c))
                        choices.setOnClickPendingIntent(view,TodoNativeActions.pending(c,-1,task,"snooze",pair.first))
                    }
                    setStyle(Notification.DecoratedCustomViewStyle())
                    setCustomBigContentView(choices)
                    setCustomHeadsUpContentView(choices)
                    setSilent(true)
                }
            }
            .setDeleteIntent(PendingIntent.getBroadcast(c,0,Intent(c,TodoReceiver::class.java).setAction(ACTION)
                .setData(Uri.parse("bilga-todo://dismiss/${Uri.encode(id)}/${r.optString("nonce")}"))
                .putExtra("todo_id",id).putExtra("nonce",r.optString("nonce")),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)).build()
    }
    @Synchronized fun snooze(c: Context,id: String,at: String,nonce: String?=null): Boolean {
        require((TodoTime.instant(at) ?: 0)>System.currentTimeMillis())
        val root=TodoStore.read(c) ?: return false
        val task=tasks(root).firstOrNull { it.optString("id")==id && !it.optBoolean("done") } ?: return false
        val r=task.optJSONObject("reminder") ?: return false
        if(nonce!=null && nonce!=r.optString("nonce")) return false
        r.put("at",at).put("fired",false).put("nonce",UUID.randomUUID().toString())
        event(root,task,"snooze"); TodoStore.write(c,root)
        c.getSystemService(NotificationManager::class.java).cancel(id,901)
        c.stopService(Intent(c,TodoOverlayService::class.java)); schedule(c,root)
        bridge?.changed(); return true
    }
    @Synchronized fun redact(c: Context) {
        val root=TodoStore.read(c) ?: return
        for(task in tasks(root).filter { it.optJSONObject("reminder")?.optBoolean("fired")==true }) {
            if(enabled(c) && c.getSystemService(NotificationManager::class.java).activeNotifications.any { it.tag==task.optString("id") && it.id==901 }) {
                c.getSystemService(NotificationManager::class.java).notify(task.getString("id"),901,notification(c,root,task))
            }
        }
        c.stopService(Intent(c,TodoOverlayService::class.java)); TodoWidget.refresh(c)
    }
}

class TodoReceiver: BroadcastReceiver() {
    override fun onReceive(c: Context,intent: Intent) {
        try {
            when(intent.action) {
                TodoReminders.WAKE -> TodoReminders.fire(c)
                TodoReminders.ACTION -> c.stopService(Intent(c,TodoOverlayService::class.java))
                Intent.ACTION_SCREEN_OFF -> TodoReminders.redact(c)
                else -> { TodoWidget.refresh(c); TodoReminders.schedule(c) }
            }
        } catch (_: Exception) { /* No plaintext or DB fallback on a locked/broken store. */ }
    }
}
