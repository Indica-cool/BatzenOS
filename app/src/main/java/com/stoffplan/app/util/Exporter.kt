package com.stoffplan.app.util

import com.stoffplan.app.data.Entry
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object Exporter {

    fun toJson(entries: List<Entry>): String {
        val arr = JSONArray()
        for (e in entries) {
            val o = JSONObject()
            o.put("id", e.id)
            o.put("timestamp", e.timestamp)
            o.put("timestampIso", isoDate(e.timestamp))
            o.put("substance", e.substance)
            o.put("doseAmount", e.doseAmount ?: JSONObject.NULL)
            o.put("doseUnit", e.doseUnit)
            o.put("route", e.route.name)
            o.put("onsetMinutes", e.onsetMinutes ?: JSONObject.NULL)
            o.put("peakMinutes", e.peakMinutes ?: JSONObject.NULL)
            o.put("comedownMinutes", e.comedownMinutes ?: JSONObject.NULL)
            o.put("effects", e.effects)
            o.put("moodBefore", e.moodBefore ?: JSONObject.NULL)
            o.put("moodAfter", e.moodAfter ?: JSONObject.NULL)
            o.put("location", e.location)
            o.put("company", e.company)
            o.put("notes", e.notes)
            arr.put(o)
        }
        val root = JSONObject().apply {
            put("app", "StoffPlan")
            put("exportedAt", isoDate(System.currentTimeMillis()))
            put("count", entries.size)
            put("entries", arr)
        }
        return root.toString(2)
    }

    fun toCsv(entries: List<Entry>): String {
        val sb = StringBuilder()
        sb.append("id,timestamp,substance,doseAmount,doseUnit,route,onsetMin,peakMin,comedownMin,effects,moodBefore,moodAfter,location,company,notes\n")
        for (e in entries) {
            sb.append(e.id).append(',')
            sb.append(csv(isoDate(e.timestamp))).append(',')
            sb.append(csv(e.substance)).append(',')
            sb.append(e.doseAmount?.toString() ?: "").append(',')
            sb.append(csv(e.doseUnit)).append(',')
            sb.append(e.route.name).append(',')
            sb.append(e.onsetMinutes?.toString() ?: "").append(',')
            sb.append(e.peakMinutes?.toString() ?: "").append(',')
            sb.append(e.comedownMinutes?.toString() ?: "").append(',')
            sb.append(csv(e.effects)).append(',')
            sb.append(e.moodBefore?.toString() ?: "").append(',')
            sb.append(e.moodAfter?.toString() ?: "").append(',')
            sb.append(csv(e.location)).append(',')
            sb.append(csv(e.company)).append(',')
            sb.append(csv(e.notes))
            sb.append('\n')
        }
        return sb.toString()
    }

    private fun csv(s: String): String {
        val needsQuote = s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')
        val escaped = s.replace("\"", "\"\"")
        return if (needsQuote) "\"$escaped\"" else escaped
    }

    private fun isoDate(ts: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date(ts))
}
