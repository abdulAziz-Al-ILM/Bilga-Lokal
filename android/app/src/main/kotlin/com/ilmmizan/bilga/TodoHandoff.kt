package com.ilmmizan.bilga

import android.app.*
import android.content.*
import android.net.Uri
import android.os.*

/** Stable launcher handoff keeps audio_service's cached engine in MainActivity. */
class TodoHandoff: Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val widget=intent.getIntExtra("appWidgetId",-1)
        if(intent.action==android.appwidget.AppWidgetManager.ACTION_APPWIDGET_CONFIGURE && !TodoWidget.ids(this).contains(widget)) { finish(); return }
        val next=Intent(this,MainActivity::class.java).setAction(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP).putExtra("todo_action",if(intent.action==android.appwidget.AppWidgetManager.ACTION_APPWIDGET_CONFIGURE) "configure" else intent.getStringExtra("todo_action"))
            .putExtra("todo_id",intent.getStringExtra("todo_id")).putExtra("todo_widget",widget)
        if(next.getStringExtra("todo_action")=="configure") {
            setResult(RESULT_CANCELED)
            next.putExtra("todo_reply",object: ResultReceiver(Handler(Looper.getMainLooper())) {
                override fun onReceiveResult(code: Int,data: Bundle?) {
                    setResult(code,Intent().putExtra("appWidgetId",widget)); finish()
                }
            })
        }
        startActivity(next)
        if(next.getStringExtra("todo_action")!="configure") finish()
    }
    companion object {
        fun intent(c: Context,action: String,id: String="",widget: Int=-1) = Intent(c,TodoHandoff::class.java).setAction(TodoReminders.OPEN)
            .setData(Uri.parse("bilga-todo://$action/$widget/${Uri.encode(id)}"))
            .putExtra("todo_action",action).putExtra("todo_id",id).putExtra("appWidgetId",widget)
        fun pending(c: Context,action: String,id: String="",widget: Int=-1) = PendingIntent.getActivity(c,0,intent(c,action,id,widget),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        fun open(c: Context,action: String,id: String="",widget: Int=-1) { c.startActivity(intent(c,action,id,widget).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }
}
