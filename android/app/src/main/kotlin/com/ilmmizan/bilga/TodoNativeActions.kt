package com.ilmmizan.bilga

import android.app.*
import android.content.*
import android.net.Uri
import android.os.*
import android.provider.Settings
import android.widget.Toast
import net.zetetic.database.sqlcipher.SQLiteDatabase
import org.json.JSONObject
import java.time.LocalDateTime
import java.util.UUID
import java.util.concurrent.Executors

/** Immutable capabilities, unlocked device, current SQL version, atomic SQL first. */
internal object TodoNativeActions {
    const val ACTION="com.ilmmizan.bilga.TODO_NATIVE_ACTION"
    private val executor=Executors.newSingleThreadExecutor()
    internal fun permitted(c:Context,root:JSONObject):Boolean {
        val prefs=c.getSharedPreferences("FlutterSharedPreferences",Context.MODE_PRIVATE)
        val wall=System.currentTimeMillis(); val issued=root.optLong("actionWall")
        val duration=root.optLong("actionUntil")-issued
        return !TodoReminders.private(c,root) && !prefs.getBoolean("flutter.bilga.appLock",false) &&
            issued>0 && wall>=issued-300000 && wall<root.optLong("actionUntil") &&
            root.optInt("actionBoot",-1)==Settings.Global.getInt(c.contentResolver,Settings.Global.BOOT_COUNT,-2) &&
            SystemClock.elapsedRealtime()-root.optLong("actionElapsed") in 0 until duration
    }
    fun pending(c:Context,widget:Int,task:JSONObject,action:String,minutes:Int=0):PendingIntent {
        val token=task.optString("actionToken")
        val intent=Intent(c,TodoActionReceiver::class.java).setAction(ACTION)
            .setData(Uri.Builder().scheme("bilga-todo-action").authority(widget.toString()).appendPath(task.getString("id"))
                .appendPath(token).appendPath(action).appendPath(minutes.toString()).build())
            .putExtra("widget",widget).putExtra("id",task.getString("id")).putExtra("token",token)
            .putExtra("operation",action).putExtra("minutes",minutes)
        return PendingIntent.getBroadcast(c,0,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    internal fun open(c:Context):SQLiteDatabase {
        val path=c.getDatabasePath("bilga_todo.db");check(path.isFile)
        val key=VaultBridge.existingDatabaseKey(c)
        try {
            System.loadLibrary("sqlcipher")
            // Explicit corruption handler: never delete/recreate a user's database.
            val db=SQLiteDatabase.openDatabase(path.path,key,null,SQLiteDatabase.OPEN_READWRITE,
                net.zetetic.database.DatabaseErrorHandler { _, error -> throw error },null)
            try {
                configure(db)
                return db
            } catch(e:Throwable) { db.close();throw e }
        } finally { key.fill(0) }
    }
    internal fun configure(db:SQLiteDatabase) {
        check(db.version==8) { "unsupported_schema" }
        // Result-bearing PRAGMAs require a read, not execSQL or an unopened cursor.
        db.rawQuery("PRAGMA busy_timeout=2000",emptyArray<String>()).use { check(it.moveToFirst()) }
        db.execSQL("PRAGMA foreign_keys=ON")
        db.execSQL("PRAGMA synchronous=FULL")
        db.rawQuery("PRAGMA secure_delete=ON",emptyArray<String>()).use { check(it.moveToFirst()) }
    }
    internal fun commit(db:SQLiteDatabase,task:JSONObject,operation:String,at:String?):JSONObject {
        val id=task.getString("id");val updated=task.getString("version")
        db.beginTransaction()
        try {
            val valid=db.rawQuery("""WITH RECURSIVE hidden(id) AS (
                SELECT id FROM todo_folders WHERE is_deleted=1 UNION
                SELECT f.id FROM todo_folders f JOIN hidden h ON f.parent_id=h.id)
                SELECT id FROM todos WHERE id=? AND updated_at=? AND is_deleted=0 AND is_done=0
                AND (folder_id IS NULL OR folder_id NOT IN (SELECT id FROM hidden))""",arrayOf(id,updated)).use { it.moveToFirst() }
            check(valid)
            val next=JSONObject(task.toString())
            if(operation=="done") {
                val now=LocalDateTime.now().toString()
                db.execSQL("UPDATE todos SET is_done=1,completed_at=?,updated_at=? WHERE id=? AND is_done=0 AND updated_at=?",arrayOf(now,now,id,updated))
                next.put("done",true).put("version",now).remove("reminder")
            } else {
                require(operation=="snooze" && (TodoTime.instant(at ?: "") ?: 0)>System.currentTimeMillis())
                val revision=UUID.randomUUID().toString()
                db.execSQL("INSERT OR REPLACE INTO todo_reminders(todo_id,enabled,remind_at,revision,fired) VALUES(?,1,?,?,0)",arrayOf(id,at,revision))
                next.put("reminder",JSONObject().put("at",at).put("revision",revision).put("fired",false).put("nonce",UUID.randomUUID().toString()))
            }
            next.put("actionToken",UUID.randomUUID().toString())
            db.setTransactionSuccessful();return next
        } finally { db.endTransaction() }
    }
    @Synchronized fun perform(c:Context,intent:Intent):Boolean = synchronized(TodoReminders) {
        val root=TodoStore.read(c) ?: return false
        if(!permitted(c,root)) return false
        val id=intent.getStringExtra("id") ?: return false
        val widget=intent.getIntExtra("widget",-1)
        if(widget!=-1 && !TodoWidget.ids(c).contains(widget)) return false
        val task=TodoReminders.tasks(root).firstOrNull { it.optString("id")==id && !it.optBoolean("done") } ?: return false
        val token=intent.getStringExtra("token") ?: return false
        if(token.isEmpty() || token!=task.optString("actionToken")) return false
        val op=intent.getStringExtra("operation") ?: return false
        if(widget==-1 && (task.optJSONObject("reminder")?.optBoolean("fired")!=true || !TodoTime.dueNow(JSONObject(task.toString()).apply { getJSONObject("reminder").put("fired",false) },System.currentTimeMillis()))) return false
        if(op=="menu") {
            val config=root.optJSONObject("widgets")?.optJSONObject(widget.toString()) ?: JSONObject().also {
                val widgets=root.optJSONObject("widgets") ?: JSONObject().also { root.put("widgets",it) }
                widgets.put(widget.toString(),it)
            }
            config.put("snoozeTask",if(config.optString("snoozeTask")==id) "" else id)
            TodoStore.write(c,root);TodoWidget.refresh(c);return true
        }
        val at=if(op=="snooze") TodoTime.snooze(intent.getIntExtra("minutes",0)) else null
        // A crash between SQL commit and cache publication hides this task until
        // app sync. It must never generate a stale reminder after completion.
        root.put("blockedTask",id).put("sqlEpoch",root.optLong("sqlEpoch")+1);TodoStore.write(c,root)
        try {
            val next=open(c).use { db -> commit(db,task,op,at) }
            val tasks=root.getJSONArray("tasks")
            for(i in 0 until tasks.length()) if(tasks.getJSONObject(i).optString("id")==id) tasks.put(i,next)
            root.optJSONObject("events")?.remove(id)
            root.optJSONObject("widgets")?.keys()?.forEach { root.getJSONObject("widgets").getJSONObject(it).remove("snoozeTask") }
            root.remove("blockedTask");root.put("sqlEpoch",root.optLong("sqlEpoch")+1)
            TodoStore.write(c,root)
            c.getSystemService(NotificationManager::class.java).cancel(id,901)
            c.stopService(Intent(c,TodoOverlayService::class.java))
            TodoWidget.refresh(c);TodoReminders.schedule(c,root)
            Handler(Looper.getMainLooper()).post { TodoReminders.bridge?.changed() }
            true
        } catch (_:Exception) {
            // Keep blockedTask: transaction outcome may be uncertain. Fresh app
            // SQL sync recovers it; no plaintext/optimistic state or destructive repair.
            TodoWidget.refresh(c);TodoReminders.schedule(c)
            Handler(Looper.getMainLooper()).post { TodoReminders.bridge?.changed() }
            false
        }
    }
    fun receive(c:Context,intent:Intent,finished:()->Unit) {
        executor.execute {
            val ok=try { perform(c,intent) } catch (_:Exception) { false }
            Handler(Looper.getMainLooper()).post {
                if(!ok) Toast.makeText(c,c.getString(R.string.tw_limits),Toast.LENGTH_LONG).show()
                finished()
            }
        }
    }
}
class TodoActionReceiver:BroadcastReceiver() {
    override fun onReceive(c:Context,intent:Intent) {
        if(intent.action!=TodoNativeActions.ACTION) return
        val pending=goAsync();TodoNativeActions.receive(c.applicationContext,intent) { pending.finish() }
    }
}
