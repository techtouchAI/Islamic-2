package com.islamic.aldhakereen.adhan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.app.ForegroundServiceStartNotAllowedException
import androidx.core.app.NotificationCompat
import com.islamic.aldhakereen.R
import android.os.Handler
import android.os.Looper

/**
 * خدمة الأذان في المقدمة - تم تحديثها لفك الارتباط بين الإشعارات المرئية والصوت مع إدارة سليمة لدورة الحياة
 */
class AdhanForegroundService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private val channelId = "adhan_channel"
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prayerName = intent?.getStringExtra("prayerName") ?: "الصلاة"
        val fullScreen = intent?.getBooleanExtra("fullScreen", false) ?: false
        val volume = intent?.getDoubleExtra("volume", 1.0) ?: 1.0
        val id = intent?.getIntExtra("id", 0) ?: 0

        val notification = createNotification(prayerName, fullScreen)
        try {
            startForeground(id + 1000, notification)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        playAdhan(volume.toFloat())

        // تأمين إيقاف الخدمة بعد مدة زمنية معقولة (مثلاً 5 دقائق) في حال فشل أي شيء آخر
        handler.postDelayed({
            stopServiceGracefully()
        }, 5 * 60 * 1000L)

        return START_NOT_STICKY
    }

    private fun playAdhan(volume: Float) {
        if (volume <= 0.0f) return

        try {
            val afd = resources.openRawResourceFd(R.raw.azan5) ?: return
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                prepare()
                setVolume(volume, volume)
                start()

                setOnCompletionListener {
                    it.release()
                    mediaPlayer = null
                    // ننتظر قليلاً قبل إيقاف الخدمة لضمان بقاء الإشعار فترة كافية
                    handler.postDelayed({ stopServiceGracefully() }, 30000)
                }

                setOnErrorListener { mp, _, _ ->
                    mp.release()
                    mediaPlayer = null
                    stopServiceGracefully()
                    false
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            stopServiceGracefully()
        }
    }

    private fun stopServiceGracefully() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // نخرج من وضع المقدمة مع الحفاظ على الإشعار كإشعار عادي يمكن مسحه
            stopForeground(STOP_FOREGROUND_DETACH)
        } else {
            stopForeground(false)
        }
        stopSelf()
    }

    private fun createNotification(prayerName: String, fullScreen: Boolean): Notification {
        val builder = NotificationCompat.Builder(this, channelId)
            .setContentTitle("حان موعد $prayerName")
            .setContentText("الصلاة خير من النوم")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(true)

        if (fullScreen) {
            val fullScreenIntent = Intent(this, com.islamic.aldhakereen.MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val fullScreenPendingIntent = PendingIntent.getActivity(
                this, 0, fullScreenIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.setFullScreenIntent(fullScreenPendingIntent, true)
        } else {
            val contentIntent = Intent(this, com.islamic.aldhakereen.MainActivity::class.java)
            val pendingContentIntent = PendingIntent.getActivity(
                this, 0, contentIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.setContentIntent(pendingContentIntent)
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "تنبيهات الأذان"
            val channel = NotificationChannel(channelId, name, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "عرض إشعارات مواقيت الصلاة والأذان"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 1000, 500, 1000)
                setSound(null, null)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        mediaPlayer?.release()
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
