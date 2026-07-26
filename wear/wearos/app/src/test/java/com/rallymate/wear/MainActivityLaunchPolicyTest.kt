package com.rallymate.wear

import android.content.Intent
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class MainActivityLaunchPolicyTest {

    @Test
    fun `external entries reuse one task and never request multiple documents`() {
        val flags = MainActivityLaunchPolicy.EXTERNAL_ENTRY_FLAGS

        assertTrue(flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        assertTrue(flags and Intent.FLAG_ACTIVITY_CLEAR_TOP != 0)
        assertTrue(flags and Intent.FLAG_ACTIVITY_SINGLE_TOP != 0)
        assertEquals(0, flags and Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
        assertEquals(0, flags and Intent.FLAG_ACTIVITY_NEW_DOCUMENT)
    }

    @Test
    fun `manifest guarantees one launcher task for duplicate start deliveries`() {
        val manifest = sequenceOf(
            File("src/main/AndroidManifest.xml"),
            File("app/src/main/AndroidManifest.xml"),
        ).firstOrNull(File::isFile)
        assertNotNull("AndroidManifest.xml not found from ${File(".").absolutePath}", manifest)

        val factory = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
            setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
        }
        val document = factory.newDocumentBuilder().parse(manifest!!)
        val activities = document.getElementsByTagName("activity")
        val mainActivity = (0 until activities.length)
            .map { activities.item(it) as Element }
            .firstOrNull {
                it.getAttributeNS(ANDROID_NAMESPACE, "name") == ".MainActivity"
            }
        assertNotNull("MainActivity declaration missing", mainActivity)

        assertEquals(
            "singleTask",
            mainActivity!!.getAttributeNS(ANDROID_NAMESPACE, "launchMode"),
        )
        assertEquals(
            "never",
            mainActivity.getAttributeNS(ANDROID_NAMESPACE, "documentLaunchMode"),
        )
        assertFalse(
            "MainActivity must retain the app's default affinity so NEW_TASK can reuse it",
            mainActivity.hasAttributeNS(ANDROID_NAMESPACE, "taskAffinity"),
        )
    }

    private companion object {
        const val ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"
    }
}
