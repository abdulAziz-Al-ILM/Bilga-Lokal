package com.ilmmizan.bilga

import android.app.NotificationManager
import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.*

/** Debug instrumentation touches only its scoped synthetic alarm cache. */
internal object ModuleReminderChecks {
    fun run(c:Context,operation:String,id:String,kind:String="habit"):Pair<Boolean,String> {
        require(c.packageName=="com.ilmmizan.bilga.review" && id.startsWith("bilga-review-module-") && id.length<200 && kind in listOf("habit","finance","recurring"))
        return try {
            val tag="$kind:$id"
            when(operation) {
                "prepare" -> {
                    check(!TodoStore.file(c,"modules-review-original").baseFile.exists())
                    check(ModuleReminders.enabled(c))
                    val original=ModuleReminders.root(c)
                    TodoStore.write(c,original,"modules-review-original")
                    val now=System.currentTimeMillis();val zone=ZoneId.systemDefault()
                    var at=Instant.ofEpochMilli(now).atZone(zone).plusMinutes(1).withSecond(0).withNano(0)
                    if(at.toInstant().toEpochMilli()<now+30000)at=at.plusMinutes(1)
                    val schedule=JSONObject().put("type","weekdays").put("weekdays",JSONArray(listOf(1,2,3,4,5,6,7))).put("interval",1).put("quota",1).put("target",1).put("start",LocalDate.now().toString()).put("pauses",JSONArray())
                    val windows=JSONArray().put(JSONObject().put("from","0001-01-01").put("schedule",schedule))
                    val row=JSONObject().put("id",tag).put("target",id).put("kind",if (kind=="recurring") "finance" else kind).put("date",at.toLocalDate().toString()).put("minute",at.hour*60+at.minute).put("created",LocalDate.now().toString()).put("windows",windows).put("completed",JSONArray()).put("config",id).put("notBefore",now)
                    if (kind=="recurring") {
                        row.put("event","financeRecurring").put("cadence",0)
                        val originalZone = java.util.TimeZone.getDefault()
                        try {
                            val candidate = JSONObject(row.toString())
                                .put("date","2032-04-17").put("minute",600)
                            java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("Asia/Tashkent"))
                            val tashkent = ModuleReminders.next(JSONObject(),candidate,now)?.at
                                ?: error("missing_tashkent_candidate")
                            java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("UTC"))
                            val utc = ModuleReminders.next(JSONObject(),candidate,now)?.at
                                ?: error("missing_utc_candidate")
                            check(utc-tashkent == 5L*60*60*1000)
                        } finally {
                            java.util.TimeZone.setDefault(originalZone)
                        }
                    }
                    ModuleReminders.validate(row)
                    val root=JSONObject().put("v",1).put("rows",JSONArray().put(row)).put("labels",JSONObject().put("habit","Bilga Review").put("finance","Bilga Review").put("message","Synthetic reminder"))
                    TodoStore.write(c,root,ModuleReminders.STORE);ModuleReminders.schedule(c,root)
                    true to "MODULE_PREPARED:${at.toInstant().toEpochMilli()}\n"
                }
                "exists" -> {
                    val exists=c.getSystemService(NotificationManager::class.java).activeNotifications.any { it.tag==tag&&it.id==903 }
                    true to "MODULE_NOTIFICATION:$exists\n"
                }
                "restore" -> {
                    val source=TodoStore.file(c,"modules-review-original")
                    if(source.baseFile.exists()) {
                        val original=TodoStore.read(c,"modules-review-original")?:error("original_unreadable")
                        c.getSystemService(NotificationManager::class.java).cancel(tag,903)
                        TodoStore.write(c,original,ModuleReminders.STORE)
                        check(ModuleReminders.root(c).toString()==original.toString())
                        source.delete();ModuleReminders.schedule(c,original)
                    }
                    true to "MODULE_ORIGINAL_RESTORED\n"
                }
                else -> false to "Unknown module fixture operation\n"
            }
        }catch(e:Throwable){false to "Module fixture failed: ${e.javaClass.simpleName} at ${e.stackTrace.firstOrNull()?.lineNumber}\n"}
    }
}
