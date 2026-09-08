package com.example.pure_audio

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val EQUALIZER_CHANNEL = "com.example.pure_audio/equalizer"
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EQUALIZER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    val sessionId = call.argument<Int>("audioSessionId") ?: 0
                    try {
                        equalizer?.release()
                        bassBoost?.release()
                        equalizer = Equalizer(0, sessionId).apply { enabled = true }
                        bassBoost = BassBoost(0, sessionId).apply { enabled = true }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    equalizer?.enabled = enabled
                    bassBoost?.enabled = enabled
                    result.success(true)
                }
                "getPresets" -> {
                    val eq = equalizer
                    if (eq != null) {
                        val numPresets = eq.numberOfPresets.toInt()
                        val presets = (0 until numPresets).map { eq.getPresetName(it.toShort()) }
                        result.success(presets)
                    } else {
                        result.success(emptyList<String>())
                    }
                }
                "setPreset" -> {
                    val preset = call.argument<Int>("preset") ?: 0
                    try {
                        equalizer?.usePreset(preset.toShort())
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "setBassBoost" -> {
                    val strength = call.argument<Int>("strength") ?: 0
                    try {
                        bassBoost?.setStrength(strength.toShort())
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "setBandLevel" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val level = call.argument<Int>("level") ?: 0
                    try {
                        equalizer?.setBandLevel(band.toShort(), level.toShort())
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            equalizer?.release()
            bassBoost?.release()
        } catch (_: Exception) {}
        super.onDestroy()
    }
}

