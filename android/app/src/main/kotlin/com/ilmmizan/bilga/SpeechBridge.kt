package com.ilmmizan.bilga

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Explicit foreground push-to-talk. No service, restart loop or audio storage. */
internal class SpeechBridge(private val activity:Activity,messenger:BinaryMessenger) {
    private val channel=MethodChannel(messenger,"bilga/speech")
    private val handler=Handler(Looper.getMainLooper())
    private var recognizer:SpeechRecognizer?=null
    private var pending:MethodChannel.Result?=null
    private var language="uz-UZ"
    private var deviceOnly=true
    private var foreground=true
    private var awaitingPermission=false
    private var generation=0
    private val deadline=Runnable { finishError("timeout") }
    init {
        channel.setMethodCallHandler { call,result ->
            when(call.method) {
                "state" -> result.success(mapOf("available" to SpeechRecognizer.isRecognitionAvailable(activity),"onDevice" to onDevice(),"microphoneAllowed" to (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED)))
                "listen" -> {
                    if(pending!=null){result.error("busy",null,null);return@setMethodCallHandler}
                    val requested=call.argument<String>("language")?:"uz-UZ"
                    if(!requested.matches(Regex("[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*"))) {result.error("language",null,null);return@setMethodCallHandler}
                    language=requested;deviceOnly=call.argument<Boolean>("onDevice")==true
                    if(!foreground){result.error("background",null,null);return@setMethodCallHandler}
                    if(deviceOnly&&!onDevice() || !deviceOnly&&!SpeechRecognizer.isRecognitionAvailable(activity)){result.error("unavailable",null,null);return@setMethodCallHandler}
                    generation++;pending=result
                    // Permission is requested ONLY in this explicit button-initiated method.
                    if(activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED){
                        awaitingPermission=true;activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO),REQUEST)
                    }else start()
                }
                "settings" -> {activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:${activity.packageName}")));result.success(null)}
                "stop" -> {recognizer?.stopListening();result.success(null)}
                "cancel" -> {cancel();result.success(null)}
                else -> result.notImplemented()
            }
        }
    }
    private fun onDevice()=Build.VERSION.SDK_INT>=31&&SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)
    private fun start(){
        if(pending==null||!foreground){cancel();return}
        val attempt=generation
        try {
            recognizer=if(deviceOnly&&Build.VERSION.SDK_INT>=31)SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)else SpeechRecognizer.createSpeechRecognizer(activity)
            recognizer!!.setRecognitionListener(object:RecognitionListener {
                override fun onReadyForSpeech(p:Bundle?){if(attempt!=generation||pending==null)return;channel.invokeMethod("status","ready")}
                override fun onBeginningOfSpeech(){if(attempt!=generation||pending==null)return;channel.invokeMethod("status","listening")}
                override fun onRmsChanged(value:Float){}
                override fun onBufferReceived(value:ByteArray?){} // Never retain audio.
                override fun onEndOfSpeech(){if(attempt!=generation||pending==null)return;channel.invokeMethod("status","processing")}
                override fun onError(code:Int){if(attempt!=generation||pending==null)return;finishError(when(code){
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS->"permission"
                    SpeechRecognizer.ERROR_NO_MATCH->"no_match"
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT->"no_speech"
                    SpeechRecognizer.ERROR_NETWORK,SpeechRecognizer.ERROR_NETWORK_TIMEOUT->"network"
                    SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE->"language"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY->"busy"
                    else->"recognition"
                })}
                override fun onResults(value:Bundle?){
                    if(attempt!=generation||pending==null)return
                    val choices=value?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.map { it.take(4000).trim() }?.filter { it.isNotEmpty() }?.take(3)?:emptyList()
                    if(choices.isEmpty()){finishError("no_match");return}
                    val reply=pending;pending=null;release();reply?.success(mapOf("text" to choices.first(),"alternatives" to choices,"onDeviceRequested" to deviceOnly))
                }
                override fun onPartialResults(value:Bundle?){if(attempt==generation&&pending!=null)channel.invokeMethod("partial",value?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.take(4000)?:"")}
                override fun onEvent(type:Int,value:Bundle?){}
            })
            handler.postDelayed(deadline,45000)
            recognizer!!.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE,language)
                .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS,true)
                .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS,3)
                .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE,deviceOnly))
        }catch(_:Exception){finishError("unavailable")}
    }
    fun permissionResult(request:Int,grants:IntArray):Boolean {
        if(request!=REQUEST)return false
        if(!awaitingPermission)return true
        awaitingPermission=false
        if(grants.firstOrNull()==PackageManager.PERMISSION_GRANTED&&foreground&&pending!=null)start()else finishError("permission")
        return true
    }
    private fun release(){handler.removeCallbacks(deadline);val old=recognizer;recognizer=null;try{old?.destroy()}catch(_:Exception){}}
    private fun finishError(code:String){val reply=pending;pending=null;awaitingPermission=false;release();reply?.error(code,null,null)}
    fun cancel(){generation++;val old=recognizer;recognizer=null;try{old?.cancel();old?.destroy()}catch(_:Exception){};finishError("cancelled")}
    fun foreground(value:Boolean){foreground=value;if(!value)cancel()}
    fun close(){cancel();channel.setMethodCallHandler(null)}
    companion object { private const val REQUEST=874 }
}
