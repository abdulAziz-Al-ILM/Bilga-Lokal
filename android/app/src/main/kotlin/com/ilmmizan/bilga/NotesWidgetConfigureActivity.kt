package com.ilmmizan.bilga

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.ComponentName
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver

/** Hand off to the existing Flutter activity; never attach its shared audio engine twice. */
class NotesWidgetConfigureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        setResult(RESULT_CANCELED)
        super.onCreate(savedInstanceState)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
        if (!NotesWidget.owns(this, id)) { finish(); return }
        val requested = if (intent.action == AppWidgetManager.ACTION_APPWIDGET_CONFIGURE) "configure"
            else intent.getStringExtra("notes_action")
        if (requested !in listOf("configure", "open", "create", "search", "list")) { finish(); return }
        val reply = object : ResultReceiver(Handler(Looper.getMainLooper())) {
            override fun onReceiveResult(code: Int, data: Bundle?) {
                if (!isFinishing) {
                    setResult(code, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
                    finish()
                }
            }
        }
        startActivity(Intent.makeMainActivity(ComponentName(this, MainActivity::class.java)).apply {
            putExtra("notes_action", requested)
            putExtra("note_id", intent.getStringExtra("note_id"))
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            if (requested == "configure") putExtra("notes_config_reply", reply)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        })
        if (requested != "configure") finish()
    }
}
