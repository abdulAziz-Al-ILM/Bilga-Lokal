package com.ilmmizan.bilga

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import android.widget.*
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Locale

/** User-launched native picker: no Flutter task, overlay permission or service. */
class TodoSnoozeActivity : Activity() {
    private var submitting=false
    override fun attachBaseContext(base:Context) {
        val code=TodoStore.read(base)?.optString("language","uz") ?: "uz"
        super.attachBaseContext(base.createConfigurationContext(Configuration(base.resources.configuration).apply { setLocale(Locale.forLanguageTag(code)) }))
    }
    override fun onCreate(state:Bundle?) {
        setTheme(if(Color.luminance(WidgetTheme.background(this))<.5) android.R.style.Theme_DeviceDefault_Dialog_NoActionBar_MinWidth else android.R.style.Theme_DeviceDefault_Light_Dialog_NoActionBar_MinWidth)
        super.onCreate(state)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        if(!authorized()) { finish();return }
        setContentView(R.layout.todo_snooze_picker)
        val body=findViewById<LinearLayout>(R.id.todo_picker_body)
        body.setBackgroundColor(WidgetTheme.background(this))
        findViewById<TextView>(R.id.todo_picker_title).apply {
            val root=TodoStore.read(this@TodoSnoozeActivity)
            val task=root?.let { TodoNativeActions.authorizedTask(this@TodoSnoozeActivity,it,intent) }
            text=getString(R.string.tw_custom)+(if(task?.optBoolean("widgetAllowed")==true) " · "+task.optString("title").take(160) else "")
            setTextColor(WidgetTheme.foreground(this@TodoSnoozeActivity))
        }
        val date=findViewById<DatePicker>(R.id.todo_picker_date)
        val time=findViewById<TimePicker>(R.id.todo_picker_time)
        val initial=ZonedDateTime.now().plusMinutes(10)
        if(state==null) { date.updateDate(initial.year,initial.monthValue-1,initial.dayOfMonth);time.hour=initial.hour;time.minute=initial.minute }
        time.setIs24HourView(android.text.format.DateFormat.is24HourFormat(this))
        val error=findViewById<TextView>(R.id.todo_picker_error).apply { setTextColor(WidgetTheme.foreground(this@TodoSnoozeActivity)) }
        val save=findViewById<Button>(R.id.todo_picker_save)
        val cancel=findViewById<Button>(R.id.todo_picker_cancel)
        WidgetTheme.button(this,save,true);WidgetTheme.button(this,cancel)
        cancel.setText(R.string.tw_cancel);cancel.setOnClickListener { finish() }
        save.setText(R.string.tw_save)
        save.setOnClickListener {
            if(submitting) return@setOnClickListener
            date.clearFocus();time.clearFocus() // Commit spinner/text input before reading values.
            val at=LocalDate.of(date.year,date.month+1,date.dayOfMonth).atTime(time.hour,time.minute).atZone(ZoneId.systemDefault()).toOffsetDateTime().toString()
            if((TodoTime.instant(at) ?: 0)<=System.currentTimeMillis()) { error.setText(R.string.tw_future);return@setOnClickListener }
            if(!authorized()) { finish();return@setOnClickListener }
            submitting=true;save.isEnabled=false
            TodoNativeActions.submit(this,Intent(intent).putExtra("operation","snooze").putExtra("at",at)) { ok ->
                submitting=false
                if(ok) finish() else { save.isEnabled=true;error.setText(R.string.tw_limits) }
            }
        }
    }
    override fun onResume() { super.onResume();if(!authorized()) finish() }
    override fun onPause() { super.onPause();if(TodoReminders.locked(this)) finish() }
    private fun authorized():Boolean {
        val root=TodoStore.read(this) ?: return false
        return TodoNativeActions.authorizedTask(this,root,intent)!=null
    }
    companion object {
        fun pending(c:Context,widget:Int,task:JSONObject):PendingIntent {
            val token=task.getString("actionToken")
            val intent=Intent(c,TodoSnoozeActivity::class.java)
                .setData(Uri.Builder().scheme("bilga-todo-custom").authority(widget.toString()).appendPath(task.getString("id")).appendPath(token).build())
                .putExtra("widget",widget).putExtra("id",task.getString("id")).putExtra("token",token)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            return PendingIntent.getActivity(c,0,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
    }
}
