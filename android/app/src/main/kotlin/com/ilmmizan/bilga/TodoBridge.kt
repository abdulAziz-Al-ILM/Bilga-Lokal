package com.ilmmizan.bilga

import android.app.*
import android.appwidget.AppWidgetManager
import android.content.*
import android.os.*
import android.net.Uri
import android.provider.Settings
import io.flutter.plugin.common.*
import org.json.*
import java.util.UUID

class TodoBridge(private val activity: Activity,messenger: BinaryMessenger) {
    private val channel=MethodChannel(messenger,"bilga/todo")
    private var launch: Map<String,Any?>?=null
    private var reply: Pair<Int,ResultReceiver>?=null
    init {
        TodoReminders.bridge=this; TodoWidget.observe(activity); receive(activity.intent)
        channel.setMethodCallHandler { call,result ->
            try {
                synchronized(TodoReminders) { when(call.method) {
                    "consumeLaunch" -> { result.success(launch); launch=null }
                    "reviewNotification" -> {
                        // Device-test probe: only this isolated debug package,
                        // only its own synthetic notification. Never available
                        // to production, even a production debug installation.
                        require(activity.packageName=="com.ilmmizan.bilga.review" &&
                            activity.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE!=0)
                        val tag=call.argument<String>("tag") ?: error("no_tag")
                        val source=call.argument<String>("sourceFixture")
                        val cached=TodoReminders.tasks(TodoStore.read(activity) ?: JSONObject())
                        val fixture=cached.firstOrNull { it.optString("id")==source && source?.startsWith("bilga-review-notification-")==true }
                        val generated=cached.firstOrNull { it.optString("id")==tag }
                        require(tag.startsWith("bilga-review-notification-") ||
                            (fixture!=null && generated!=null && fixture.optString("series").isNotEmpty() &&
                             generated.optString("series")==fixture.optString("series") &&
                             generated.optLong("sequence")>fixture.optLong("sequence")))
                        val active=activity.getSystemService(NotificationManager::class.java).activeNotifications
                            .firstOrNull { it.tag==tag && it.id==901 }
                        when(call.argument<String>("operation")) {
                            "exists" -> result.success(active!=null)
                            "metadata" -> result.success(mapOf("hasTitle" to (generated?.has("title") ?: false),
                                "widgetAllowed" to (generated?.optBoolean("widgetAllowed") ?: false)))
                            "complete" -> {
                                val action=active?.notification?.actions?.firstOrNull() ?: error("no_action")
                                action.actionIntent.send()
                                result.success(true)
                            }
                            else -> result.notImplemented()
                        }
                    }
                    "state" -> {
                        val root=TodoStore.read(activity) ?: JSONObject()
                        val settings=TodoReminders.settings(root)
                        result.success(mapOf("settings" to map(settings),"widgets" to map(root.optJSONObject("widgets") ?: JSONObject()),
                            "sqlEpoch" to root.optLong("sqlEpoch"),"notifications" to TodoReminders.enabled(activity),"exact" to TodoReminders.exact(activity),
                            "overlay" to Settings.canDrawOverlays(activity),
                            "batteryRestricted" to activity.getSystemService(ActivityManager::class.java).let { Build.VERSION.SDK_INT>=28 && it.isBackgroundRestricted },
                            "channelSound" to (activity.getSystemService(NotificationManager::class.java).getNotificationChannel("bilga.todo.sound.v1")?.importance ?: NotificationManager.IMPORTANCE_HIGH),
                            "channelQuiet" to (activity.getSystemService(NotificationManager::class.java).getNotificationChannel("bilga.todo.quiet.v1")?.importance ?: NotificationManager.IMPORTANCE_HIGH)))
                    }
                    "publish" -> {
                        val root=TodoStore.read(activity) ?: JSONObject()
                        if((call.argument<Number>("sqlEpoch")?.toLong() ?: 0)!=root.optLong("sqlEpoch")) {
                            result.success(false); android.os.Handler(android.os.Looper.getMainLooper()).post { changed() };return@setMethodCallHandler
                        }
                        val old=TodoReminders.tasks(root).associateBy { it.getString("id") }
                        val incoming=call.argument<List<Map<String,Any?>>>("tasks") ?: emptyList()
                        require(incoming.size<=100000)
                        val ids=mutableSetOf<String>()
                        val tasks=JSONArray()
                        for(row in incoming) {
                            val task=JSONObject(row); val id=task.getString("id"); require(id.length in 1..1024 && ids.add(id))
                            task.put("actionToken",old[id]?.takeIf { it.optString("version")==task.optString("version") }?.optString("actionToken")?.takeIf { it.isNotEmpty() } ?: UUID.randomUUID().toString())
                            val r=task.optJSONObject("reminder"); val previous=old[id]?.optJSONObject("reminder")
                            if(r!=null) {
                                if(previous!=null && r.optString("revision")==previous.optString("revision")) {
                                    // Native delivery/snooze wins until its durable event reaches SQLCipher.
                                    task.put("reminder",previous)
                                } else r.put("nonce",UUID.randomUUID().toString())
                            }
                            tasks.put(task)
                        }
                        val next=(0 until tasks.length()).map { tasks.getJSONObject(it) }.associateBy { it.getString("id") }
                        for((id,task) in old) {
                            val current=next[id]
                            if(current==null || current.optBoolean("done") || current.optJSONObject("reminder")==null ||
                                current.optJSONObject("reminder")?.optString("revision")!=task.optJSONObject("reminder")?.optString("revision")) {
                                activity.getSystemService(NotificationManager::class.java).cancel(id,901)
                                activity.stopService(Intent(activity,TodoOverlayService::class.java))
                            }
                        }
                        val events=root.optJSONObject("events")
                        if(events!=null) for(id in events.keys().asSequence().toList()) {
                            if(next[id]?.optJSONObject("reminder")?.optString("revision")!=events.getJSONObject(id).optString("revision")) events.remove(id)
                        }
                        root.remove("blockedTask")
                        root.put("actionUntil",call.argument<Number>("actionUntil")?.toLong() ?: 0)
                            .put("actionWall",System.currentTimeMillis()).put("actionElapsed",SystemClock.elapsedRealtime())
                            .put("actionBoot",Settings.Global.getInt(activity.contentResolver,Settings.Global.BOOT_COUNT,-1))
                        root.put("tasks",tasks).put("redacted",call.argument<Boolean>("redacted")!=false)
                            .put("labels",JSONObject(call.argument<Map<String,String>>("labels") ?: emptyMap<String,String>()))
                            .put("language",call.argument<String>("language") ?: "uz")
                            .put("background",call.argument<Int>("background")).put("foreground",call.argument<Int>("foreground"))
                            .put("dark",call.argument<Boolean>("dark")!=false)
                        TodoStore.write(activity,root); TodoWidget.refresh(activity); TodoReminders.schedule(activity,root)
                        if(root.optBoolean("redacted",true)) TodoReminders.redact(activity)
                        result.success(null)
                    }
                    "invalidateWidgetPermission" -> {
                        val root=TodoStore.read(activity)
                        if(root!=null) {
                            for(task in TodoReminders.tasks(root)) if(task.optString("id")==call.arguments) {
                                task.put("widgetAllowed",false)
                                if(!TodoReminders.settings(root).optBoolean("showTitles")) task.remove("title")
                            }
                            root.put("sqlEpoch",root.optLong("sqlEpoch")+1)
                            TodoStore.write(activity,root);TodoWidget.refresh(activity)
                        }
                        result.success(null)
                    }
                    "events" -> {
                        val events=TodoStore.read(activity)?.optJSONObject("events") ?: JSONObject()
                        result.success(events.keys().asSequence().map { map(events.getJSONObject(it)) }.toList())
                    }
                    "ack" -> {
                        val root=TodoStore.read(activity)
                        if(root!=null) {
                            val events=root.optJSONObject("events") ?: JSONObject()
                            val accepted=call.arguments as? List<*> ?: emptyList<Any>()
                            for(id in events.keys().asSequence().toList()) if(events.getJSONObject(id).optString("eventId") in accepted) events.remove(id)
                            TodoStore.write(activity,root)
                        }; result.success(null)
                    }
                    "snooze" -> result.success(TodoReminders.snooze(activity,call.argument<String>("id")!!,call.argument<String>("at")!!))
                    "settings" -> {
                        val root=TodoStore.read(activity) ?: JSONObject()
                        val options=JSONObject(call.arguments as? Map<*,*> ?: emptyMap<Any,Any>())
                        root.put("settings",options)
                        // Revocation clears app-owned title copies immediately.
                        if(!options.optBoolean("showTitles")) for(task in TodoReminders.tasks(root)) task.remove("title")
                        TodoStore.write(activity,root); TodoReminders.redact(activity)
                        if(!options.optBoolean("enabled",true)) for(task in TodoReminders.tasks(root)) activity.getSystemService(NotificationManager::class.java).cancel(task.optString("id"),901)
                        TodoReminders.schedule(activity,root); result.success(null)
                    }
                    "redact" -> {
                        val root=TodoStore.read(activity)
                        if(root!=null) { root.put("redacted",true); TodoStore.write(activity,root); TodoReminders.redact(activity) }
                        result.success(null)
                    }
                    "permission" -> {
                        when(call.arguments as? String) {
                            "notifications" -> if(Build.VERSION.SDK_INT>=33) activity.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),712)
                                else activity.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE,activity.packageName))
                            "exact" -> if(Build.VERSION.SDK_INT>=31) activity.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,Uri.parse("package:${activity.packageName}")))
                            "overlay" -> activity.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,Uri.parse("package:${activity.packageName}")))
                            "battery" -> activity.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            "channels" -> activity.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE,activity.packageName))
                        }; result.success(null)
                    }
                    "saveWidget" -> {
                        val id=call.argument<Int>("id") ?: -1; require(id==reply?.first && TodoWidget.ids(activity).contains(id))
                        val config=JSONObject(call.arguments as? Map<*,*> ?: emptyMap<Any,Any>())
                        require(config.optString("source") in listOf("today","upcoming","overdue"))
                        val root=TodoStore.read(activity) ?: JSONObject()
                        val configs=root.optJSONObject("widgets") ?: JSONObject().also { root.put("widgets",it) }
                        configs.put(id.toString(),config); TodoStore.write(activity,root); TodoWidget.refresh(activity); TodoReminders.schedule(activity,root)
                        result.success(null)
                    }
                    "finishWidget", "cancelWidget" -> {
                        val current=reply ?: error("no_config"); reply=null
                        current.second.send(if(call.method=="finishWidget") Activity.RESULT_OK else Activity.RESULT_CANCELED,null)
                        result.success(null); activity.moveTaskToBack(true)
                    }
                    "requestPin" -> {
                        val manager=AppWidgetManager.getInstance(activity)
                        result.success(manager.isRequestPinAppWidgetSupported && manager.requestPinAppWidget(android.content.ComponentName(activity,TodoWidget::class.java),null,null))
                    }
                    else -> result.notImplemented()
                }
            } } catch (_: Exception) { result.error("todo_unavailable","To-Do unavailable",null) }
        }
    }
    fun receive(intent: Intent?) {
        val action=intent?.getStringExtra("todo_action") ?: return
        if(action !in listOf("open","create","list","done","snooze","configure")) return
        val id=intent.getIntExtra("todo_widget",-1)
        if(action=="configure") {
            if(!TodoWidget.ids(activity).contains(id)) return
            val receiver=if(Build.VERSION.SDK_INT>=33) intent.getParcelableExtra("todo_reply",ResultReceiver::class.java)
                else @Suppress("DEPRECATION") intent.getParcelableExtra<ResultReceiver>("todo_reply")
            if(receiver==null) return
            reply=id to receiver
        }
        launch=mapOf("action" to action,"id" to intent.getStringExtra("todo_id")?.take(1024),"widgetId" to id)
        channel.invokeMethod("launch",null)
    }
    fun due(id: String) { channel.invokeMethod("due",id) }
    fun changed() { channel.invokeMethod("changed",null) }
    fun ready() { changed(); channel.invokeMethod("launch",null) }
    fun close() { if(TodoReminders.bridge===this) TodoReminders.bridge=null; channel.setMethodCallHandler(null) }
    private fun map(value: JSONObject): Map<String,Any?> = value.keys().asSequence().associateWith { key ->
        when(val v=value.get(key)) { JSONObject.NULL -> null; is JSONObject -> map(v); else -> v }
    }
}
