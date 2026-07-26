package com.rallymate.rallymate

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/** User-initiated Bluetooth SIG Heart Rate Service bridge (0x180D/0x2A37). */
@Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
class BleHeartRateBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val CHANNEL = "com.rallymate/ble_heart_rate"
        private const val REQUEST_PERMISSIONS = 4762
        private val HEART_RATE_SERVICE: UUID =
            UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
        private val HEART_RATE_MEASUREMENT: UUID =
            UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
        private val CLIENT_CHARACTERISTIC_CONFIG: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val handler = Handler(Looper.getMainLooper())
    private val manager = activity.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val adapter: BluetoothAdapter?
        get() = manager.adapter
    private val discovered = linkedMapOf<String, Map<String, Any?>>()
    private var pendingPermission: MethodChannel.Result? = null
    private var pendingScan: MethodChannel.Result? = null
    private var pendingConnect: MethodChannel.Result? = null
    private var scanning = false
    private var gatt: BluetoothGatt? = null
    private var isConnected = false
    private var connectedIdentifier: String? = null
    private var connectedName: String? = null
    private val connectTimeout = Runnable {
        failConnect("connect_timeout", "Bluetooth connection timed out")
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status())
                "requestPermissions" -> requestPermissions(result)
                "scan" -> scan(result)
                "connect" -> connect(call.argument<String>("identifier"), result)
                "disconnect" -> {
                    if (pendingConnect != null) {
                        failConnect("connect_cancelled", "Bluetooth connection cancelled")
                    } else {
                        disconnect()
                    }
                    result.success(true)
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", activity.packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        activity.startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_PERMISSIONS) return false
        val result = pendingPermission
        pendingPermission = null
        result?.success(status())
        return true
    }

    fun dispose() {
        stopScan()
        pendingScan?.success(emptyList<Map<String, Any?>>())
        pendingScan = null
        pendingPermission?.success(status())
        pendingPermission = null
        failConnect("connect_cancelled", "Bluetooth connection cancelled")
        disconnect()
        channel.setMethodCallHandler(null)
    }

    @SuppressLint("MissingPermission")
    private fun status(): Map<String, Any?> {
        val permissionsGranted = hasPermissions()
        // BluetoothAdapter.isEnabled requires BLUETOOTH_CONNECT on Android 12+.
        // The status method is intentionally callable before requesting it.
        val bluetoothEnabled = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !permissionsGranted
        ) {
            false
        } else {
            runCatching { adapter?.isEnabled == true }.getOrDefault(false)
        }
        return mapOf(
            "supported" to (adapter != null),
            "bluetoothEnabled" to bluetoothEnabled,
            "permissionsGranted" to permissionsGranted,
            "connected" to isConnected,
            "identifier" to connectedIdentifier,
            "name" to connectedName,
        )
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (hasPermissions()) {
            result.success(status())
            return
        }
        if (pendingPermission != null) {
            result.error("permission_busy", "Permission request already active", null)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(
            activity,
            requiredPermissions().toTypedArray(),
            REQUEST_PERMISSIONS,
        )
    }

    @SuppressLint("MissingPermission")
    private fun scan(result: MethodChannel.Result) {
        if (!hasPermissions()) {
            result.error("permissions_required", "Bluetooth permission required", null)
            return
        }
        if (pendingConnect != null) {
            result.error("connect_busy", "Bluetooth connection already active", null)
            return
        }
        val scanner = adapter?.takeIf { it.isEnabled }?.bluetoothLeScanner
        if (scanner == null) {
            result.error("bluetooth_off", "Bluetooth is disabled", null)
            return
        }
        if (pendingScan != null) {
            result.error("scan_busy", "Scan already active", null)
            return
        }
        discovered.clear()
        pendingScan = result
        scanning = true
        val filters = listOf(
            ScanFilter.Builder().setServiceUuid(ParcelUuid(HEART_RATE_SERVICE)).build(),
        )
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        try {
            scanner.startScan(filters, settings, scanCallback)
        } catch (_: SecurityException) {
            scanning = false
            pendingScan = null
            result.error("permissions_required", "Bluetooth permission required", null)
            return
        } catch (_: IllegalStateException) {
            scanning = false
            pendingScan = null
            result.error("scan_failed", "Bluetooth scan could not start", null)
            return
        }
        handler.postDelayed({ finishScan() }, 7_000)
    }

    private fun finishScan() {
        stopScan()
        val result = pendingScan ?: return
        pendingScan = null
        result.success(discovered.values.toList())
    }

    @SuppressLint("MissingPermission")
    private fun stopScan() {
        if (!scanning) return
        scanning = false
        if (hasPermissions()) {
            runCatching { adapter?.bluetoothLeScanner?.stopScan(scanCallback) }
        }
    }

    private val scanCallback = object : ScanCallback() {
        @SuppressLint("MissingPermission")
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device ?: return
            val identifier = runCatching { device.address }.getOrNull() ?: return
            val name = runCatching {
                device.name ?: result.scanRecord?.deviceName
            }.getOrNull()
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?.take(80)
                ?: "Sensore cardiaco"
            discovered[identifier] = mapOf(
                "identifier" to identifier,
                "name" to name,
                "signal" to result.rssi,
            )
        }

        override fun onScanFailed(errorCode: Int) {
            stopScan()
            val result = pendingScan ?: return
            pendingScan = null
            result.error("scan_failed", "Bluetooth scan failed", errorCode)
        }
    }

    @SuppressLint("MissingPermission")
    private fun connect(identifier: String?, result: MethodChannel.Result) {
        if (pendingConnect != null) {
            result.error("connect_busy", "Bluetooth connection already active", null)
            return
        }
        if (identifier.isNullOrBlank() || identifier.length > 80) {
            result.error("bad_args", "identifier required", null)
            return
        }
        if (!hasPermissions()) {
            result.error("permissions_required", "Bluetooth permission required", null)
            return
        }
        val device = runCatching { adapter?.getRemoteDevice(identifier) }.getOrNull()
        if (device == null) {
            result.error("device_missing", "Bluetooth device unavailable", null)
            return
        }
        stopScan()
        disconnect()
        connectedIdentifier = identifier
        isConnected = false
        connectedName = runCatching { device.name }.getOrNull()
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.take(80)
            ?: discovered[identifier]?.get("name")?.toString()
            ?: "Sensore cardiaco"
        pendingConnect = result
        gatt = try {
            device.connectGatt(activity, false, gattCallback, BluetoothDeviceTransport.LE)
        } catch (_: SecurityException) {
            failConnect("permissions_required", "Bluetooth permission required")
            return
        } catch (_: IllegalArgumentException) {
            failConnect("connect_failed", "Bluetooth connection could not start")
            return
        }
        if (gatt == null) {
            failConnect("connect_failed", "Bluetooth connection could not start")
            return
        }
        handler.postDelayed(connectTimeout, 12_000)
    }

    @SuppressLint("MissingPermission")
    private fun disconnect() {
        handler.removeCallbacks(connectTimeout)
        val current = gatt
        gatt = null
        isConnected = false
        connectedIdentifier = null
        connectedName = null
        runCatching { current?.disconnect() }
        runCatching { current?.close() }
        channel.invokeMethod("connectionChanged", status())
    }

    private fun completeConnect() {
        handler.removeCallbacks(connectTimeout)
        val result = pendingConnect ?: return
        pendingConnect = null
        isConnected = true
        result.success(true)
        channel.invokeMethod("connectionChanged", status())
    }

    @SuppressLint("MissingPermission")
    private fun failConnect(code: String, message: String) {
        handler.removeCallbacks(connectTimeout)
        val result = pendingConnect
        pendingConnect = null
        val current = gatt
        gatt = null
        isConnected = false
        connectedIdentifier = null
        connectedName = null
        runCatching { current?.disconnect() }
        runCatching { current?.close() }
        result?.error(code, message, null)
        channel.invokeMethod("connectionChanged", status())
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (gatt !== this@BleHeartRateBridge.gatt) {
                runCatching { gatt.close() }
                return
            }
            if (status == BluetoothGatt.GATT_SUCCESS && newState == BluetoothProfile.STATE_CONNECTED) {
                val discoveryStarted = hasPermissions() &&
                    runCatching { gatt.discoverServices() }.getOrDefault(false)
                if (!discoveryStarted) handler.post {
                    val permissionMissing = !hasPermissions()
                    failConnect(
                        if (permissionMissing) "permissions_required" else "connect_failed",
                        if (permissionMissing) {
                            "Bluetooth permission required"
                        } else {
                            "Heart rate service discovery could not start"
                        },
                    )
                }
            } else {
                handler.post {
                    failConnect("connect_failed", "Bluetooth connection failed")
                }
            }
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (gatt !== this@BleHeartRateBridge.gatt) return
            if (status != BluetoothGatt.GATT_SUCCESS || !hasPermissions()) {
                handler.post { failConnect("connect_failed", "Heart rate service unavailable") }
                return
            }
            val characteristic = gatt.getService(HEART_RATE_SERVICE)
                ?.getCharacteristic(HEART_RATE_MEASUREMENT)
            val descriptor = characteristic?.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG)
            if (characteristic == null || descriptor == null) {
                handler.post { failConnect("sensor_incompatible", "Heart rate notifications unavailable") }
                return
            }
            val started = runCatching {
                if (!gatt.setCharacteristicNotification(characteristic, true)) {
                    return@runCatching false
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    gatt.writeDescriptor(
                        descriptor,
                        BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE,
                    ) == BluetoothStatusCodes.SUCCESS
                } else {
                    @Suppress("DEPRECATION")
                    descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    @Suppress("DEPRECATION")
                    gatt.writeDescriptor(descriptor)
                }
            }.getOrDefault(false)
            if (!started) {
                handler.post { failConnect("connect_failed", "Heart rate subscription failed") }
            }
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int,
        ) {
            if (gatt !== this@BleHeartRateBridge.gatt) return
            if (descriptor.uuid != CLIENT_CHARACTERISTIC_CONFIG) return
            handler.post {
                if (status == BluetoothGatt.GATT_SUCCESS) completeConnect()
                else failConnect("connect_failed", "Heart rate subscription failed")
            }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            if (gatt !== this@BleHeartRateBridge.gatt || !isConnected) return
            emitHeartRate(value)
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
        ) {
            if (gatt !== this@BleHeartRateBridge.gatt || !isConnected) return
            @Suppress("DEPRECATION")
            emitHeartRate(characteristic.value ?: return)
        }
    }

    private fun emitHeartRate(value: ByteArray) {
        if (value.size < 2) return
        val isUInt16 = value[0].toInt() and 0x01 != 0
        val bpm = if (isUInt16) {
            if (value.size < 3) return
            (value[1].toInt() and 0xff) or ((value[2].toInt() and 0xff) shl 8)
        } else {
            value[1].toInt() and 0xff
        }
        if (bpm !in 20..300) return
        handler.post {
            channel.invokeMethod("heartRate", mapOf(
                "bpm" to bpm,
                "timestampMs" to System.currentTimeMillis(),
            ))
        }
    }

    private fun hasPermissions(): Boolean = requiredPermissions().all {
        ActivityCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
    }

    private fun requiredPermissions(): List<String> = if (Build.VERSION.SDK_INT >= 31) {
        listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
    } else {
        listOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    private object BluetoothDeviceTransport {
        const val LE = 2
    }
}
