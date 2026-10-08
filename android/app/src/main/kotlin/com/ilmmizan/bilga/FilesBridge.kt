package com.ilmmizan.bilga
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.Closeable
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors
class FilesBridge(private val activity:Activity,messenger:BinaryMessenger){
 private val channel=MethodChannel(messenger,"bilga/files")
 private val worker=Executors.newSingleThreadExecutor()
 private val handles=mutableMapOf<String,Closeable>()
 private var picker:MethodChannel.Result?=null
 private var incoming:Intent?=null
 init{channel.setMethodCallHandler{call,result ->
  when(call.method){
   "pick","create"->{if(picker!=null){result.error("busy","Picker open",null);return@setMethodCallHandler};picker=result
    try{val i=if(call.method=="pick") Intent(Intent.ACTION_OPEN_DOCUMENT).apply{type="*/*";addCategory(Intent.CATEGORY_OPENABLE);putExtra(Intent.EXTRA_ALLOW_MULTIPLE,true)}else Intent(Intent.ACTION_CREATE_DOCUMENT).apply{type=call.argument<String>("mime")?:"application/octet-stream";addCategory(Intent.CATEGORY_OPENABLE);putExtra(Intent.EXTRA_TITLE,call.argument<String>("name")?:"Bilga.bilga2")};activity.startActivityForResult(i,if(call.method=="pick")751 else 752)}catch(_:Exception){picker=null;result.error("picker","Picker unavailable",null)}
   }
   "consume"->{val i=incoming;incoming=null;worker.execute{try{val rows=i?.let{streams(it).map{u->metadata(u)}}?:emptyList();val text=i?.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.take(100000)?:"";activity.runOnUiThread{result.success(mapOf("files" to rows,"text" to text))}}catch(_:Exception){activity.runOnUiThread{result.error("share","Cannot read share",null)}}}}
   else->worker.execute{try{val value:Any?=when(call.method){
    "openRead"->{val u=Uri.parse(call.argument<String>("uri"));require(u.scheme=="content");val t=UUID.randomUUID().toString();handles[t]=activity.contentResolver.openInputStream(u)?:error("missing");t}
    "openWrite"->{val u=Uri.parse(call.argument<String>("uri"));require(u.scheme=="content");val t=UUID.randomUUID().toString();handles[t]=activity.contentResolver.openOutputStream(u,"wt")?:error("missing");t}
    "read"->{val b=ByteArray(65536);val n=(handles[call.argument<String>("token")] as InputStream).read(b);if(n<0)ByteArray(0)else b.copyOf(n)}
    "write"->{val b=call.argument<ByteArray>("bytes")?:error("bytes");require(b.size<=1048576);(handles[call.argument<String>("token")] as OutputStream).write(b);null}
    "close"->{handles.remove(call.argument<String>("token"))?.close();null}
    else->error("method")};activity.runOnUiThread{result.success(value)}}catch(_:Exception){activity.runOnUiThread{result.error("file_io","File operation failed",null)}}}
  }
 }}
 @Suppress("DEPRECATION") private fun streams(i:Intent):List<Uri>{val r=mutableListOf<Uri>();if(i.action==Intent.ACTION_SEND_MULTIPLE)i.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let{r.addAll(it)}else i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let{r.add(it)};i.clipData?.let{c->for(n in 0 until c.itemCount.coerceAtMost(20))c.getItemAt(n).uri?.let{r.add(it)}};return r.distinct().filter{it.scheme=="content"}.take(20)}
 private fun metadata(u:Uri):Map<String,Any?>{var name="File";var size=-1L;activity.contentResolver.query(u,arrayOf(OpenableColumns.DISPLAY_NAME,OpenableColumns.SIZE),null,null,null)?.use{c->if(c.moveToFirst()){val n=c.getColumnIndex(OpenableColumns.DISPLAY_NAME);val s=c.getColumnIndex(OpenableColumns.SIZE);if(n>=0&&!c.isNull(n))name=c.getString(n).take(200);if(s>=0&&!c.isNull(s))size=c.getLong(s)}};return mapOf("uri" to u.toString(),"name" to name,"size" to size,"mime" to(activity.contentResolver.getType(u)?:"application/octet-stream"))}
 fun receive(i:Intent?){if(i?.action==Intent.ACTION_SEND||i?.action==Intent.ACTION_SEND_MULTIPLE){incoming=i;channel.invokeMethod("incoming",null)}}
 fun activityResult(request:Int,code:Int,data:Intent?):Boolean{if(request!=751&&request!=752)return false;val cb=picker?:return true;picker=null;if(code!=Activity.RESULT_OK||data==null){cb.success(null);return true};if(request==752){cb.success(data.data?.toString());return true};worker.execute{try{val rows=(streams(data)+listOfNotNull(data.data)).distinct().take(20).map{metadata(it)};activity.runOnUiThread{cb.success(rows)}}catch(_:Exception){activity.runOnUiThread{cb.error("picker","Cannot read",null)}}};return true}
 fun close(){channel.setMethodCallHandler(null);worker.execute{handles.values.forEach{try{it.close()}catch(_:Exception){}};handles.clear()};worker.shutdown()}
}
