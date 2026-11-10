package com.ilmmizan.bilga

import android.app.Activity
import android.app.Instrumentation
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.os.Build
import android.os.Bundle
import java.io.File
import org.json.JSONArray

/** Device tests use reserved synthetic cache IDs, never notes/model/user files. */
class NotesWidgetChecks : Instrumentation() {
    private var fixtureTodo = false
    private var verifyTodo = false
    private var verifyEmpty = false
    private var fixtureSeconds: Int? = null
    override fun onCreate(arguments: Bundle?) {
        check(targetContext.packageName=="com.ilmmizan.bilga.review" &&
            targetContext.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE!=0)
        fixtureTodo = arguments?.getString("fixtureTodo") == "true"
        verifyTodo = arguments?.getString("todoChecks") == "true"
        verifyEmpty = arguments?.getString("verifyEmptySnapshots") == "true"
        fixtureSeconds = arguments?.getString("fixtureReminderSeconds")?.toInt()
        super.onCreate(arguments); start()
    }
    override fun onStart() {
        if(fixtureTodo) {
            val report=StringBuilder()
            var inspected=true
            try {
                val root=TodoStore.read(targetContext) ?: error("no_mirror")
                val task=TodoReminders.tasks(root).single { it.optString("title").contains("Bilga Recovery 20261016") }
                fixtureSeconds?.let { seconds ->
                    // Test setup only, absent from production APK. One unique
                    // UI-created synthetic task, unlocked/current access lease,
                    // existing encrypted DB/key and version-checked SQL transaction.
                    // Seed a real future alarm; never fake a due event or touch
                    // unrelated tasks. Caller opens Main to sync/schedule normally.
                    check(seconds in 30..120 && TodoNativeActions.permitted(targetContext,root))
                    TodoNativeActions.open(targetContext).use { db ->
                        db.rawQuery("SELECT id FROM todos WHERE instr(title,?)>0 AND is_deleted=0 AND is_done=0",arrayOf("Bilga Recovery 20261016")).use { row ->
                            check(row.count==1 && row.moveToFirst() && row.getString(0)==task.getString("id"))
                        }
                        val at=java.time.OffsetDateTime.now().plusSeconds(seconds.toLong()).toString()
                        TodoNativeActions.commit(db,task,"snooze",at)
                        report.append("Synthetic reminder setup: ").append(at).append('\n')
                    }
                }
                report.append("Synthetic mirror: due=").append(task.optString("due")).append(" reminder=").append(task.optJSONObject("reminder")?.optString("at"))
                    .append(" fired=").append(task.optJSONObject("reminder")?.optBoolean("fired"))
                    .append(" blocked=").append(root.optString("blockedTask")==task.optString("id"))
                    .append(" permitted=").append(TodoNativeActions.permitted(targetContext,root)).append('\n')
                // Only the exact fixture created through the UI; never export IDs,
                // tokens, keys, other rows, user content or full cache contents.
                if(TodoNativeActions.permitted(targetContext,root)) TodoNativeActions.open(targetContext).use { db ->
                    db.rawQuery("SELECT t.due_at,t.is_done,r.remind_at,r.fired FROM todos t LEFT JOIN todo_reminders r ON r.todo_id=t.id WHERE instr(t.title,?)>0 AND t.is_deleted=0",arrayOf("Bilga Recovery 20261016")).use { row ->
                        check(row.count==1 && row.moveToFirst())
                        report.append("Synthetic SQL: due=").append(row.getString(0)).append(" done=").append(row.getInt(1))
                            .append(" reminder=").append(row.getString(2)).append(" fired=").append(row.getInt(3)).append('\n')
                    }
                }
            } catch(e:Throwable) {
                inspected=false
                report.append("Fixture inspection failed: ").append(e.javaClass.simpleName)
                    .append(" at ").append(e.stackTrace.firstOrNull()?.let { "${it.fileName}:${it.lineNumber}" }).append('\n')
            }
            finish(if(inspected) Activity.RESULT_OK else Activity.RESULT_CANCELED,Bundle().apply { putString("stream",report.toString()) });return
        }
        if(verifyTodo) {
            val (ok,report)=TodoChecks.run(targetContext)
            finish(if(ok) Activity.RESULT_OK else Activity.RESULT_CANCELED,Bundle().apply { putString("stream",report) })
            return
        }
        if (verifyEmpty) {
            // Read on-device; export only pass/fail, never cache contents or note IDs.
            val empty = NotesWidgetStore.cachedIds(targetContext).all { id ->
                val value = NotesWidgetStore.read(targetContext, id)
                value != null && (value.optJSONArray("rows")?.length() ?: 0) == 0
            }
            finish(if (empty) Activity.RESULT_OK else Activity.RESULT_CANCELED,
                Bundle().apply { putString("stream", "App-owned widget snapshots empty: ${if (empty) "PASS" else "FAIL"}\n") })
            return
        }
        val first = 2147483001
        val second = 2147483002
        val context = targetContext
        var failure: String? = null
        var ownsFixtures=false
        try {
            check(listOf(first,second).none { File(context.noBackupFilesDir,"notes-widgets/$it.bin").exists() })
            val installed=AppWidgetManager.getInstance(context).getAppWidgetIds(android.content.ComponentName(context,NotesWidget::class.java))
            check(first !in installed && second !in installed)
            ownsFixtures=true
            check(NotesWidget.previewLines(200,140,1f)==2 && NotesWidget.previewLines(200,180,1f)==3 && NotesWidget.previewLines(200,140,2f)==0)
            val secret = "synthetic-widget-cache-sentinel-9381"
            val value = NotesWidget.defaults(first).put("test", secret)
            check(value.getString("privacy") == "hidden")
            NotesWidgetStore.write(context, first, value)
            val file = File(context.noBackupFilesDir, "notes-widgets/$first.bin")
            val bytes = file.readBytes()
            check(!String(bytes, Charsets.ISO_8859_1).contains(secret))
            check(NotesWidgetStore.read(context, first)?.getString("test") == secret)
            val other = File(context.noBackupFilesDir, "notes-widgets/$second.bin")
            other.writeBytes(bytes)
            check(NotesWidgetStore.read(context, second) == null) // Widget ID is authenticated.
            bytes[bytes.lastIndex] = (bytes.last().toInt() xor 1).toByte()
            file.writeBytes(bytes)
            check(NotesWidgetStore.read(context, first) == null) // Tampering fails closed.
            check(runCatching { NotesWidgetStore.readableOrNew(context,first) }.isFailure)
            check(file.exists()) // An unavailable/corrupt cache is never silently reset.
            val a = NotesWidget.pending(context, first, "open", "synthetic-one")
            val b = NotesWidget.pending(context, first, "open", "synthetic-two")
            val c = NotesWidget.pending(context, second, "open", "synthetic-one")
            check(a != b && a != c && b != c)
            if (Build.VERSION.SDK_INT >= 31) check(a.isImmutable && b.isImmutable && c.isImmutable)
            a.cancel(); b.cancel(); c.cancel()
            val provider = AppWidgetManager.getInstance(context).installedProviders.single { it.provider.packageName==context.packageName && it.provider.className == NotesWidget::class.java.name }
            check(provider.widgetCategory == AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN)
            check(provider.resizeMode == AppWidgetProviderInfo.RESIZE_BOTH)
            check(provider.configure?.className == NotesWidgetConfigureActivity::class.java.name)
            check(NotesWidgetConfigureActivity::class.java.superclass == Activity::class.java)
            val snapshot = NotesWidget.defaults(first).put("source", "pinned")
                .put("pinnedIds", JSONArray().put("synthetic-one"))
                .put("rows", JSONArray().put(secret)).put("permissionsVersion", 1).put("permissionEpoch", 7)
            check(NotesWidget.visibleRows(snapshot, 7, false).length() == 1)
            check(NotesWidget.visibleRows(snapshot, 8, false).length() == 0)
            check(NotesWidget.visibleRows(snapshot, 7, true).length() == 0)
            snapshot.remove("permissionsVersion")
            check(NotesWidget.visibleRows(snapshot, 7, false).length() == 0)
            NotesWidgetStore.write(context, first, snapshot)
            NotesWidgetStore.clearSnapshots(context,8,intArrayOf(first),readValue={null})
            check(NotesWidgetStore.read(context,first)?.optString("source")=="pinned")
            NotesWidgetStore.clearSnapshots(context, 8, intArrayOf(first, second))
            val cleared = NotesWidgetStore.read(context, first)!!
            check(cleared.getJSONArray("rows").length() == 0 && !cleared.toString().contains(secret))
            check(cleared.getString("source") == "pinned" && cleared.getJSONArray("pinnedIds").getString(0) == "synthetic-one")
        } catch (e: Throwable) {
            failure = e.javaClass.simpleName
        } finally {
            if(ownsFixtures) { NotesWidgetStore.delete(context, first); NotesWidgetStore.delete(context, second) }
        }
        finish(if (failure == null) Activity.RESULT_OK else Activity.RESULT_CANCELED,
            Bundle().apply { putString("stream", if (failure == null) "Notes widget native checks: 13 PASS (safe default, encryption, readback, ID binding, tampering, PendingIntent isolation, immutable intents, provider metadata, permission epoch, snapshot clearing)\n" else "Notes widget native checks FAILED: $failure\n") })
    }
}
