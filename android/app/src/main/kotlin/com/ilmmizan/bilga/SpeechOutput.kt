package com.ilmmizan.bilga

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Prefers an installed offline voice and falls back to the bundled synthesizer. */
internal class SpeechOutput(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "bilga/speech_output")
    private val handler = Handler(Looper.getMainLooper())
    private val embedded = EmbeddedSpeech(activity.applicationContext, handler)
    private val hasNavoiySample = activity.packageName == "com.ilmmizan.bilga.review"
    private var ready: Boolean? = null
    private var pending: MethodChannel.Result? = null
    private var generation = 0
    private var foreground = true
    private var engine: TextToSpeech? = null
    private var initialize: (() -> Unit)? = null
    private val expiry = Runnable { stop("unavailable") }
    private val initializationExpiry = Runnable {
        val action = initialize
        initialize = null
        action?.invoke()
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "stop" -> { stop("cancelled"); result.success(null) }
                "hasNavoiySample" -> result.success(hasNavoiySample)
                "playNavoiySample" -> {
                    if (!foreground || !hasNavoiySample) {
                        result.error("unavailable", null, null)
                        return@setMethodCallHandler
                    }
                    stop("cancelled")
                    pending = result
                    val attempt = generation
                    handler.postDelayed(expiry, 15000)
                    embedded.playNavoiySample { error -> finish(attempt, error) }
                }
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
                        handler.postDelayed(initializationExpiry, 1500)
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
        handler.removeCallbacks(initializationExpiry)
        if (!foreground || generation != attempt || pending == null) return
        val tts = engine
        if (ready != true || tts == null) {
            speakEmbedded(text, locale, rate, attempt)
            return
        }
        try {
            val voice = tts.voices.orEmpty()
                .filter { (it.locale.language == locale.language ||
                    (locale.language == "uz" && it.locale.language == "uzb")) &&
                    !it.isNetworkConnectionRequired &&
                    TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED !in it.features.orEmpty() }
                .maxWithOrNull(compareBy<Voice> { it.quality }
                    .thenBy { it.locale.country == locale.country })
            if (voice == null || tts.setVoice(voice) != TextToSpeech.SUCCESS) {
                speakEmbedded(text, locale, rate, attempt)
                return
            }
            tts.setSpeechRate(rate)
            val token = attempt.toString()
            tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                private var started = false

                override fun onStart(id: String?) {
                    if (id == token) handler.post { started = true }
                }
                override fun onDone(id: String?) { if (id == token) handler.post { finish(attempt, null) } }
                @Deprecated("Required by Android")
                override fun onError(id: String?) {
                    if (id == token) handler.post {
                        if (attempt == generation && pending != null) {
                            if (started) finish(attempt, "unavailable")
                            else speakEmbedded(text, locale, rate, attempt)
                        }
                    }
                }
            })
            if (tts.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), token) != TextToSpeech.SUCCESS) {
                speakEmbedded(text, locale, rate, attempt)
            } else {
                handler.postDelayed(expiry, 120000)
            }
        } catch (_: Exception) { speakEmbedded(text, locale, rate, attempt) }
    }

    private fun speakEmbedded(text: String, locale: Locale, rate: Float, attempt: Int) {
        handler.removeCallbacks(expiry)
        if (!embedded.available) {
            finish(attempt, "language")
            return
        }
        val language = if (locale.language == "en") "en-us" else locale.language
        handler.postDelayed(expiry, 120000)
        embedded.speak(text, language, rate) { error -> finish(attempt, error) }
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
        handler.removeCallbacks(initializationExpiry)
        finish(generation, reason)
        generation++
        engine?.stop()
        embedded.stop()
    }

    fun foreground(value: Boolean) {
        foreground = value
        if (!value) stop("cancelled")
    }

    fun close() {
        stop("cancelled")
        engine?.shutdown()
        engine = null
        embedded.close()
        channel.setMethodCallHandler(null)
    }
}
