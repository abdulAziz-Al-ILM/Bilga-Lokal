package com.ilmmizan.bilga

import android.content.*
import android.database.Cursor
import android.net.Uri
import android.os.*

/** Debug APK only. Shell-only, read-only, reserved synthetic fixture only.
 * Does not force-stop Bilga or cancel its alarms, unlike target instrumentation. */
class DebugFixtureInspector:ContentProvider() {
    override fun onCreate()=true
    override fun call(method:String,arg:String?,extras:Bundle?):Bundle {
        val c=requireNotNull(context)
        c.enforceCallingPermission(android.Manifest.permission.DUMP,"Shell diagnostics only")
        check(Binder.getCallingUid() in listOf(0,2000) && c.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE!=0)
        require(method=="inspectTodo" && arg in listOf("Bilga Recovery 20261016","Bilga Recovery 20261022"))
        val result=Bundle()
        try {
            val root=TodoStore.read(c) ?: error("no_mirror")
            check(TodoNativeActions.permitted(c,root))
            val task=TodoReminders.tasks(root).single { it.optString("title").contains(requireNotNull(arg)) }
            TodoNativeActions.open(c).use { db ->
                db.rawQuery("SELECT due_at,is_done,r.remind_at,r.fired,r.revision FROM todos t LEFT JOIN todo_reminders r ON r.todo_id=t.id WHERE instr(t.title,?)>0 AND t.is_deleted=0",arrayOf(arg)).use { row ->
                    check(row.count==1 && row.moveToFirst())
                    result.putString("deadline",row.getString(0));result.putBoolean("done",row.getInt(1)==1)
                    val at=TodoTime.instant(row.getString(2) ?: "")
                    result.putLong("reminderMillis",at ?: 0);result.putBoolean("fired",row.getInt(3)==1)
                    val mirror=task.optJSONObject("reminder")
                    result.putBoolean("mirrorMatches",at==mirror?.optString("at")?.let { TodoTime.instant(it) } && row.getString(4)==mirror?.optString("revision"))
                    result.putBoolean("blocked",root.optString("blockedTask")==task.optString("id"))
                }
            }
        } catch(e:Exception) { result.putString("error",e.javaClass.simpleName) }
        return result
    }
    override fun getType(uri:Uri):String?=null
    override fun query(uri:Uri,projection:Array<out String>?,selection:String?,selectionArgs:Array<out String>?,sortOrder:String?):Cursor?=null
    override fun insert(uri:Uri,values:ContentValues?):Uri?=throw UnsupportedOperationException()
    override fun update(uri:Uri,values:ContentValues?,selection:String?,selectionArgs:Array<out String>?):Int=throw UnsupportedOperationException()
    override fun delete(uri:Uri,selection:String?,selectionArgs:Array<out String>?):Int=throw UnsupportedOperationException()
}
