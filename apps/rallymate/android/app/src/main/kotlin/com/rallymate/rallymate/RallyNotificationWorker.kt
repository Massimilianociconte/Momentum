package com.rallymate.rallymate

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

class RallyNotificationWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    override fun doWork(): Result {
        val payload = mapOf(
            "id" to inputData.getString("id"),
            "title" to inputData.getString("title"),
            "body" to inputData.getString("body"),
            "category" to inputData.getString("category"),
            "payload" to inputData.getString("payload"),
        )
        RallyNotifications.post(applicationContext, payload)
        return Result.success()
    }
}
