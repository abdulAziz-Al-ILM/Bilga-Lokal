package com.ilmmizan.bilga

import android.app.*
import android.appwidget.*
import android.content.*
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.os.*
import android.view.View
import android.widget.FrameLayout
import android.widget.RemoteViews
import org.json.*
import java.time.*
import java.io.File

/** Synthetic-only native tests; no user database reads, changes or key export. */
internal object TodoChecks {
    fun run(targetContext: Context): Pair<Boolean,String> {
        var count=0
        var failure: String?=null
        val directory=java.nio.file.Files.createTempDirectory(targetContext.cacheDir.toPath(),"todo-native-checks-").toFile()
        val c=object: ContextWrapper(targetContext) { override fun getNoBackupFilesDir()=directory }
        fun checkCase(condition: Boolean) { check(condition); count++ }
        fun task(id: String,due: String,done: Boolean=false)=JSONObject().put("id",id).put("due",due).put("done",done)
        try {
            val zone=ZoneId.of("Asia/Tashkent")
            val now=TodoTime.instant("2026-10-12T23:59:00",zone)!!
            checkCase(TodoTime.state(task("a","2026-10-15T00:00:00"),now,zone)=="green")
            checkCase(TodoTime.state(task("a","2026-10-14T00:00:00"),now,zone)=="yellow" && TodoTime.state(task("a","2026-10-13T00:00:00"),now,zone)=="red")
            checkCase(TodoTime.state(task("a","2026-10-12T23:59:00"),now,zone)=="overdue" && TodoTime.state(task("a","2026-10-12T23:59:00",true),now,zone)=="completed")
            checkCase(TodoTime.instant("2026-10-12T18:59:00Z",zone)==now && TodoTime.state(task("a","invalid"),now,zone)=="neutral")
            val ny=ZoneId.of("America/New_York")
            val before=TodoTime.instant("2026-03-07T10:00:00",ny)!!
            val tomorrow=TodoTime.instant(TodoTime.snooze(-1,before,ny),ny)!!
            checkCase(tomorrow-before==23*60*60*1000L && Instant.ofEpochMilli(tomorrow).atZone(ny).hour==10)
            checkCase(TodoTime.instant("2026-03-08T02:30:00",ny)==TodoTime.instant("2026-03-08T03:30:00",ny))
            val autumn=TodoTime.instant("2026-10-31T10:00:00",ny)!!
            checkCase(TodoTime.instant(TodoTime.snooze(-1,autumn,ny),ny)!!-autumn==25*60*60*1000L)
            val reminder=JSONObject().put("at",Instant.ofEpochMilli(now+1000).toString()).put("revision","generation-a").put("nonce","once").put("fired",false)
            val a=task("synthetic-a","2026-10-13T00:00:00").put("reminder",reminder)
            checkCase(!TodoTime.dueNow(a,now) && TodoTime.dueNow(a,now+1000))
            val root=JSONObject().put("tasks",JSONArray().put(a))
            checkCase(TodoReminders.claim(root,now+1000).size==1 && TodoReminders.claim(root,now+1000).isEmpty() && root.getJSONObject("events").length()==1)
            checkCase(!root.getJSONObject("events").toString().contains("title") && reminder.getBoolean("fired"))
            val selected=TodoWidget.selected(listOf(task("a","2026-10-12T22:00:00"),task("b","2026-10-13T10:00:00"),task("c","2026-10-11T10:00:00",true)),"upcoming",now,zone)
            checkCase(selected.map { it.getString("id") }==listOf("a","b") && TodoWidget.selected(selected,"overdue",now,zone).size==1)
            val approved=task("approved","2026-10-13T10:00:00").put("widgetAllowed",true)
            val widgetRoot=JSONObject().put("blockedTask","blocked").put("tasks",JSONArray()
                .put(approved)
                .put(task("denied","2026-10-12T22:00:00").put("widgetAllowed",false))
                .put(task("missing-grant","2026-10-12T22:00:00"))
                .put(task("blocked","2026-10-12T22:00:00").put("widgetAllowed",true)))
            checkCase(TodoWidget.visibleTasks(widgetRoot,"upcoming",now,zone)==listOf(approved))
            approved.put("widgetAllowed",false)
            checkCase(TodoWidget.visibleTasks(widgetRoot,"upcoming",now,zone).isEmpty())

            val manager=c.getSystemService(NotificationManager::class.java)
            TodoStore.write(c,JSONObject().put("settings",JSONObject().put("sound",false)))
            val quiet=manager.getNotificationChannel(ModuleReminders.channel(c))
            checkCase(quiet.id=="bilga.modules.quiet.v1" && quiet.sound==null && !quiet.shouldVibrate())
            TodoStore.write(c,JSONObject().put("settings",JSONObject().put("sound",true)))
            val audible=manager.getNotificationChannel(ModuleReminders.channel(c))
            checkCase(audible.id=="bilga.modules.sound.v1" && audible.sound==
                android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION) &&
                audible.audioAttributes.usage==android.media.AudioAttributes.USAGE_NOTIFICATION)
            checkCase(TodoReminders.audible(JSONObject()))
            for (priority in 1..3) {
                val id=TodoReminders.priorityChannel(c,priority)
                val tone=manager.getNotificationChannel(id)
                checkCase(id=="bilga.todo.priority.$priority.v1" && tone.sound!=null &&
                    c.contentResolver.openAssetFileDescriptor(tone.sound,"r")?.use { it.length>44 }==true)
            }
            checkCase(TodoReminders.channel(c,false,3)=="bilga.todo.quiet.v1")
            for (layout in listOf(R.layout.agent_widget,R.layout.notes_widget,R.layout.todo_widget)) {
                val views=RemoteViews(c.packageName,layout)
                WidgetTheme.card(c,views)
                val image=views.apply(c,FrameLayout(c)).findViewById<View>(R.id.bilga_widget_background)
                val size=View.MeasureSpec.makeMeasureSpec(168,View.MeasureSpec.EXACTLY)
                image.measure(size,size);image.layout(0,0,168,168)
                val bitmap=Bitmap.createBitmap(168,168,Bitmap.Config.ARGB_8888)
                image.draw(Canvas(bitmap))
                checkCase(Color.alpha(bitmap.getPixel(0,0))==0 && bitmap.getPixel(84,84)==WidgetTheme.background(c))
                bitmap.recycle()
            }
            val blocked=JSONObject().put("tasks",JSONArray().put(JSONObject(a.toString()).apply { getJSONObject("reminder").put("fired",false) }))
            checkCase(TodoReminders.pendingTimes(blocked).size==1 && TodoReminders.pendingTimes(blocked.put("blockedTask","synthetic-a")).isEmpty())
            val secret="synthetic-encryption-sentinel-9381"
            TodoStore.write(c,JSONObject().put("test",secret),"synthetic")
            val bytes=TodoStore.file(c,"synthetic").readFully()
            checkCase(!String(bytes,Charsets.ISO_8859_1).contains(secret) && TodoStore.read(c,"synthetic")?.optString("test")==secret)
            bytes[bytes.lastIndex]=(bytes.last().toInt() xor 1).toByte(); TodoStore.file(c,"synthetic").baseFile.writeBytes(bytes)
            checkCase(TodoStore.read(c,"synthetic")==null)
            val p=TodoHandoff.pending(c,"open","synthetic-a",2147483003)
            val q=TodoHandoff.pending(c,"done","synthetic-a",2147483003)
            val r=TodoHandoff.pending(c,"open","synthetic-a",2147483004)
            checkCase(p!=q && p!=r && (Build.VERSION.SDK_INT<31 || p.isImmutable)); p.cancel();q.cancel();r.cancel()
            val provider=AppWidgetManager.getInstance(c).installedProviders.single { it.provider.packageName==c.packageName && it.provider.className==TodoWidget::class.java.name }
            checkCase(provider.widgetCategory==AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN && provider.configure.className==TodoHandoff::class.java.name && provider.resizeMode==AppWidgetProviderInfo.RESIZE_BOTH)
            checkCase(c.checkSelfPermission("android.permission.USE_FULL_SCREEN_INTENT")!=android.content.pm.PackageManager.PERMISSION_GRANTED)
            count+=TodoActionChecks.run(c,directory)
        } catch(e: Throwable) { failure=e.javaClass.simpleName }
        finally { directory.deleteRecursively() }
        return (failure==null) to if(failure==null) "To-Do native checks: $count PASS\n" else "To-Do native checks FAILED at ${count+1}: $failure\n"
    }
}
