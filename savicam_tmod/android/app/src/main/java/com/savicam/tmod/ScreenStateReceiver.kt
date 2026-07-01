package com.savicam.tmod

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * ScreenStateReceiver — lắng nghe ACTION_SCREEN_OFF / ACTION_SCREEN_ON.
 *
 * QUAN TRỌNG: ACTION_SCREEN_OFF/ON KHÔNG thể khai báo trong AndroidManifest.xml.
 * Bắt buộc phải register ĐỘNG trong code (HeadlessService.onCreate hoặc tương tự).
 * Nếu khai báo trong manifest → receiver sẽ KHÔNG BAO GIỜ fire.
 *
 * Khi nhận event, push xuống Flutter qua EventChannel thông qua NativeChannelRouter.
 */
class ScreenStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ScreenStateReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_OFF -> {
                Log.i(TAG, "Screen OFF detected")
                NativeChannelRouter.fireScreenStateEvent(isScreenOn = false)
            }
            Intent.ACTION_SCREEN_ON -> {
                Log.i(TAG, "Screen ON detected")
                NativeChannelRouter.fireScreenStateEvent(isScreenOn = true)
            }
            else -> {
                Log.d(TAG, "Unknown action: ${intent.action}")
            }
        }
    }
}
