package com.islamic.aldhakereen.adhan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AdhanReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Need to reschedule alarms. The app usually handles this by fetching next prayers.
            // For now, ignore playing Adhan immediately.
            return
        }

        val serviceIntent = Intent(context, AdhanForegroundService::class.java).apply {
            putExtra("id", intent.getIntExtra("id", 0))
            putExtra("prayerName", intent.getStringExtra("prayerName"))
            putExtra("fullScreen", intent.getBooleanExtra("fullScreen", false))
            putExtra("volume", intent.getDoubleExtra("volume", 1.0))
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
