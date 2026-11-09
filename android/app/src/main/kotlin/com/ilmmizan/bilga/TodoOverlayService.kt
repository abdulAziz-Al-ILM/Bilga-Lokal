package com.ilmmizan.bilga

import android.app.*
import android.content.*
import android.os.*
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.media.*
import android.provider.Settings
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.TextToSpeech
import android.view.*
import android.widget.*
import java.util.Locale

/** One bounded reminder panel; never sticky, no polling, no full-screen intent. */
class TodoOverlayService: Service() {
    private val handler=Handler(Looper.getMainLooper())
    private var panel: View?=null
    private var speech: TextToSpeech?=null
    private var tone: ToneGenerator?=null
    private var taskId=""
    private var picker: Dialog?=null
    private var generation=0
    private val stop=Runnable { stopSelf() }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?,flags: Int,startId: Int): Int {
        // A second due task replaces the single panel and its pending speech.
        val currentGeneration=++generation
        picker?.dismiss();picker=null
        handler.removeCallbacksAndMessages(null)
        speech?.stop(); speech?.shutdown(); speech=null
        tone?.release(); tone=null
        try {
            val root=TodoStore.read(this) ?: error("no_state")
            taskId=intent?.getStringExtra("todo_id") ?: error("no_task")
            val task=TodoReminders.tasks(root).firstOrNull { it.optString("id")==taskId } ?: error("no_task")
            val r=task.optJSONObject("reminder") ?: error("no_reminder")
            check(r.optBoolean("fired") && !task.optBoolean("done") && !TodoReminders.private(this,root))
            val at=TodoTime.instant(r.optString("at")) ?: error("no_time")
            check(System.currentTimeMillis()>=at && System.currentTimeMillis()-at<120000)
            val notification=Notification.Builder(this,TodoReminders.channel(this,false)).setSmallIcon(R.drawable.todo_notification)
                .setContentTitle("Bilga").setContentText(TodoReminders.label(root,"reminderMessage"))
                .setContentIntent(TodoNativeActions.pending(this,-1,task,"reminderMenu")).setOnlyAlertOnce(true).build()
            if(Build.VERSION.SDK_INT>=34) startForeground(902,notification,ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE)
            else startForeground(902,notification)
            removePanel(); speech?.shutdown(); speech=null
            val options=TodoReminders.settings(root)
            if(options.optBoolean("overlay") && Settings.canDrawOverlays(this) && !TodoReminders.foreground) {

                val box=LinearLayout(this).apply {
                    orientation=LinearLayout.VERTICAL; setPadding(dp(16),dp(10),dp(16),dp(16))
                    background=GradientDrawable().apply { setColor(WidgetTheme.background(this@TodoOverlayService)); cornerRadius=dp(20).toFloat(); setStroke(dp(1),WidgetTheme.accent(this@TodoOverlayService)) }
                    elevation=dp(12).toFloat(); filterTouchesWhenObscured=true
                }
                fun button(label: String, action: ()->Unit) = Button(this).apply {
                    text=label; WidgetTheme.button(this@TodoOverlayService,this,label==TodoReminders.label(root,"reminderDone")); filterTouchesWhenObscured=true
                    setOnClickListener { action() }
                }
                val head=LinearLayout(this).apply { orientation=LinearLayout.HORIZONTAL }
                head.addView(TextView(this).apply {
                    text=if(options.optBoolean("showTitles")) task.optString("title").ifBlank { TodoReminders.label(root,"reminderMessage") } else TodoReminders.label(root,"reminderMessage")
                    textSize=17f; setTextColor(WidgetTheme.foreground(this@TodoOverlayService)); maxLines=2
                },LinearLayout.LayoutParams(0,LinearLayout.LayoutParams.WRAP_CONTENT,1f))
                head.addView(button(TodoReminders.label(root,"close")) { stopSelf() })
                box.addView(head)
                box.addView(button(TodoReminders.label(root,"reminderDone")) { TodoNativeActions.receive(this,Intent().putExtra("id",taskId).putExtra("token",task.optString("actionToken")).putExtra("widget",-1).putExtra("operation","done")) { stopSelf() } })
                box.addView(TextView(this).apply { text=TodoReminders.label(root,"reminderSnooze"); setTextColor(WidgetTheme.foreground(this@TodoOverlayService)) })
                val groups=if(resources.configuration.fontScale>1.2f || resources.configuration.screenWidthDp<360) listOf(listOf(5),listOf(10),listOf(30),listOf(60),listOf(-1)) else listOf(listOf(5,10,30),listOf(60,-1))
                for(group in groups) {
                    val line=LinearLayout(this).apply { orientation=LinearLayout.HORIZONTAL }
                    for(minutes in group) line.addView(button(TodoReminders.label(root,when(minutes){5->"snooze5";10->"snooze10";30->"snooze30";60->"snooze60";else->"tomorrow"})) {
                        TodoNativeActions.receive(this,Intent().putExtra("id",taskId).putExtra("token",task.optString("actionToken")).putExtra("widget",-1).putExtra("operation","snooze").putExtra("minutes",minutes)) { stopSelf() }
                    },LinearLayout.LayoutParams(0,LinearLayout.LayoutParams.WRAP_CONTENT,1f))
                    box.addView(line)
                }
                box.addView(button(TodoReminders.label(root,"snoozeCustom")) { chooseTime(task) })
                val scroll=ScrollView(this).apply { isFillViewport=false; addView(box) }
                box.measure(View.MeasureSpec.makeMeasureSpec(minOf(resources.displayMetrics.widthPixels-dp(24),dp(480)),View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(0,View.MeasureSpec.UNSPECIFIED))
                val metrics=resources.displayMetrics
                val params=WindowManager.LayoutParams(minOf(metrics.widthPixels-dp(24),dp(480)),minOf(box.measuredHeight,(metrics.heightPixels*.8).toInt()),
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_SECURE,
                    PixelFormat.TRANSLUCENT).apply { gravity=Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL; y=dp(20) }
                getSystemService(WindowManager::class.java).addView(scroll,params); panel=scroll
            }
            if(options.optBoolean("tts") && (Build.VERSION.SDK_INT<37 || TodoReminders.foreground)) {
                var spoken=false
                val fallback=Runnable { if(!spoken) { spoken=true; beep() } }
                handler.postDelayed(fallback,3000)
                speech=TextToSpeech(this) { status ->
                    val tts=speech
                    if(currentGeneration==generation && status==TextToSpeech.SUCCESS && tts!=null) {
                        tts.setOnUtteranceProgressListener(object: UtteranceProgressListener() {
                            override fun onStart(id: String?) {}
                            override fun onDone(id: String?) { handler.post { if(currentGeneration==generation && panel==null) stopSelf() } }
                            @Suppress("DEPRECATION") override fun onError(id: String?) { handler.post { if(currentGeneration==generation) beep() } }
                            override fun onError(id: String?,code: Int) { handler.post { if(currentGeneration==generation) beep() } }
                        })
                        val locale=Locale.forLanguageTag(root.optString("language","en"))
                        val voice=tts.voices.orEmpty().filter { !it.isNetworkConnectionRequired && it.locale.language==locale.language &&
                            !it.features.orEmpty().contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) }.maxByOrNull { it.quality }
                        if(voice!=null && tts.setVoice(voice)==TextToSpeech.SUCCESS) {
                            spoken=true; handler.removeCallbacks(fallback)
                            val text=(options.optString("address").take(60)+" "+TodoReminders.label(root,"reminderMessage")).trim()
                            if(tts.speak(text,TextToSpeech.QUEUE_FLUSH,Bundle().apply { putInt(TextToSpeech.Engine.KEY_PARAM_STREAM,AudioManager.STREAM_NOTIFICATION) },"bilga-todo")==TextToSpeech.ERROR) beep()
                        }
                    }
                }
            }
            handler.removeCallbacks(stop); handler.postDelayed(stop,if(panel==null) 15000 else 45000)
        } catch (_: Exception) { stopSelf() }
        return START_NOT_STICKY
    }
    private fun dp(v: Int)=(v*resources.displayMetrics.density).toInt()
    private fun chooseTime(task: org.json.JSONObject) {
        if(!Settings.canDrawOverlays(this) || TodoReminders.locked(this)) return
        picker?.dismiss()
        // A bounded, secure native picker stays above the current app. It uses
        // the same capability/SQL transaction as the preset buttons.
        handler.removeCallbacks(stop);handler.postDelayed(stop,120000)
        val theme=if(Color.luminance(WidgetTheme.background(this))<.5) android.R.style.Theme_DeviceDefault_Dialog_Alert else android.R.style.Theme_DeviceDefault_Light_Dialog_Alert
        val themed=ContextThemeWrapper(this,theme)
        val selectedId=task.getString("id")
        val now=java.time.ZonedDateTime.now()
        fun show(dialog: AlertDialog) {
            picker=dialog
            dialog.window?.apply { setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY); addFlags(WindowManager.LayoutParams.FLAG_SECURE) }
            dialog.setOnCancelListener { picker=null;handler.removeCallbacks(stop);handler.postDelayed(stop,45000) }
            dialog.show()
            for(which in listOf(AlertDialog.BUTTON_POSITIVE,AlertDialog.BUTTON_NEGATIVE)) dialog.getButton(which)?.let { it.filterTouchesWhenObscured=true;WidgetTheme.button(this,it,which==AlertDialog.BUTTON_POSITIVE) }
        }
        show(DatePickerDialog(themed,{ _,year,month,day ->
            show(TimePickerDialog(themed,{ _,hour,minute ->
                picker=null
                val at=java.time.LocalDate.of(year,month+1,day).atTime(hour,minute).atZone(java.time.ZoneId.systemDefault()).toOffsetDateTime().toString()
                TodoNativeActions.receive(this,Intent().putExtra("id",selectedId).putExtra("token",task.optString("actionToken")).putExtra("widget",-1).putExtra("operation","snooze").putExtra("at",at)) { stopSelf() }
            },now.hour,now.minute,android.text.format.DateFormat.is24HourFormat(this)))
        },now.year,now.monthValue-1,now.dayOfMonth))
    }
    private fun beep() { try { tone?.release(); tone=ToneGenerator(AudioManager.STREAM_NOTIFICATION,65); tone?.startTone(ToneGenerator.TONE_PROP_BEEP,250) } catch (_: Exception) {} }
    private fun removePanel() { panel?.let { try { getSystemService(WindowManager::class.java).removeView(it) } catch (_: Exception) {} }; panel=null }
    override fun onTimeout(startId: Int) { stopSelf() }
    override fun onTimeout(startId: Int,fgsType: Int) { stopSelf() }
    override fun onDestroy() { generation++; handler.removeCallbacksAndMessages(null); picker?.dismiss();picker=null;removePanel(); speech?.stop(); speech?.shutdown(); tone?.release(); stopForeground(STOP_FOREGROUND_REMOVE); super.onDestroy() }
}
