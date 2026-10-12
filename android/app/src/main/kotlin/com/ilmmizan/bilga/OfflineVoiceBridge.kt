package com.ilmmizan.bilga

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.*
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

/** Only the on-device recognizer and installed, non-network TTS voices are used.
 * Synthesizing to private cache lets MediaPlayer retain the exact audio position.
 * No model downloader or network client receives text or microphone samples. */
class OfflineVoiceBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "bilga/voice")
    private val handler = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = null
    private var ready = false
    private var recognizer: SpeechRecognizer? = null
    private var listenResult: MethodChannel.Result? = null
    private var listenLanguage = "en-US"
    private var installedSttLanguages = emptyList<String>()
    private var playbackResult: MethodChannel.Result? = null
    private var player: MediaPlayer? = null
    private var audioFile: File? = null
    private var paused = false
    private var foreground = true
    private var generation = 0L
    private var ttsGeneration = 0L
    private val timeout = Runnable { finishListen(null, "timeout") }

    init {
        initializeTts()
        channel.setMethodCallHandler { call, result ->
            try {
                if (!foreground && call.method in setOf("listen", "speak", "playFile", "resume")) {
                    result.error("cancelled", "Assistant is not in the foreground", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "capabilities" -> capabilities(call.argument<String>("language") ?: "en-US", result)
                    "ttsSettings" -> {
                        activity.startActivity(Intent("com.android.settings.TTS_SETTINGS"))
                        result.success(null)
                    }
                    "refreshTts" -> {
                        stopPlayback()
                        tts?.shutdown()
                        initializeTts()
                        result.success(null)
                    }
                    "listen" -> {
                        if (listenResult != null) result.error("busy", "Already listening", null)
                        else {
                            listenResult = result
                            listenLanguage = call.argument<String>("language") ?: "en-US"
                            if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED)
                                activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 711)
                            else startListen()
                        }
                    }
                    "cancel" -> { finishListen(null, "cancelled"); result.success(null) }
                    "stop" -> { stopPlayback(); result.success(null) }
                    "pause" -> { paused = true; player?.takeIf { it.isPlaying }?.pause(); result.success(null) }
                    "resume" -> { paused = false; player?.start(); result.success(null) }
                    "speak" -> {
                        stopPlayback()
                        paused = call.argument<Boolean>("paused") == true
                        val language = call.argument<String>("language") ?: "en-US"
                        val voice = offlineVoice(language)
                        if (!ready || voice == null) result.error("offline_tts_unavailable", language, null)
                        else {
                            playbackResult = result
                            val epoch = generation
                            val file = File(activity.cacheDir, "bilga-voice-$epoch.wav")
                            audioFile = file
                            if (tts?.setVoice(voice) != TextToSpeech.SUCCESS) { failPlayback(); return@setMethodCallHandler }
                            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                                override fun onStart(id: String?) {}
                                override fun onDone(id: String?) { handler.post { if (epoch == generation && id == epoch.toString()) play(file, epoch) } }
                                @Suppress("OVERRIDE_DEPRECATION")
                                override fun onError(id: String?) { handler.post { if (epoch == generation && id == epoch.toString()) failPlayback() } }
                            })
                            val text = call.argument<String>("text") ?: ""
                            if (text.isEmpty() || text.length > TextToSpeech.getMaxSpeechInputLength() ||
                                tts?.synthesizeToFile(text, Bundle(), file, epoch.toString()) != TextToSpeech.SUCCESS) failPlayback()
                        }
                    }
                    "playFile" -> {
                        stopPlayback()
                        paused = call.argument<Boolean>("paused") == true
                        val file = File(call.argument<String>("path") ?: "")
                        // Accept only app-owned private cache audio, never arbitrary URIs.
                        if (!file.canonicalPath.startsWith(activity.cacheDir.canonicalPath + File.separator))
                            result.error("invalid_path", "Private cache required", null)
                        else { playbackResult = result; audioFile = file; play(file, generation) }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("voice_unavailable", "Offline voice unavailable", null) }
        }
    }

    private fun initializeTts() {
        ready = false
        val epoch = ++ttsGeneration
        tts = TextToSpeech(activity) { status ->
            if (epoch == ttsGeneration) ready = status == TextToSpeech.SUCCESS
        }
    }

    private fun offlineVoice(language: String) = if (!ready) null else tts?.voices
        ?.filter { !it.isNetworkConnectionRequired &&
            !it.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) &&
            it.locale.language == Locale.forLanguageTag(language).language }
        ?.sortedByDescending { it.locale.toLanguageTag().equals(language, true) }?.firstOrNull()

    private fun request(language: String) = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        if (Build.VERSION.SDK_INT >= 34) {
            putExtra(RecognizerIntent.EXTRA_ENABLE_LANGUAGE_DETECTION, true)
            putExtra(RecognizerIntent.EXTRA_ENABLE_LANGUAGE_SWITCH, RecognizerIntent.LANGUAGE_SWITCH_BALANCED)
        }
    }

    private fun capabilities(language: String, result: MethodChannel.Result, attempt: Int = 0) {
        if (!ready && attempt < 20) { handler.postDelayed({ capabilities(language, result, attempt + 1) }, 100); return }
        val base = mutableMapOf<String, Any>(
            "tts" to (offlineVoice(language) != null),
            "ttsLanguages" to (tts?.voices?.filter { !it.isNetworkConnectionRequired &&
                !it.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) }
                ?.map { it.locale.toLanguageTag() }?.distinct() ?: emptyList<String>()),
            "stt" to "unavailable", "sttLanguages" to emptyList<String>(),
            "sdk" to Build.VERSION.SDK_INT, "abis" to Build.SUPPORTED_ABIS.toList())
        if (Build.VERSION.SDK_INT < 31 || !SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)) {
            result.success(base); return
        }
        if (Build.VERSION.SDK_INT < 33) { base["stt"] = "unknown"; result.success(base); return }
        val probe = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
        var finished = false
        val finish = Runnable { if (!finished) { finished = true; probe.destroy(); result.success(base) } }
        handler.postDelayed(finish, 5000)
        probe.checkRecognitionSupport(request(language), activity.mainExecutor, object : RecognitionSupportCallback {
            override fun onSupportResult(support: RecognitionSupport) {
                if (finished) return
                installedSttLanguages = support.installedOnDeviceLanguages
                base["sttLanguages"] = installedSttLanguages
                base["stt"] = if (support.installedOnDeviceLanguages.any {
                    Locale.forLanguageTag(it).language == Locale.forLanguageTag(language).language }) "available" else "unavailable"
                finish.run()
            }
            override fun onError(error: Int) { base["stt"] = "unknown"; finish.run() }
        })
    }

    fun permissionResult(granted: Boolean) {
        if (listenResult == null) return
        if (granted) startListen() else finishListen(null, "permission")
    }
    private fun startListen() {
        try {
            if (Build.VERSION.SDK_INT < 31 || !SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)) {
                finishListen(null, "offline_unavailable"); return
            }
            recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
            recognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) { finishListen(null, "speech_$error") }
                override fun onResults(results: Bundle?) { finishListen(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull(), null) }
                override fun onPartialResults(results: Bundle?) {}
                override fun onEvent(type: Int, params: Bundle?) {}
            })
            handler.postDelayed(timeout, 30000)
            val actualLanguage = installedSttLanguages.firstOrNull { it.equals(listenLanguage, true) }
                ?: installedSttLanguages.firstOrNull { Locale.forLanguageTag(it).language == Locale.forLanguageTag(listenLanguage).language }
                ?: listenLanguage
            recognizer?.startListening(request(actualLanguage))
        } catch (_: Exception) { finishListen(null, "offline_unavailable") }
    }
    private fun finishListen(text: String?, error: String?) {
        val result = listenResult; listenResult = null
        handler.removeCallbacks(timeout)
        val old = recognizer; recognizer = null
        old?.cancel(); old?.destroy()
        if (error == null) result?.success(text) else result?.error(error, "Offline speech session ended", null)
    }
    private fun play(file: File, epoch: Long) {
        try {
            player = MediaPlayer().apply {
                setDataSource(file.absolutePath)
                setOnCompletionListener { if (epoch == generation) completePlayback(true) }
                setOnErrorListener { _, _, _ -> if (epoch == generation) failPlayback(); true }
                prepare()
                if (!paused && foreground) start()
            }
        } catch (_: Exception) { failPlayback() }
    }
    private fun completePlayback(completed: Boolean) {
        val result = playbackResult; playbackResult = null
        player?.release(); player = null
        audioFile?.delete(); audioFile = null
        result?.success(completed)
    }
    private fun failPlayback() {
        val result = playbackResult; playbackResult = null
        completePlayback(false)
        result?.error("offline_tts_unavailable", "Offline synthesis failed", null)
    }
    private fun stopPlayback() {
        generation++
        tts?.stop()
        completePlayback(false)
    }
    fun foreground() { foreground = true }
    fun background() { foreground = false; finishListen(null, "cancelled"); paused = true; player?.takeIf { it.isPlaying }?.pause() }
    fun close() { ttsGeneration++; ready = false; background(); stopPlayback(); tts?.shutdown(); tts = null; channel.setMethodCallHandler(null) }
}
