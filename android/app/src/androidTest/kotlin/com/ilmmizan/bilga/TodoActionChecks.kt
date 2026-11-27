package com.ilmmizan.bilga

import android.content.*
import android.os.*
import android.provider.Settings
import net.zetetic.database.sqlcipher.SQLiteDatabase
import org.json.JSONObject
import java.io.File

/** Real SQLCipher, synthetic key/file only; never opens the user database. */
internal object TodoActionChecks {
 fun run(c:Context,directory:File):Int {
  var n=0
  fun verify(ok:Boolean) { check(ok);n++ }
  System.loadLibrary("sqlcipher")
  directory.mkdirs()
  val db=SQLiteDatabase.openDatabase(File(directory,"synthetic-action.db").path,"synthetic-only-9381".toByteArray(),null,
   SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.CREATE_IF_NECESSARY,net.zetetic.database.DatabaseErrorHandler { _,error -> throw error },null)
  db.use {
   db.version=9
   TodoNativeActions.configure(db)
   verify(db.rawQuery("PRAGMA busy_timeout",emptyArray<String>()).use { it.moveToFirst();it.getInt(0)==2000 } &&
    db.rawQuery("PRAGMA secure_delete",emptyArray<String>()).use { it.moveToFirst();it.getInt(0)==1 })
   db.execSQL("CREATE TABLE todos(id TEXT PRIMARY KEY,title TEXT,updated_at TEXT,is_done INTEGER DEFAULT 0,is_deleted INTEGER DEFAULT 0,folder_id TEXT,due_at TEXT,completed_at TEXT)")
   db.execSQL("CREATE TABLE todo_folders(id TEXT,parent_id TEXT,is_deleted INTEGER DEFAULT 0)")
   db.execSQL("CREATE TABLE todo_reminders(todo_id TEXT PRIMARY KEY,enabled INTEGER,remind_at TEXT,revision TEXT,fired INTEGER)")
   db.execSQL("CREATE TRIGGER cancel AFTER UPDATE OF is_done ON todos WHEN NEW.is_done=1 BEGIN DELETE FROM todo_reminders WHERE todo_id=NEW.id;END")
   db.execSQL("INSERT INTO todos(id,title,updated_at,due_at) VALUES('a','Synthetic','old','2030-01-01T10:00:00')")
   val task=JSONObject().put("id","a").put("version","old").put("due","2030-01-01T10:00:00")
   val at=TodoTime.snooze(5)
   val snoozed=TodoNativeActions.commit(db,task,"snooze",at)
   verify(db.rawQuery("SELECT due_at,updated_at FROM todos",emptyArray<String>()).use { it.moveToFirst();it.getString(0)=="2030-01-01T10:00:00" && it.getString(1)=="old" })
   verify(db.rawQuery("SELECT remind_at,revision FROM todo_reminders",emptyArray<String>()).use { it.moveToFirst();it.getString(0)==at && it.getString(1)==snoozed.getJSONObject("reminder").getString("revision") })
   val custom=TodoNativeActions.commit(db,snoozed,"snooze","2031-01-02T11:20:00+05:00")
   verify(db.rawQuery("SELECT t.due_at,r.remind_at FROM todos t JOIN todo_reminders r ON r.todo_id=t.id",emptyArray<String>()).use { it.moveToFirst();it.getString(0)=="2030-01-01T10:00:00" && it.getString(1)=="2031-01-02T11:20:00+05:00" })
   val done=TodoNativeActions.commit(db,custom,"done",null)
   verify(done.optBoolean("done") && !done.has("reminder") && done.optString("actionToken")!=snoozed.optString("actionToken"))
   verify(db.rawQuery("SELECT COUNT(*) FROM todo_reminders",emptyArray<String>()).use { it.moveToFirst();it.getInt(0)==0 })
   verify(runCatching { TodoNativeActions.commit(db,task,"done",null) }.isFailure)
   db.execSQL("UPDATE todos SET is_done=0,is_deleted=1,updated_at='old' WHERE id='a'")
   verify(runCatching { TodoNativeActions.commit(db,task,"snooze",at) }.isFailure)
   db.execSQL("UPDATE todos SET is_deleted=0,folder_id='hidden' WHERE id='a'")
   db.execSQL("INSERT INTO todo_folders(id,is_deleted) VALUES('hidden',1)")
   verify(runCatching { TodoNativeActions.commit(db,task,"done",null) }.isFailure)
   db.execSQL("UPDATE todos SET folder_id=NULL WHERE id='a'")
   db.execSQL("CREATE TRIGGER fail_action BEFORE UPDATE ON todos BEGIN SELECT RAISE(ABORT,'synthetic'); END")
   verify(runCatching { TodoNativeActions.commit(db,task,"done",null) }.isFailure && db.rawQuery("SELECT is_done FROM todos",emptyArray<String>()).use { it.moveToFirst();it.getInt(0)==0 })
  }
  val prefs=c.getSharedPreferences("synthetic-native-action-9381",Context.MODE_PRIVATE)
  prefs.edit().putBoolean("flutter.bilga.appLock",false).commit()
  val isolated=object:ContextWrapper(c) {
   override fun getSharedPreferences(name:String,mode:Int)=if(name=="FlutterSharedPreferences") prefs else super.getSharedPreferences(name,mode)
  }
  val wall=System.currentTimeMillis()
  val root=JSONObject().put("redacted",true).put("actionWall",wall).put("actionUntil",wall+60000)
   .put("actionBoot",Settings.Global.getInt(c.contentResolver,Settings.Global.BOOT_COUNT,-1)).put("actionElapsed",SystemClock.elapsedRealtime())
  verify(!TodoNativeActions.permitted(isolated,root))
  root.put("redacted",false).put("actionUntil",wall-1)
  verify(!TodoNativeActions.permitted(isolated,root))
  root.put("actionUntil",wall+60000)
  prefs.edit().putBoolean("flutter.bilga.appLock",true).commit()
  verify(!TodoNativeActions.permitted(isolated,root))
  prefs.edit().putBoolean("flutter.bilga.appLock",false).commit()
  verify(TodoReminders.locked(c) || TodoNativeActions.permitted(isolated,root))
  val themeContext=object:ContextWrapper(c) {
   override fun getSharedPreferences(name:String,mode:Int)=if(name=="bilga-widget-theme") prefs else super.getSharedPreferences(name,mode)
  }
  for(dark in listOf(false,true)) {
   val foreground=if(dark) android.graphics.Color.WHITE else android.graphics.Color.BLACK
   prefs.edit().putInt("foreground",foreground).putInt("container",if(dark) android.graphics.Color.BLACK else android.graphics.Color.WHITE).commit()
   val button=android.widget.Button(themeContext)
   WidgetTheme.button(themeContext,button)
   verify(button.currentTextColor==foreground && button.backgroundTintList==null && button.minHeight>=(48*c.resources.displayMetrics.density).toInt())
  }
  val main=c.packageManager.getActivityInfo(ComponentName(c,MainActivity::class.java),0)
  verify(main.launchMode==android.content.pm.ActivityInfo.LAUNCH_SINGLE_TASK && !main.taskAffinity.isNullOrEmpty())
  for(activity in listOf(TodoHandoff::class.java,NotesWidgetConfigureActivity::class.java)) {
   val info=c.packageManager.getActivityInfo(ComponentName(c,activity),0)
   verify(info.taskAffinity.isNullOrEmpty() && info.flags and android.content.pm.ActivityInfo.FLAG_EXCLUDE_FROM_RECENTS!=0)
  }
  val task=JSONObject().put("id","synthetic-a").put("actionToken","token-1")
  val a=TodoNativeActions.pending(c,2147483003,task,"done")
  val b=TodoNativeActions.pending(c,2147483003,task,"snooze",5)
  task.put("actionToken","token-2")
  val d=TodoNativeActions.pending(c,2147483003,task,"done")
  verify(a!=b && a!=d && (Build.VERSION.SDK_INT<31 || a.isImmutable))
  a.cancel();b.cancel();d.cancel();prefs.edit().clear().commit()
  verify(!c.packageManager.getReceiverInfo(ComponentName(c,TodoActionReceiver::class.java),0).exported)
  val customActivity=c.packageManager.getActivityInfo(ComponentName(c,TodoSnoozeActivity::class.java),0)
  verify(!customActivity.exported && customActivity.taskAffinity.isNullOrEmpty() && customActivity.flags and android.content.pm.ActivityInfo.FLAG_EXCLUDE_FROM_RECENTS!=0)
  val customPending=TodoSnoozeActivity.pending(c,2147483003,task)
  verify(customPending.isActivity && (Build.VERSION.SDK_INT<31 || customPending.isImmutable))
  customPending.cancel()
  val guarded=JSONObject().put("id","guarded").put("actionToken","safe-token").put("done",false)
   .put("reminder",JSONObject().put("at",java.time.Instant.now().minusSeconds(1).toString()).put("fired",true))
  root.put("tasks",org.json.JSONArray().put(guarded))
  val request=Intent().putExtra("widget",-1).putExtra("id","guarded").putExtra("token","wrong-token")
  verify(TodoNativeActions.authorizedTask(isolated,root,request)==null)
  request.putExtra("token","safe-token")
  root.put("blockedTask","guarded")
  verify(TodoNativeActions.authorizedTask(isolated,root,request)==null)
  root.remove("blockedTask")
  guarded.put("done",true)
  verify(TodoNativeActions.authorizedTask(isolated,root,request)==null)
  val reminderTask=JSONObject().put("id","synthetic-notification").put("actionToken","synthetic-token")
   .put("reminder",JSONObject().put("nonce","synthetic-nonce"))
  val notification=TodoReminders.notification(c,JSONObject(),reminderTask,snoozeMenu=true)
  verify(notification.actions.size==2 && notification.actions.all { Build.VERSION.SDK_INT<31 || (it.actionIntent.isBroadcast && it.actionIntent.isImmutable) })
  verify(notification.bigContentView!=null && notification.headsUpContentView!=null && notification.publicVersion!=null)
  verify(Build.VERSION.SDK_INT<31 || (notification.contentIntent.isBroadcast && notification.contentIntent.isImmutable))
  notification.actions.forEach { it.actionIntent.cancel() }
  return n
 }
}
