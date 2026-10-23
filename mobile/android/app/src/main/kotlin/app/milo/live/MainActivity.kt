package app.milo.live

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app.jhoomo.live/notification_tone"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playJhoomoChime" -> {
                    playSignatureJhoomoChime()
                    result.success(true)
                }
                "playSuccessChime" -> {
                    playSuccessHarmonicChime()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Synthesizes the signature JHOOMO melodious notification sound:
     * A smooth, crystalline dual-tone chime (F#5: 740 Hz -> A#5: 932 Hz -> C#6: 1108 Hz)
     * with an exponential bell fade envelope.
     */
    private fun playSignatureJhoomoChime() {
        thread(start = true, priority = Thread.MAX_PRIORITY) {
            try {
                val sampleRate = 44100
                val durationMs = 450
                val numSamples = (sampleRate * (durationMs / 1000.0)).toInt()
                val buffer = ShortArray(numSamples)

                val chord = doubleArrayOf(740.0, 932.0, 1108.0) // JHOOMO Major Triad Chime

                for (i in 0 until numSamples) {
                    val t = i.toDouble() / sampleRate
                    // Smooth bell envelope (fast attack 15ms, exponential decay)
                    val attack = if (t < 0.015) t / 0.015 else 1.0
                    val decay = Math.exp(-t * 6.5)
                    val envelope = attack * decay

                    var sample = 0.0
                    for (freq in chord) {
                        sample += sin(2.0 * Math.PI * freq * t)
                    }
                    sample = (sample / chord.size) * envelope * Short.MAX_VALUE * 0.85
                    buffer[i] = sample.toInt().toShort()
                }

                val audioTrack = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(buffer.size * 2)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()

                audioTrack.write(buffer, 0, buffer.size)
                audioTrack.play()
                Thread.sleep(durationMs.toLong() + 50)
                audioTrack.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    /**
     * High celebration chime when pass is unlocked or payment confirmed.
     */
    private fun playSuccessHarmonicChime() {
        thread(start = true, priority = Thread.MAX_PRIORITY) {
            try {
                val sampleRate = 44100
                val durationMs = 520
                val numSamples = (sampleRate * (durationMs / 1000.0)).toInt()
                val buffer = ShortArray(numSamples)

                val notes = doubleArrayOf(880.0, 1318.5, 1760.0) // A5 -> E6 -> A6 shimmering bell

                for (i in 0 until numSamples) {
                    val t = i.toDouble() / sampleRate
                    val attack = if (t < 0.01) t / 0.01 else 1.0
                    val decay = Math.exp(-t * 5.5)
                    val envelope = attack * decay

                    var sample = 0.0
                    for (freq in notes) {
                        sample += sin(2.0 * Math.PI * freq * t)
                    }
                    sample = (sample / notes.size) * envelope * Short.MAX_VALUE * 0.85
                    buffer[i] = sample.toInt().toShort()
                }

                val audioTrack = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(buffer.size * 2)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()

                audioTrack.write(buffer, 0, buffer.size)
                audioTrack.play()
                Thread.sleep(durationMs.toLong() + 50)
                audioTrack.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
