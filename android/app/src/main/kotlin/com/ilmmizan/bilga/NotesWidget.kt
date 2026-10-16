package com.ilmmizan.bilga

import android.app.KeyguardManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

class NotesWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        observeLock(context)
        ids.forEach { render(context, it) }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = render(context, id)
    override fun onDeleted(context: Context, ids: IntArray) { ids.forEach { NotesWidgetStore.delete(context, it) } }
    override fun onRestored(context: Context, oldIds: IntArray, newIds: IntArray) {
        // Configurations are device-local. Restored hosts start in the safe mode.
        newIds.forEach { render(context, it) }
    }
    companion object {
        const val OPEN = "com.ilmmizan.bilga.NOTES_WIDGET"
        private var observing = false
        fun ids(context: Context): IntArray = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, NotesWidget::class.java))
        fun owns(context: Context, id: Int): Boolean = id > 0 &&
            AppWidgetManager.getInstance(context).getAppWidgetInfo(id)?.provider == ComponentName(context, NotesWidget::class.java)
        fun defaults(id: Int) = JSONObject().put("id", id).put("source", "recent").put("privacy", "hidden")
            .put("pinnedIds", JSONArray()).put("approvals", JSONObject()).put("rows", JSONArray())
        fun refresh(context: Context) { ids(context).forEach { render(context, it) } }
        internal fun visibleRows(value: JSONObject?, epoch: Long, hidden: Boolean): JSONArray =
            if (hidden || value?.optInt("permissionsVersion") != 1 || value.optLong("permissionEpoch", -1) != epoch) JSONArray()
            else value.optJSONArray("rows") ?: JSONArray()
        fun observeLock(context: Context) {
            if (observing) return
            observing = true
            val app = context.applicationContext
            val filter = IntentFilter().apply { addAction(Intent.ACTION_SCREEN_OFF); addAction(Intent.ACTION_USER_PRESENT) }
            val receiver = object : BroadcastReceiver() { override fun onReceive(c: Context, i: Intent) { refresh(c) } }
            if (Build.VERSION.SDK_INT >= 33) app.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            else @Suppress("DEPRECATION") app.registerReceiver(receiver, filter)
        }
        fun localized(context: Context): Context {
            val code = context.getSharedPreferences("notes-widget-ui", Context.MODE_PRIVATE).getString("language", "uz") ?: "uz"
            return context.createConfigurationContext(Configuration(context.resources.configuration).apply { setLocale(Locale.forLanguageTag(code)) })
        }
        internal fun pending(context: Context, id: Int, action: String, note: String = ""): PendingIntent {
            // Keep unique PendingIntent identity on the lightweight handoff.
            // The shared Flutter/audio engine must always open in its one main task.
            val intent = Intent(context, NotesWidgetConfigureActivity::class.java).apply {
                this.action = if (action == "configure") AppWidgetManager.ACTION_APPWIDGET_CONFIGURE else OPEN
                putExtra("notes_action", action); putExtra("note_id", note)
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            }
            intent.data = Uri.Builder().scheme("bilga-notes-widget").authority(id.toString()).appendPath(action).appendPath(note).build()
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            return PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        internal fun previewLines(width:Int,height:Int,scale:Float):Int {
            if(width<160) return 0
            val available=(height-60)/scale.coerceAtLeast(1f)
            return if(available>=100) 3 else if(available>=80) 2 else 0
        }
        fun render(context: Context, id: Int) {
            if (!owns(context, id)) return
            val manager = AppWidgetManager.getInstance(context)
            val ui = context.getSharedPreferences("notes-widget-ui", Context.MODE_PRIVATE)
            val local = localized(context)
            val locked = (context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isDeviceLocked
            val value = if (locked) null else NotesWidgetStore.read(context, id)
            val labels = value?.optJSONObject("labels")
            fun label(key: String, resource: Int) = labels?.optString(key)?.takeIf { it.isNotEmpty() } ?: local.getString(resource)
            fun layout(width: Int, height: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.notes_widget)
            val color = WidgetTheme.foreground(context)
            val accent = WidgetTheme.accent(context)
            views.setInt(R.id.notes_widget_root, "setBackgroundColor", WidgetTheme.background(context))
            views.setTextViewText(R.id.notes_widget_title, label("notes", R.string.nw_notes))
            views.setTextColor(R.id.notes_widget_title, color)
            val controls = listOf(Triple(R.id.notes_widget_add, "create", R.string.nw_new_note), Triple(R.id.notes_widget_search, "search", R.string.nw_search), Triple(R.id.notes_widget_settings, "configure", R.string.nw_settings))
            for ((view, action, resource) in controls) {
                views.setTextColor(view, accent)
                views.setContentDescription(view, local.getString(resource))
                views.setOnClickPendingIntent(view, pending(context, id, action))
            }
            views.setOnClickPendingIntent(R.id.notes_widget_title, pending(context, id, "list"))
            views.removeAllViews(R.id.notes_widget_rows)
            val hidden = locked || ui.getBoolean("forceHidden", true)
            val rows = visibleRows(value, ui.getLong("permissionEpoch", 0), hidden)
            val scale=context.resources.configuration.fontScale.coerceAtLeast(1f)
            val lines=previewLines(width,height,scale)
            val detailed=lines>0
            val rowHeight=if(detailed && value?.optString("privacy")=="preview") 48+16*lines else 44
            val capacity=((height-60)/(rowHeight*scale).toInt()).coerceIn(1,6)
            for (index in 0 until minOf(rows.length(), capacity)) {
                val row = rows.optJSONObject(index) ?: continue
                val noteId = row.optString("id")
                if (noteId.isEmpty() || noteId.length > 512) continue
                val item = RemoteViews(context.packageName, R.layout.notes_widget_row)
                item.setTextViewText(R.id.notes_widget_note_title, row.optString("title").take(160))
                item.setTextViewText(R.id.notes_widget_note_body, row.optString("body").take(240))
                item.setInt(R.id.notes_widget_note_body,"setMaxLines",lines.coerceAtLeast(1))
                item.setTextViewText(R.id.notes_widget_note_tags, row.optString("tags").take(160))
                for (view in listOf(R.id.notes_widget_note_title, R.id.notes_widget_note_body, R.id.notes_widget_note_tags)) item.setTextColor(view, color)
                item.setViewVisibility(R.id.notes_widget_note_body, if (detailed && value?.optString("privacy") == "preview" && row.optString("body").isNotEmpty()) View.VISIBLE else View.GONE)
                item.setViewVisibility(R.id.notes_widget_note_tags, if (detailed && value?.optString("privacy") == "preview" && row.optString("tags").isNotEmpty()) View.VISIBLE else View.GONE)
                item.setOnClickPendingIntent(R.id.notes_widget_note_row, pending(context, id, "open", noteId))
                views.addView(R.id.notes_widget_rows, item)
            }
            views.setViewVisibility(R.id.notes_widget_message, if (rows.length() == 0) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.notes_widget_message, if (hidden || value == null) local.getString(R.string.nw_hidden) else label("empty", R.string.nw_empty))
            views.setTextColor(R.id.notes_widget_message, color)
            views.setOnClickPendingIntent(R.id.notes_widget_message, pending(context, id, "list"))
            return views
            }
            val options = manager.getAppWidgetOptions(id)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 240)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 140)
            val views = if (Build.VERSION.SDK_INT >= 31) {
                @Suppress("DEPRECATION")
                val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
                    ?.filter { it.width > 0 && it.height > 0 }?.distinct()?.take(16)
                if (sizes.isNullOrEmpty()) layout(minWidth, minHeight)
                else RemoteViews(sizes.associateWith { layout(it.width.toInt(), it.height.toInt()) })
            } else RemoteViews(
                layout(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minWidth), minHeight),
                layout(minWidth, options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minHeight)))
            manager.updateAppWidget(id, views)
        }
    }
}
