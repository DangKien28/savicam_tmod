package com.savicam.relap

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "savicam_sos_channel"
            val channelName = "SOS Alerts"
            val channel = NotificationChannel(
                channelId, 
                channelName, 
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical alerts from paired T-Mod device"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
