package com.ilmmizan.bilga

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Reads a bounded excerpt using only an installed voice in the requested language. */
internal class SpeechOutput(activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "bilga/speech_output")
    private val handler = Handler(Looper.getMainLooper())
    private var ready: Boolean? = null
    private var pending: MethodChannel.Result? = null
    private var generation = 0
    private var foreground = true
    private var engine: TextToSpeech? = null
    private var initialize: (() -> Unit)? = null
    private val expiry = Runnable { stop("unavailable") }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "stop" -> { stop("cancelled"); result.success(null) }
                "speak" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val locale = Locale.forLanguageTag(call.argument<String>("language").orEmpty())
                    val rate = call.argument<Number>("rate")?.toFloat() ?: 1f
                    if (!foreground || text.isBlank() || text.length > minOf(2500, TextToSpeech.getMaxSpeechInputLength()) ||
                        locale.language !in setOf("uz", "en", "ru") || rate !in 0.65f..1.5f) {
                        result.error("unavailable", null, null)
                        return@setMethodCallHandler
                    }
                    stop("cancelled")
                    pending = result
                    val attempt = generation
                    val begin = { speak(text, locale, rate, attempt) }
                    if (ready != null) begin() else {
                        initialize = begin
                        handler.postDelayed(expiry, 5000)
                        if (engine == null) {
                            engine = TextToSpeech(activity.applicationContext) { state ->
                                handler.post {
                                    if (engine != null) {
                                        ready = state == TextToSpeech.SUCCESS
                                        val action = initialize
                                        initialize = null
                                        action?.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun speak(text: String, locale: Locale, rate: Float, attempt: Int) {
        handler.removeCallbacks(expiry)
        if (!foreground || generation != attempt || pending == null) return
        val tts = engine
        if (ready != true || tts == null) { finish(attempt, "unavailable"); return }
        try {
            val voice = tts.voices.orEmpty()
                .filter { it.locale.language == locale.language &&
                    !it.isNetworkConnectionRequired &&
                    TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED !in it.features.orEmpty() }
                .sortedWith(compareByDescending<android.speech.tts.Voice> { it.locale.country == locale.country }
                    .thenByDescending { it.quality }).firstOrNull()
            if (voice == null || tts.setVoice(voice) != TextToSpeech.SUCCESS) {
                finish(attempt, "language")
                return
            }
            tts.setSpeechRate(rate)
            val token = attempt.toString()
            tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String?) {}
                override fun onDone(id: String?) { if (id == token) handler.post { finish(attempt, null) } }
                @Deprecated("Required by Android")
                override fun onError(id: String?) { if (id == token) handler.post { finish(attempt, "unavailable") } }
            })
            if (tts.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), token) != TextToSpeech.SUCCESS) {
                finish(attempt, "unavailable")
            } else {
                handler.postDelayed(expiry, 120000)
            }
        } catch (_: Exception) { finish(attempt, "unavailable") }
    }

    private fun finish(attempt: Int, error: String?) {
        if (attempt != generation) return
        handler.removeCallbacks(expiry)
        val result = pending
        pending = null
        if (error == null) result?.success(null) else result?.error(error, null, null)
    }

    private fun stop(reason: String) {
        initialize = null
        finish(generation, reason)
        generation++
        engine?.stop()
    }

    fun foreground(value: Boolean) {
        foreground = value
        if (!value) stop("cancelled")
    }

    fun close() {
        stop("cancelled")
        engine?.shutdown()
        engine = null
        channel.setMethodCallHandler(null)
    }
}
