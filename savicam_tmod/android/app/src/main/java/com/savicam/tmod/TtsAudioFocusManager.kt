package com.savicam.tmod

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.util.Log

/**
 * TtsAudioFocusManager
 *
 * Quản lý AudioFocus cho TTS khi app chạy Headless Mode.
 *
 * Vấn đề: Trên Xiaomi/MIUI và Oppo/ColorOS, khi screen off, hệ thống
 * restrict AudioFocus cho background apps. `flutter_tts` plugin KHÔNG tự
 * request AudioFocus — nếu không request trước, `TextToSpeech.speak()`
 * trả về ERROR silently (không crash, không exception, chỉ im lặng).
 *
 * Giải pháp: Từ Dart, gọi `requestAudioFocus()` qua MethodChannel trước
 * mỗi lần `flutter_tts.speak()`, sau đó gọi `abandonAudioFocus()` khi done.
 *
 * Usage flow (Dart):
 *   1. await MethodChannelBridge.requestAudioFocus()
 *   2. await flutter_tts.speak(message)
 *   3. await MethodChannelBridge.abandonAudioFocus()
 */
class TtsAudioFocusManager(private val context: Context) {

    companion object {
        private const val TAG = "TtsAudioFocusManager"
    }

    private val audioManager: AudioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private var focusRequest: AudioFocusRequest? = null
    private var hasFocus = false

    /**
     * Request AudioFocus TRƯỚC khi TTS phát.
     *
     * Dùng AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK:
     *   - Transient: chỉ cần focus ngắn hạn (phát 1 câu)
     *   - May duck: app khác (nhạc) sẽ giảm volume thay vì pause hoàn toàn
     *
     * @return true nếu request thành công, false nếu bị từ chối
     */
    fun requestFocus(): Boolean {
        if (hasFocus) {
            Log.d(TAG, "requestFocus: already held — skipping")
            return true
        }

        val result: Int

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // API 26+: dùng AudioFocusRequest builder
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attrs)
                .setAcceptsDelayedFocusGain(false)
                .setOnAudioFocusChangeListener { change ->
                    Log.d(TAG, "onAudioFocusChange: $change")
                    if (change == AudioManager.AUDIOFOCUS_LOSS ||
                        change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
                        hasFocus = false
                    }
                }
                .build()

            result = audioManager.requestAudioFocus(focusRequest!!)
        } else {
            // API < 26: deprecated API
            @Suppress("DEPRECATION")
            result = audioManager.requestAudioFocus(
                { change ->
                    Log.d(TAG, "onAudioFocusChange (legacy): $change")
                    if (change == AudioManager.AUDIOFOCUS_LOSS ||
                        change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
                        hasFocus = false
                    }
                },
                AudioManager.STREAM_NOTIFICATION,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
        }

        hasFocus = (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
        Log.i(TAG, "requestFocus: result=${if (hasFocus) "GRANTED" else "DENIED"}")
        return hasFocus
    }

    /**
     * Abandon AudioFocus SAU khi TTS xong.
     * Quan trọng: nếu không abandon, apps khác (nhạc, navigation) sẽ bị ducked vĩnh viễn.
     */
    fun abandonFocus() {
        if (!hasFocus) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let {
                audioManager.abandonAudioFocusRequest(it)
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }

        hasFocus = false
        focusRequest = null
        Log.i(TAG, "abandonFocus: released")
    }
}
