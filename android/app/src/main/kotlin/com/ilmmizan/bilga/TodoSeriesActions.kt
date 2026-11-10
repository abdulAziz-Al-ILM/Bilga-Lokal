package com.ilmmizan.bilga

import net.zetetic.database.sqlcipher.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.*
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.Locale
import java.util.UUID

/** Called inside the original completion transaction, never an optimistic copy. */
internal object TodoSeriesActions {
    private fun integer(data:JSONObject,key:String,min:Int,max:Int):Int {
        val raw=data.get(key)
        require(raw is Int || raw is Long)
        val number=(raw as Number).toLong()
        require(number in min.toLong()..max.toLong())
        return number.toInt()
    }
    private fun keys(data:JSONObject,allowed:Set<String>) {
        require(data.keys().asSequence().all { it in allowed })
    }
    private fun rule(raw:String):TaskRecurrence.Rule {
        require(raw.length<=2048)
        val data=JSONObject(raw)
        keys(data,setOf("version","unit","interval","weekdays","until"))
        require(integer(data,"version",1,1)==1)
        val unit=TaskRecurrence.Unit.valueOf(data.getString("unit").uppercase(Locale.ROOT))
        val interval=integer(data,"interval",1,365)
        val source=if(data.isNull("weekdays")) JSONArray() else data.getJSONArray("weekdays")
        val days=mutableSetOf<Int>()
        for(i in 0 until source.length()) {
            val value=source.get(i);require(value is Int || value is Long)
            val number=(value as Number).toLong();require(number in 1L..7L)
            require(days.add(number.toInt()))
        }
        val until=if(data.isNull("until")) null else LocalDate.parse(data.getString("until"))
        return TaskRecurrence.Rule(unit,interval,days,until)
    }
    private fun template(raw:String):JSONObject {
        require(raw.toByteArray(StandardCharsets.UTF_8).size<=4*1024*1024)
        val data=JSONObject(raw)
        keys(data,setOf("version","title","description","priority","folder_id","reminder","checklist"))
        integer(data,"version",1,1);integer(data,"priority",0,3)
        require(data.get("title") is String && data.getString("title").isNotBlank() && data.getString("title").length<=100000)
        require(data.get("description") is String && data.getString("description").length<=1000000)
        require(data.isNull("folder_id") || data.get("folder_id") is String)
        if(data.has("checklist")) {
            val items=data.getJSONArray("checklist");require(items.length()<=200)
            for(i in 0 until items.length()) {
                val item=items.get(i)
                require(item is String && item.isNotBlank() && item.length<=2000)
            }
        }
        if(!data.isNull("reminder")) {
            val pattern=data.getJSONObject("reminder")
            require(pattern.length()==6)
            integer(pattern,"days",-3660000,3660000)
            integer(pattern,"hour",0,23);integer(pattern,"minute",0,59);integer(pattern,"second",0,59)
            integer(pattern,"millisecond",0,999);integer(pattern,"microsecond",0,999)
        }
        return data
    }
    private fun parse(text:String):Pair<ZonedDateTime,Boolean> = try {
        OffsetDateTime.parse(text).toInstant().atZone(ZoneOffset.UTC) to true
    } catch(_:DateTimeParseException) {
        LocalDateTime.parse(text).atZone(ZoneId.systemDefault()) to false
    }
    private fun format(date:ZonedDateTime,utc:Boolean):String {
        val pattern=if(date.nano%1000000==0) "uuuu-MM-dd'T'HH:mm:ss.SSS" else "uuuu-MM-dd'T'HH:mm:ss.SSSSSS"
        return date.format(DateTimeFormatter.ofPattern(pattern,Locale.ROOT)) + if(utc) "Z" else ""
    }
    private fun folder(db:SQLiteDatabase,original:String?):String? {
        var current=original
        val seen=mutableSetOf<String>()
        while(current!=null) {
            val id=current
            if(!seen.add(id)) return null
            current=db.rawQuery("SELECT parent_id,is_deleted FROM todo_folders WHERE id=?",arrayOf(id)).use {
                if(!it.moveToFirst() || it.getInt(1)!=0) return null
                if(it.isNull(0)) null else it.getString(0)
            }
        }
        return original
    }
    private fun occurrenceId(series:String,sequence:Long):String {
        val hash=MessageDigest.getInstance("SHA-256").digest(series.toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { String.format(Locale.ROOT,"%02x",it.toInt() and 255) }
        return "occurrence:$hash:$sequence"
    }

    fun advance(db:SQLiteDatabase,id:String,stamp:String,clock:Instant=Instant.now()):JSONObject? {
        // Native action fixtures and already-installed older schemas still work.
        if(db.version<10) return null
        val row=db.rawQuery("""SELECT s.id,s.rule,s.anchor_at,s.template,s.current_sequence,o.nominal_at
            FROM todo_series s JOIN todo_occurrences o ON o.series_id=s.id
            WHERE o.todo_id=? AND s.head_task_id=? AND s.active=1""",arrayOf(id,id)).use {
            if(!it.moveToFirst()) return null
            listOf(it.getString(0),it.getString(1),it.getString(2),it.getString(3),it.getLong(4).toString(),it.getString(5))
        }
        val series=row[0];val (anchor,utc)=parse(row[2]);val nominal=parse(row[5]).first.toInstant()
        val cutoff=if(nominal.isAfter(clock)) nominal else clock
        val next=TaskRecurrence.next(rule(row[1]),anchor,cutoff)
        if(next==null) {
            db.execSQL("UPDATE todo_series SET active=0,updated_at=? WHERE id=?",arrayOf(stamp,series))
            return null
        }
        val data=template(row[3]);val sequence=row[4].toLong()+1
        val nextId=occurrenceId(series,sequence);val due=format(next,utc)
        val destination=folder(db,if(data.isNull("folder_id")) null else data.getString("folder_id"))
        db.execSQL("""INSERT INTO todos(id,title,description,priority,due_at,folder_id,is_done,is_deleted,created_at,updated_at)
            VALUES(?,?,?,?,?,?,0,0,?,?)""",arrayOf<Any?>(nextId,data.getString("title"),data.getString("description"),data.getInt("priority"),due,destination,stamp,stamp))
        db.execSQL("INSERT INTO todo_occurrences(todo_id,series_id,sequence,nominal_at) VALUES(?,?,?,?)",arrayOf<Any?>(nextId,series,sequence,due))
        if(db.version>=11 && data.has("checklist")) {
            val items=data.getJSONArray("checklist")
            for(i in 0 until items.length()) db.execSQL(
                "INSERT INTO todo_checklist(id,todo_id,title,is_done,position) VALUES(?,?,?,0,?)",
                arrayOf<Any?>("check:${UUID.randomUUID()}",nextId,items.getString(i),i))
        }
        db.execSQL("UPDATE todo_series SET head_task_id=?,current_sequence=?,updated_at=? WHERE id=?",arrayOf<Any?>(nextId,sequence,stamp,series))
        val task=JSONObject().put("id",nextId).put("title",data.getString("title")).put("version",stamp)
            .put("series",series).put("sequence",sequence)
            .put("due",due).put("done",false).put("widgetAllowed",false).put("actionToken",UUID.randomUUID().toString())
        if(!data.isNull("reminder")) {
            val pattern=data.getJSONObject("reminder")
            val local=next.toLocalDate().plusDays(pattern.getInt("days").toLong()).atTime(
                pattern.getInt("hour"),pattern.getInt("minute"),pattern.getInt("second"),
                (pattern.getInt("millisecond")*1000+pattern.getInt("microsecond"))*1000).atZone(anchor.zone)
            val at=format(local,utc);val revision=UUID.randomUUID().toString();val fired=!local.toInstant().isAfter(clock)
            db.execSQL("INSERT INTO todo_reminders(todo_id,enabled,remind_at,revision,fired) VALUES(?,1,?,?,?)",arrayOf<Any?>(nextId,at,revision,if(fired)1 else 0))
            task.put("reminder",JSONObject().put("at",at).put("revision",revision).put("fired",fired).put("nonce",UUID.randomUUID().toString()))
        }
        return task
    }
}
