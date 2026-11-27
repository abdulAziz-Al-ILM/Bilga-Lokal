package com.ilmmizan.bilga

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.widget.Button
import android.widget.RemoteViews
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal object WidgetTheme {
    fun color(c:Context,key:String,fallback:Int)=c.getSharedPreferences("bilga-widget-theme",Context.MODE_PRIVATE).getInt(key,fallback)
    fun background(c:Context)=color(c,"background",Color.rgb(20,32,25))
    fun foreground(c:Context)=color(c,"foreground",Color.rgb(238,238,238))
    fun accent(c:Context)=color(c,"accent",Color.rgb(164,215,185))
    fun card(c:Context,views:RemoteViews) {
        views.setInt(R.id.bilga_widget_background,"setColorFilter",background(c))
    }
    fun shape(c:Context,filled:Boolean=false)=GradientDrawable().apply {
        setColor(if(filled) accent(c) else color(c,"container",Color.rgb(30,34,42)))
        cornerRadius=18*c.resources.displayMetrics.density
        if(!filled) setStroke((c.resources.displayMetrics.density).toInt().coerceAtLeast(1),color(c,"outline",Color.GRAY))
    }
    fun button(c:Context,button:Button,primary:Boolean=false) {
        button.setTextColor(if(primary) color(c,"onAccent",Color.BLACK) else foreground(c))
        // Platform Button's white tint used to override our dark background.
        button.backgroundTintList=null;button.background=shape(c,primary)
        button.isAllCaps=false;button.minHeight=(48*c.resources.displayMetrics.density).toInt()
        button.setPadding(12,12,12,12)
    }
    fun bind(c:Context,messenger:BinaryMessenger) {
        val channel=MethodChannel(messenger,"bilga/widget_theme")
        channel.setMethodCallHandler { call,result ->
            if(call.method!="publish") {result.notImplemented();return@setMethodCallHandler}
            try {
                val editor=c.getSharedPreferences("bilga-widget-theme",Context.MODE_PRIVATE).edit()
                for(key in listOf("background","foreground","accent","onAccent","container","outline")) {
                    val value=call.argument<Number>(key) ?: error("missing_color")
                    editor.putInt(key,value.toInt())
                }
                check(editor.commit());AgentWidget.refresh(c);TodoWidget.refresh(c);NotesWidget.refresh(c)
                result.success(null)
            } catch(_:Exception) { result.error("widget_theme","Widget theme unavailable",null) }
        }
        // Refresh from an already-running Dart/settings instance too.
        channel.invokeMethod("refresh",null)
    }
}
