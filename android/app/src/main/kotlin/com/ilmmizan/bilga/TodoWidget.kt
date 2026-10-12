package com.ilmmizan.bilga

import android.appwidget.*
import android.content.*
import android.os.*
import android.util.SizeF
import android.graphics.*
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.time.*

class TodoWidget: AppWidgetProvider() {
    override fun onUpdate(c: Context,m: AppWidgetManager,ids: IntArray) { observe(c); ids.forEach { render(c,it) }; TodoReminders.schedule(c) }
    override fun onAppWidgetOptionsChanged(c: Context,m: AppWidgetManager,id: Int,options: Bundle) = render(c,id)
    override fun onDeleted(c: Context,ids: IntArray) {
        val root=TodoStore.read(c)
        if(root!=null) { ids.forEach { root.optJSONObject("widgets")?.remove(it.toString()) }; TodoStore.write(c,root) }
        TodoReminders.schedule(c)
    }
    override fun onRestored(c: Context,oldIds: IntArray,newIds: IntArray) { newIds.forEach { render(c,it) }; TodoReminders.schedule(c) }
    companion object {
        private var observing=false
        fun ids(c: Context)=AppWidgetManager.getInstance(c).getAppWidgetIds(ComponentName(c,TodoWidget::class.java))
        fun observe(c: Context) {
            if(observing) return; observing=true
            val receiver=TodoReceiver()
            val filter=IntentFilter().apply { addAction(Intent.ACTION_SCREEN_OFF); addAction(Intent.ACTION_USER_PRESENT) }
            if(Build.VERSION.SDK_INT>=33) c.applicationContext.registerReceiver(receiver,filter,Context.RECEIVER_NOT_EXPORTED)
            else @Suppress("DEPRECATION") c.applicationContext.registerReceiver(receiver,filter)
        }
        fun refresh(c: Context) { ids(c).forEach { render(c,it) } }
        internal fun selected(tasks: List<JSONObject>,source: String,now: Long,zone: ZoneId=ZoneId.systemDefault()): List<JSONObject> {
            val today=Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
            return tasks.filter { task ->
                val due=TodoTime.instant(task.optString("due"),zone) ?: return@filter false
                val date=Instant.ofEpochMilli(due).atZone(zone).toLocalDate()
                when(source) {
                    "overdue" -> due<=now && !task.optBoolean("done")
                    "today" -> date==today
                    else -> !date.isAfter(today.plusDays(3)) && (!task.optBoolean("done") || !date.isBefore(today)) // Overdue + upcoming 3 calendar days.
                }
            }.sortedWith(compareBy<JSONObject> { it.optBoolean("done") }.thenBy { TodoTime.instant(it.optString("due"),zone) })
        }
        internal fun color(state: String,dark: Boolean): Int = when(state) {
            "green"->Color.rgb(50,166,106); "yellow"->Color.rgb(229,184,47); "red"->Color.rgb(228,84,88)
            "overdue"->if(dark) Color.rgb(107,114,126) else Color.rgb(23,25,28)
            else->if(dark) Color.rgb(197,203,211) else Color.rgb(154,162,173)
        }
        private fun background(color: Int): Bitmap {
            val bitmap=Bitmap.createBitmap(360,64,Bitmap.Config.ARGB_8888)
            val canvas=Canvas(bitmap); val paint=Paint(Paint.ANTI_ALIAS_FLAG)
            paint.color=color; paint.alpha=10; canvas.drawRoundRect(1f,1f,359f,63f,10f,10f,paint)
            paint.alpha=18; paint.strokeWidth=.6f
            for(x in 16..350 step 16) canvas.drawLine(x.toFloat(),2f,x.toFloat(),62f,paint)
            for(y in 16..60 step 16) canvas.drawLine(2f,y.toFloat(),358f,y.toFloat(),paint)
            paint.alpha=220; paint.style=Paint.Style.STROKE; paint.strokeWidth=2f
            canvas.drawRoundRect(1f,1f,359f,63f,10f,10f,paint)
            return bitmap
        }
        fun render(c: Context,id: Int) {
            val manager=AppWidgetManager.getInstance(c)
            if(!ids(c).contains(id)) return
            val root=TodoStore.read(c) ?: JSONObject()
            val config=root.optJSONObject("widgets")?.optJSONObject(id.toString()) ?: JSONObject()
            val now=System.currentTimeMillis()
            val tasks=selected(TodoReminders.tasks(root).filter { it.optString("id")!=root.optString("blockedTask") },config.optString("source","upcoming"),now)
            val hidden=TodoReminders.private(c,root) || !config.optBoolean("showTitles")
            val dark=root.optBoolean("dark",true)
            val foreground=WidgetTheme.foreground(c)
            fun label(key: String,fallback: Int)=root.optJSONObject("labels")?.optString(key)?.takeIf { it.isNotBlank() } ?: c.getString(fallback)
            fun layout(width: Int,height: Int): RemoteViews {
                val views=RemoteViews(c.packageName,R.layout.todo_widget)
                views.setInt(R.id.todo_widget_root,"setBackgroundColor",WidgetTheme.background(c))
                views.setTextViewText(R.id.todo_widget_title,label("todos",R.string.tw_todos)); views.setTextColor(R.id.todo_widget_title,foreground)
                views.setOnClickPendingIntent(R.id.todo_widget_title,TodoHandoff.pending(c,"list",widget=id))
                views.setTextViewText(R.id.todo_widget_progress,"${tasks.count { it.optBoolean("done") }}/${tasks.size} · ${label("reminderDone",R.string.tw_done)}")
                views.setTextColor(R.id.todo_widget_progress,foreground)
                views.setTextColor(R.id.todo_widget_add,foreground); views.setTextColor(R.id.todo_widget_settings,foreground)
                views.setOnClickPendingIntent(R.id.todo_widget_add,TodoHandoff.pending(c,"create",widget=id))
                views.setContentDescription(R.id.todo_widget_add,label("newTask",R.string.tw_new))
                views.setOnClickPendingIntent(R.id.todo_widget_settings,TodoHandoff.pending(c,"configure",widget=id))
                views.setContentDescription(R.id.todo_widget_settings,label("reminderSettings",R.string.tw_reminders))
                views.removeAllViews(R.id.todo_widget_rows)
                val menuTask=tasks.firstOrNull { it.optString("id")==config.optString("snoozeTask") && !it.optBoolean("done") }
                if(menuTask!=null && !TodoReminders.private(c,root)) {
                    // Replace rows instead of appending: presets fit even the smallest widget.
                    views.setViewVisibility(R.id.todo_widget_progress,View.GONE)
                    views.setTextViewText(R.id.todo_widget_title,label("reminderSnooze",R.string.tw_snooze))
                    views.setOnClickPendingIntent(R.id.todo_widget_title,TodoNativeActions.pending(c,id,menuTask,"menu"))
                    val menu=RemoteViews(c.packageName,R.layout.todo_widget_snooze)
                    for((view,pair) in listOf(R.id.todo_snooze5 to (5 to "snooze5"),R.id.todo_snooze10 to (10 to "snooze10"),R.id.todo_snooze30 to (30 to "snooze30"),R.id.todo_snooze60 to (60 to "snooze60"),R.id.todo_snoozeTomorrow to (-1 to "tomorrow"))) {
                        menu.setTextViewText(view,root.optJSONObject("labels")?.optString(pair.second) ?: "")
                        menu.setTextColor(view,foreground)
                        menu.setOnClickPendingIntent(view,TodoNativeActions.pending(c,id,menuTask,"snooze",pair.first))
                    }
                    views.addView(R.id.todo_widget_rows,menu)
                    views.setViewVisibility(R.id.todo_widget_message,View.GONE)
                    return views
                }
                val capacity=((height-75)/(100* c.resources.configuration.fontScale.coerceAtLeast(1f))).toInt().coerceIn(1,6)
                for((index,task) in tasks.take(capacity).withIndex()) {
                    val row=RemoteViews(c.packageName,R.layout.todo_widget_row)
                    val taskId=task.getString("id")
                    row.setImageViewBitmap(R.id.todo_widget_row_background,background(color(TodoTime.state(task,now),dark)))
                    row.setTextViewText(R.id.todo_widget_row_title,if(hidden || !task.optBoolean("widgetAllowed")) "${label("task",R.string.tw_task)} ${index+1}" else task.optString("title").ifBlank { label("task",R.string.tw_task) }.take(160))
                    row.setTextColor(R.id.todo_widget_row_title,foreground)
                    val due=TodoTime.instant(task.optString("due"))
                    val state=TodoTime.state(task,now)
                    val stateText=root.optJSONObject("labels")?.optString(when(state) { "completed"->"todoDone"; "overdue"->"todoOverdue"; "neutral"->"none"; else->"remaining" }) ?: state
                    val deadline=due?.let { android.text.format.DateFormat.getDateFormat(c).format(java.util.Date(it))+" "+android.text.format.DateFormat.getTimeFormat(c).format(java.util.Date(it)) } ?: ""
                    row.setTextViewText(R.id.todo_widget_row_time,deadline+"\n"+stateText)
                    row.setTextColor(R.id.todo_widget_row_time,foreground)
                    row.setTextColor(R.id.todo_widget_row_remaining,foreground)
                    row.setChronometerCountDown(R.id.todo_widget_row_remaining,due!=null && due>now)
                    row.setChronometer(R.id.todo_widget_row_remaining,SystemClock.elapsedRealtime()+((due ?: now)-now),"%s",due!=null && state!="completed")
                    row.setViewVisibility(R.id.todo_widget_row_remaining,if(due!=null && state!="completed") View.VISIBLE else View.GONE)
                    row.setOnClickPendingIntent(R.id.todo_widget_row_text,TodoHandoff.pending(c,"open",taskId,id))
                    row.setTextColor(R.id.todo_widget_row_done,foreground)
                    row.setTextViewText(R.id.todo_widget_row_done,if(task.optBoolean("done")) "✓" else "□")
                    row.setContentDescription(R.id.todo_widget_row_done,label("reminderDone",R.string.tw_done))
                    row.setOnClickPendingIntent(R.id.todo_widget_row_done,if(task.optBoolean("done")) null else TodoNativeActions.pending(c,id,task,"done"))
                    row.setTextColor(R.id.todo_widget_row_snooze,foreground)
                    row.setContentDescription(R.id.todo_widget_row_snooze,root.optJSONObject("labels")?.optString("reminderSnooze") ?: "")
                    row.setOnClickPendingIntent(R.id.todo_widget_row_snooze,if(task.optBoolean("done")) null else TodoNativeActions.pending(c,id,task,"menu"))
                    views.addView(R.id.todo_widget_rows,row)

                }
                views.setViewVisibility(R.id.todo_widget_message,if(tasks.isEmpty()) View.VISIBLE else View.GONE)
                views.setTextViewText(R.id.todo_widget_message,label("empty",R.string.tw_empty)); views.setTextColor(R.id.todo_widget_message,foreground)
                return views
            }
            val options=manager.getAppWidgetOptions(id)
            val w=options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,240)
            val h=options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT,160)
            val views=if(Build.VERSION.SDK_INT>=31) {
                @Suppress("DEPRECATION") val sizes=options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)?.filter { it.width>0 && it.height>0 }?.distinct()?.take(16)
                if(sizes.isNullOrEmpty()) layout(w,h) else RemoteViews(sizes.associateWith { layout(it.width.toInt(),it.height.toInt()) })
            } else RemoteViews(layout(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH,w),h),layout(w,options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT,h)))
            manager.updateAppWidget(id,views)
        }
    }
}
