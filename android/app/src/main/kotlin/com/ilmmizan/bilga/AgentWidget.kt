package com.ilmmizan.bilga

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class AgentWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.ilmmizan.bilga.OPEN_AGENT"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val pending = PendingIntent.getActivity(context, 710, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val views = RemoteViews(context.packageName, R.layout.agent_widget)
            WidgetTheme.card(context,views)
            views.setTextColor(R.id.agent_widget_title,WidgetTheme.foreground(context))
            views.setInt(R.id.agent_widget_icon,"setColorFilter",WidgetTheme.accent(context))
            views.setOnClickPendingIntent(R.id.agent_widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
    companion object {
        fun refresh(c:Context) {
            val m=AppWidgetManager.getInstance(c)
            AgentWidget().onUpdate(c,m,m.getAppWidgetIds(android.content.ComponentName(c,AgentWidget::class.java)))
        }
    }
}
