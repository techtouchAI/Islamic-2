package com.islamic.aldhakereen.hijri

import android.content.Context
import java.util.Calendar

class HijriNativeManager(private val context: Context) {

    fun getHijriDate(manualOffset: Int): Map<String, Any> {
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_MONTH, manualOffset)

        // Approximate Umm al-Qura calculation based on standard Java Calendar
        // (A fully compliant Umm al-Qura calendar usually requires external libraries,
        // but we'll implement a robust approximation to avoid dependencies as instructed).
        var d = calendar.get(Calendar.DAY_OF_MONTH)
        var m = calendar.get(Calendar.MONTH) + 1
        var y = calendar.get(Calendar.YEAR)

        var m1 = (m - 14) / 12
        var y1 = y + 4800 + m1
        var jd = d + (1461 * y1) / 4 + (367 * (m - 2 - 12 * m1)) / 12 - (3 * ((y1 + 100) / 100)) / 4 + 15 - 32075

        var l = jd - 1948440 + 10632
        var n = (l - 1) / 10631
        l = l - 10631 * n + 354
        var j = ((10985 - l) / 5316) * ((50 * l) / 17719) + (l / 5670) * ((43 * l) / 15238)
        l = l - ((30 - j) / 15) * ((17719 * j) / 50) - (j / 16) * ((15238 * j) / 43) + 29

        var hMonth = (24 * l) / 709
        var hDay = l - (709 * hMonth) / 24
        var hYear = 30 * n + j - 30

        val monthNames = arrayOf(
            "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
            "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
        )

        val monthName = monthNames[(hMonth - 1) % 12]

        return mapOf(
            "day" to hDay,
            "month" to hMonth,
            "monthName" to monthName,
            "year" to hYear
        )
    }
}

object HijriEventsDatabase {
    val majorEvents = listOf(
        mapOf("title" to "بداية شهر رمضان", "month" to 9, "day" to 1),
        mapOf("title" to "ليلة القدر", "month" to 9, "day" to 22),
        mapOf("title" to "عيد الفطر المبارك", "month" to 10, "day" to 1),
        mapOf("title" to "عيد الأضحى المبارك", "month" to 12, "day" to 10),
        mapOf("title" to "عاشوراء", "month" to 1, "day" to 10)
    )
}
