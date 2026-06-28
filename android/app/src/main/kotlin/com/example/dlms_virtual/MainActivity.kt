package com.example.dlms_virtual

import android.media.audiofx.Equalizer
import android.media.audiofx.DynamicsProcessing
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import kotlin.math.hypot

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.dlms/audiofx"
    private val EVENT_CHANNEL = "com.example.dlms/rta_stream"
    private var equalizer: Equalizer? = null
    private var dspEngine: DynamicsProcessing? = null
    private var visualizer: Visualizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            equalizer = Equalizer(0, 0).apply { enabled = true }
            val dspConfig = DynamicsProcessing.Config.Builder(
                DynamicsProcessing.VARIANT_FAVOR_FREQUENCY_RESOLUTION,
                2, true, 5, true, 3, false, 0, true
            ).build()
            dspEngine = DynamicsProcessing(0, dspConfig).apply { enabled = true }
        } catch (e: Exception) { e.printStackTrace() }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    try {
                        if (visualizer == null) {
                            visualizer = Visualizer(0).apply {
                                captureSize = Visualizer.getCaptureSizeRange()[1]
                                enabled = true
                            }
                        }
                    } catch (e: Exception) { e.printStackTrace() }
                    startRtaStreaming()
                }
                override fun onCancel(arguments: Any?) { 
                    eventSink = null 
                    try {
                        visualizer?.enabled = false
                        visualizer?.release()
                        visualizer = null
                    } catch(e: Exception) {}
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setMatrix" -> {
                    val output = call.argument<Int>("output") ?: 0
                    val gain = call.argument<Double>("gain")?.toFloat() ?: 1f
                    try {
                        dspEngine?.setInputGainByChannelIndex(output, gain * 10f)
                        result.success(null)
                    } catch (e: Exception) { result.error("ERROR", e.message, null) }
                }
                "setGeq" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val gain = call.argument<Double>("gain")?.toFloat() ?: 0f
                    try {
                        equalizer?.setBandLevel(band.toShort(), (gain * 100).toInt().toShort())
                        result.success(null)
                    } catch (e: Exception) { result.error("ERROR", e.message, null) }
                }
                "setPeq" -> {
                    val ch = call.argument<Int>("channel") ?: 0
                    val band = call.argument<Int>("band") ?: 0
                    val freq = call.argument<Double>("freq")?.toFloat() ?: 1000f
                    val gain = call.argument<Double>("gain")?.toFloat() ?: 0f
                    try {
                        dspEngine?.let {
                            val eqBand = it.getPreEqBand(ch, band).apply { frequency = freq; this.gain = gain }
                            it.setPreEqBand(ch, band, eqBand)
                        }
                        result.success(null)
                    } catch (e: Exception) { result.error("ERROR", e.message, null) }
                }
                "setCrossover" -> {
                    val ch = call.argument<Int>("channel") ?: 0
                    val band = call.argument<Int>("band") ?: 0
                    val cutoff = call.argument<Double>("cutoff")?.toFloat() ?: 120f
                    try {
                        dspEngine?.let {
                            val mbc = it.getMbcBand(ch, band).apply { cutoffFrequency = cutoff }
                            it.setMbcBand(ch, band, mbc)
                        }
                        result.success(null)
                    } catch (e: Exception) { result.error("ERROR", e.message, null) }
                }
                "setLimiter" -> {
                    val ch = call.argument<Int>("channel") ?: 0
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val thresh = call.argument<Double>("thresh")?.toFloat() ?: 0f
                    try {
                        dspEngine?.let {
                            val lim = DynamicsProcessing.Limiter(enabled, enabled, ch).apply { threshold = thresh }
                            it.setLimiterConfigByChannelIndex(ch, lim)
                        }
                        result.success(null)
                    } catch (e: Exception) { result.error("ERROR", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startRtaStreaming() {
        handler.post(object : Runnable {
            override fun run() {
                if (eventSink == null) return
                val fft = ByteArray(256)
                try {
                    visualizer?.getFft(fft)
                } catch (e: Exception) { }
                
                val magnitudes = ArrayList<Double>()
                for (i in 0 until 16) {
                    val r = fft[i * 2].toDouble()
                    val j = fft[i * 2 + 1].toDouble()
                    val mag = hypot(r, j) / 128.0
                    magnitudes.add(if (mag > 1.0) 1.0 else mag)
                }
                eventSink?.success(magnitudes)
                handler.postDelayed(this, 120)
            }
        })
    }
}
