package com.ilmmizan.bilga

import android.app.*
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

internal class ModuleReminderBridge(private val activity:Activity,messenger:BinaryMessenger) {
    private val channel=MethodChannel(messenger,"bilga/modules")
    private var pending:Map<String,String>?=null
    private val main = android.os.Handler(android.os.Looper.getMainLooper())
    companion object { private var current:ModuleReminderBridge?=null }
    init {
        current=this
        // An interrupted isolated fixture cannot leave its synthetic alarm cache active.
        if(review() && TodoStore.file(activity,"modules-review-original").baseFile.exists()) restoreReview()
        receive(activity.intent)
        channel.setMethodCallHandler { call,result ->
            try {
                when(call.method) {
                    "publish" -> {
                        val rows = call.argument<List<Map<String,Any?>>>("rows") ?: emptyList()
                        val labels = call.argument<Map<String,String>>("labels") ?: emptyMap()
                        ModuleReminders.enqueue {
                            try {
                                ModuleReminders.publish(activity.applicationContext, rows, labels)
                                main.post { result.success(null) }
                            } catch (e:Exception) {
                                main.post { result.error("module_reminder",e.javaClass.simpleName,null) }
                            }
                        }
                    }
                    "state" -> result.success(mapOf("notifications" to ModuleReminders.enabled(activity),"exact" to TodoReminders.exact(activity),"batteryRestricted" to (Build.VERSION.SDK_INT>=28 && activity.getSystemService(ActivityManager::class.java).isBackgroundRestricted)))
                    "notifications" -> {if(Build.VERSION.SDK_INT>=33&&activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)activity.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),756);result.success(null)}
                    "settings" -> {activity.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE,activity.packageName));result.success(null)}
                    "exact" -> {if(Build.VERSION.SDK_INT>=31&&!TodoReminders.exact(activity))activity.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,Uri.parse("package:${activity.packageName}")));result.success(null)}
                    "consumeLaunch" -> {result.success(pending);pending=null}
                    "reviewBegin" -> {
                        check(review());check(!TodoStore.file(activity,"modules-review-original").baseFile.exists())
                        TodoStore.write(activity,ModuleReminders.root(activity),"modules-review-original")
                        result.success(null)
                    }
                    "reviewPublish" -> {
                        check(review()&&TodoStore.file(activity,"modules-review-original").baseFile.exists())
                        val id=call.argument<String>("id")?:error("fixture_id");check(id.startsWith("bilga-review-module-"))
                        val at=call.argument<Number>("at")?.toLong()?:error("fixture_time");check(at>System.currentTimeMillis()&&at<System.currentTimeMillis()+120000)
                        val row=JSONObject().put("id",id).put("target",id).put("kind","review").put("config",id).put("at",at).put("notBefore",System.currentTimeMillis())
                        ModuleReminders.validate(row,true)
                        val root=JSONObject().put("v",1).put("rows",org.json.JSONArray().put(row)).put("labels",JSONObject().put("habit","Bilga Review").put("message","Synthetic reminder"))
                        TodoStore.write(activity,root,ModuleReminders.STORE);ModuleReminders.schedule(activity,root);result.success(null)
                    }
                    "reviewNotification" -> {
                        check(review());val id=call.argument<String>("id")?:error("fixture_id");check(id.startsWith("bilga-review-module-"))
                        result.success(activity.getSystemService(NotificationManager::class.java).activeNotifications.any { it.tag==id&&it.id==903 })
                    }
                    "reviewEnd" -> {check(review());restoreReview();result.success(null)}
                    else -> result.notImplemented()
                }
            }catch(e:Exception){result.error("module_reminder",e.javaClass.simpleName,null)}
        }
        ModuleReminders.enqueue { ModuleReminders.schedule(activity.applicationContext) }
    }
    private fun review()=activity.packageName=="com.ilmmizan.bilga.review"&&activity.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE!=0
    private fun restoreReview() {
        for(row in ModuleReminders.rows(ModuleReminders.root(activity)))if(row.optString("id").startsWith("bilga-review-module-"))activity.getSystemService(NotificationManager::class.java).cancel(row.getString("id"),903)
        val original=TodoStore.read(activity,"modules-review-original")?:error("original_unreadable")
        TodoStore.write(activity,original,ModuleReminders.STORE);TodoStore.file(activity,"modules-review-original").delete();ModuleReminders.schedule(activity,original)
    }
    fun receive(intent:Intent?) {
        if(intent?.action!=ModuleReminders.OPEN)return
        val kind=intent.getStringExtra("module_kind");val target=intent.getStringExtra("module_target")
        if(kind in listOf("habit","finance","task","center","experience","book")&&!target.isNullOrEmpty()&&target.length<=2048){pending=mapOf("kind" to kind!!,"target" to target,"event" to intent.getStringExtra("module_event").orEmpty());channel.invokeMethod("launch",null)}
        intent.action=Intent.ACTION_MAIN;intent.removeExtra("module_kind");intent.removeExtra("module_target");intent.removeExtra("module_event")
    }
    fun ready(){channel.invokeMethod("ready",null)}
    fun close(){if(current===this){channel.setMethodCallHandler(null);current=null}}
}
