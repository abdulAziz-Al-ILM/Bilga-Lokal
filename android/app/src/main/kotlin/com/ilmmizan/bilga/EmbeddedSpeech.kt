package com.ilmmizan.bilga

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.roundToInt

/** Runs the separately packaged eSpeak NG program with stdin and WAV stdout. */
internal class EmbeddedSpeech(private val context: Context, private val main: Handler) {
    private val worker = Executors.newSingleThreadExecutor()
    private val generation = AtomicInteger()
    private val binary = File(context.applicationInfo.nativeLibraryDir, "libbilga_espeak_exec.so")
    @Volatile private var process: Process? = null
    private var track: AudioTrack? = null
    private var completion: Runnable? = null

    val available get() = binary.canExecute()

    fun speak(text: String, language: String, rate: Float, done: (String?) -> Unit) {
        stop()
        val attempt = generation.get()
        worker.execute {
            val wav = try { render(text, language, rate, attempt) } catch (_: Exception) { null }
            main.post {
                if (attempt != generation.get()) return@post
                if (wav == null) done("unavailable") else play(wav, attempt, done)
            }
        }
    }

    private fun dataPath(): File {
        val parent = File(context.cacheDir, "bilga-espeak-1.52.0")
        val root = File(parent, "espeak-ng-data")
        val marker = File(parent, "ready")
        if (!marker.exists()) {
            fun copy(path: String, target: File) {
                val children = context.assets.list(path).orEmpty()
                if (children.isNotEmpty()) {
                    target.mkdirs()
                    for (child in children) copy("$path/$child", File(target, child))
                } else {
                    context.assets.open(path).use { input -> target.outputStream().use { input.copyTo(it) } }
                }
            }
            copy("embedded-speech/espeak-ng-data", root)
            marker.createNewFile()
        }
        return parent
    }

    private fun render(text: String, language: String, rate: Float, attempt: Int): ByteArray? {
        val data = dataPath()
        if (attempt != generation.get()) return null
        val child = ProcessBuilder(binary.path, "--path=${data.path}", "-b", "1", "-v", language,
            "-s", (165 * rate).roundToInt().toString(), "--stdout", "--stdin")
            .redirectError(ProcessBuilder.Redirect.to(File("/dev/null"))).start()
        process = child
        try {
            if (attempt != generation.get()) return null
            child.outputStream.use { it.write(text.toByteArray(Charsets.UTF_8)) }
            val wav = ByteArrayOutputStream()
            child.inputStream.use { input ->
                val buffer = ByteArray(8192)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    if (attempt != generation.get() || wav.size() + read > 8_000_000) return null
                    wav.write(buffer, 0, read)
                }
            }
            return if (child.waitFor() == 0) wav.toByteArray() else null
        } finally {
            process = null
            child.destroy()
        }
    }

    private fun play(wav: ByteArray, attempt: Int, done: (String?) -> Unit) {
        try {
            require(wav.size > 44 && wav.copyOfRange(0, 4).contentEquals("RIFF".toByteArray()) &&
                wav.copyOfRange(8, 16).contentEquals("WAVEfmt ".toByteArray()) &&
                wav.copyOfRange(36, 40).contentEquals("data".toByteArray()))
            val header = ByteBuffer.wrap(wav).order(ByteOrder.LITTLE_ENDIAN)
            val sampleRate = header.getInt(24)
            require(header.getShort(20).toInt() == 1 && header.getShort(22).toInt() == 1 &&
                header.getShort(34).toInt() == 16 && sampleRate in 8000..48000)
            val count = (wav.size - 44) and -2
            val audio = AudioTrack.Builder()
                .setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setAudioFormat(AudioFormat.Builder().setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                .setBufferSizeInBytes(count).setTransferMode(AudioTrack.MODE_STATIC).build()
            track = audio
            require(audio.write(wav, 44, count) == count)
            val frames = count / 2
            val finished = Runnable {
                if (attempt == generation.get()) {
                    stop()
                    done(null)
                }
            }
            completion = finished
            audio.setPlaybackPositionUpdateListener(object : AudioTrack.OnPlaybackPositionUpdateListener {
                override fun onMarkerReached(current: AudioTrack?) = finished.run()
                override fun onPeriodicNotification(current: AudioTrack?) = Unit
            }, main)
            audio.notificationMarkerPosition = frames
            audio.play()
            main.postDelayed(finished, frames * 1000L / sampleRate + 450)
        } catch (_: Exception) {
            stop()
            done("unavailable")
        }
    }

    fun stop() {
        generation.incrementAndGet()
        process?.destroy()
        completion?.let(main::removeCallbacks)
        completion = null
        track?.release()
        track = null
    }

    fun close() {
        stop()
        worker.shutdownNow()
    }
}
