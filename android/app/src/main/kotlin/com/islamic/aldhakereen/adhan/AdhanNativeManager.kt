package com.islamic.aldhakereen.adhan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log

/**
 * مدير التنبيهات الأصلي - يدعم متطلبات Android 12+ (Exact Alarms)
 */
class AdhanNativeManager(private val context: Context) {

    private val TAG = "AdhanNativeManager"

    fun scheduleAdhan(id: Int, timeInMillis: Long, prayerName: String, fullScreen: Boolean = false, volume: Double = 1.0, preAlertMinutes: Int = 0) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AdhanReceiver::class.java).apply {
            putExtra("id", id)
            putExtra("prayerName", prayerName)
            putExtra("fullScreen", fullScreen)
            putExtra("volume", volume)
        }

        // حساب وقت التنبيه الفعلي مع خصم دقائق التنبيه المسبق
        val triggerTime = timeInMillis - (preAlertMinutes * 60 * 1000L)

        // التحقق من صلاحية المنبهات الدقيقة لنظام أندرويد 12 فما فوق
        val canScheduleExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (canScheduleExact) {
                // استخدام AlarmClockInfo لضمان الدقة وتجاوز وضع Doze
                val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerTime, pendingIntent)
                alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                Log.d(TAG, "Scheduled exact alarm for $prayerName at $triggerTime")
            } else {
                // مسار بديل (Fallback) في حال عدم وجود صلاحية المنبه الدقيق
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
                }
                Log.w(TAG, "Scheduled fallback alarm for $prayerName - missing exact alarm permission")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling alarm for $prayerName", e)
            // الملاذ الأخير
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        }
    }

    fun cancelAdhan(id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AdhanReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "Canceled alarm with ID $id")
    }

    /**
     * التحقق من حالة الصلاحية لتقديم تغذية راجعة للمستخدم
     */
    fun checkExactAlarmPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }
}
