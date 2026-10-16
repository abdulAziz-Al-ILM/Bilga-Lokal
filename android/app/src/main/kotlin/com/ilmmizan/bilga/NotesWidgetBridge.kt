package com.ilmmizan.bilga

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.ResultReceiver
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class NotesWidgetBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "bilga/notes_widget")
    private var launch: Map<String, Any>? = null
    private var configuring: Pair<Int, ResultReceiver>? = null
    init {
        NotesWidget.observeLock(activity)
        // AudioService keeps the Flutter engine alive across activity recreation.
        // Notify an already-running Dart host; cold Dart also consumes this queue.
        receive(activity.intent)
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "consumeLaunch" -> { result.success(launch); launch = null }
                    "configs" -> {
                        val ids = NotesWidget.ids(activity).toMutableSet()
                        result.success(ids.map { id ->
                            val v = NotesWidgetStore.readableOrNew(activity, id)
                            mapOf("id" to id, "source" to v.optString("source", "recent"), "privacy" to v.optString("privacy", "hidden"),
                                "revision" to v.optString("revision", ""),
                                "permissionEpoch" to activity.getSharedPreferences("notes-widget-ui", Context.MODE_PRIVATE).getLong("permissionEpoch", 0),
                                "tagId" to v.optString("tagId").takeIf { it.isNotEmpty() && it != "null" },
                                "pinnedIds" to array(v.optJSONArray("pinnedIds")), "approvals" to objectMap(v.optJSONObject("approvals")))
                        })
                    }
                    "saveConfig" -> {
                        val id = call.argument<Int>("id") ?: -1
                        require(id == configuring?.first && NotesWidget.owns(activity, id))
                        val source = call.argument<String>("source") ?: "recent"
                        val privacy = call.argument<String>("privacy") ?: "hidden"
                        require(source in listOf("recent", "pinned", "tag") && privacy in listOf("hidden", "titles", "preview"))
                        val pinned = call.argument<List<String>>("pinnedIds") ?: emptyList()
                        val approvals = call.argument<Map<String, String>>("approvals") ?: emptyMap()
                        require(pinned.size <= 100 && approvals.size <= 100 && pinned.all { it.length in 1..512 } && approvals.all { it.key.length in 1..512 && it.value.length <= 128 })
                        NotesWidgetStore.write(activity, id, NotesWidget.defaults(id).put("source", source).put("privacy", privacy)
                            .put("revision", UUID.randomUUID().toString()).put("tagId", call.argument<String>("tagId")).put("pinnedIds", JSONArray(pinned)).put("approvals", JSONObject(approvals)))
                        NotesWidget.render(activity, id)
                        result.success(null)
                    }
                    "publish" -> {
                        val ui = activity.getSharedPreferences("notes-widget-ui", Context.MODE_PRIVATE).edit()
                        ui.putBoolean("forceHidden", call.argument<Boolean>("forceHidden") != false)
                        for (key in listOf("background", "foreground", "accent")) ui.putInt(key, (call.argument<Number>(key) ?: 0).toInt())
                        ui.putString("language", call.argument<String>("language") ?: "uz")
                        check(ui.commit())
                        val labels = JSONObject(call.argument<Map<String, String>>("labels") ?: emptyMap<String, String>())
                        for (item in call.argument<List<Map<String, Any>>>("widgets") ?: emptyList()) {
                            val id = (item["id"] as? Number)?.toInt() ?: continue
                            if (!NotesWidget.owns(activity, id)) continue
                            val config = NotesWidgetStore.readableOrNew(activity, id)
                            if (config.optString("revision", "") != (item["revision"] as? String ?: "")) continue
                            val epoch = activity.getSharedPreferences("notes-widget-ui", Context.MODE_PRIVATE).getLong("permissionEpoch", 0)
                            if ((item["permissionEpoch"] as? Number)?.toLong() != epoch) continue
                            val rows = item["rows"] as? List<*> ?: emptyList<Any>()
                            require(rows.size <= 12)
                            config.put("rows", JSONArray(rows)).put("labels", labels)
                                .put("permissionEpoch", epoch).put("permissionsVersion", 1)
                            NotesWidgetStore.write(activity, id, config)
                        }
                        NotesWidget.refresh(activity)
                        result.success(null)
                    }
                    "invalidatePermissions" -> {
                        val ui = activity.getSharedPreferences("notes-widget-ui", Context.MODE_PRIVATE)
                        val epoch = Math.addExact(ui.getLong("permissionEpoch", 0), 1)
                        check(ui.edit().putLong("permissionEpoch", epoch).putBoolean("forceHidden", true).commit())
                        NotesWidget.refresh(activity)
                        NotesWidgetStore.clearSnapshots(activity, epoch)
                        NotesWidget.refresh(activity)
                        result.success(null)
                    }
                    "redact" -> {
                        check(activity.getSharedPreferences("notes-widget-ui", Context.MODE_PRIVATE).edit().putBoolean("forceHidden", true).commit())
                        NotesWidget.refresh(activity); result.success(null)
                    }
                    "finishConfiguration", "cancelConfiguration" -> {
                        val (id, reply) = configuring ?: error("No widget configuration")
                        require(NotesWidget.owns(activity, id))
                        configuring = null
                        reply.send(if (call.method == "finishConfiguration") Activity.RESULT_OK else Activity.RESULT_CANCELED, null)
                        result.success(null)
                        activity.moveTaskToBack(true)
                    }
                    "requestPin" -> {
                        val manager = AppWidgetManager.getInstance(activity)
                        result.success(manager.isRequestPinAppWidgetSupported && manager.requestPinAppWidget(ComponentName(activity, NotesWidget::class.java), null, null))
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                activity.getSharedPreferences("notes-widget-ui", Context.MODE_PRIVATE).edit().putBoolean("forceHidden", true).commit()
                NotesWidget.refresh(activity)
                result.error("notes_widget", "Notes widget unavailable", null)
            }
        }
    }
    fun receive(intent: Intent?, notify: Boolean = true) {
        val id = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1) ?: return
        if (!NotesWidget.owns(activity, id)) return
        if (intent.action != Intent.ACTION_MAIN && intent.action != NotesWidget.OPEN) return
        launch = when {
            intent.getStringExtra("notes_action") == "configure" -> {
                val reply = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra("notes_config_reply", ResultReceiver::class.java)
                    else @Suppress("DEPRECATION") intent.getParcelableExtra<ResultReceiver>("notes_config_reply")
                if (reply == null) return
                configuring = id to reply
                mapOf("action" to "configure", "id" to id)
            }
            intent.getStringExtra("notes_action") in listOf("open", "create", "search", "list") ->
                mapOf("action" to intent.getStringExtra("notes_action")!!, "id" to id, "noteId" to (intent.getStringExtra("note_id") ?: "").take(512))
            else -> return
        }
        if (notify) channel.invokeMethod("launch", null)
    }
    fun ready() { channel.invokeMethod("refresh", null) }
    fun close() { channel.setMethodCallHandler(null) }
    private fun array(value: JSONArray?): List<String> = if (value == null) emptyList() else (0 until value.length()).map { value.getString(it) }
    private fun objectMap(value: JSONObject?): Map<String, String> = value?.keys()?.asSequence()?.associateWith { value.getString(it) } ?: emptyMap()
}
