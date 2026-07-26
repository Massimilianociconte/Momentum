import CoreBluetooth
import Flutter
import Foundation
import UIKit

/// User-initiated Bluetooth SIG Heart Rate Service bridge (0x180D/0x2A37).
/// Peripheral identifiers never leave the device and scans are time-bounded.
final class BleHeartRateBridge: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  private static let service = CBUUID(string: "180D")
  private static let measurement = CBUUID(string: "2A37")

  private let channel: FlutterMethodChannel
  private var central: CBCentralManager?
  private var peripherals: [UUID: CBPeripheral] = [:]
  private var scanRows: [UUID: [String: Any]] = [:]
  private var pendingScan: FlutterResult?
  private var pendingPermission: FlutterResult?
  private var pendingConnect: FlutterResult?
  private var scanTimer: Timer?
  private var connectTimer: Timer?
  private var connectedPeripheral: CBPeripheral?
  private var isConnected = false

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.rallymate/ble_heart_rate",
      binaryMessenger: binaryMessenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
  }

  func dispose() {
    stopScan()
    if pendingConnect != nil {
      failConnect(code: "connect_cancelled", message: "Bluetooth connection cancelled")
    } else {
      disconnect()
    }
    pendingScan?([])
    pendingScan = nil
    pendingPermission?(statusPayload())
    pendingPermission = nil
    channel.setMethodCallHandler(nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(statusPayload())
    case "requestPermissions":
      requestPermissions(result)
    case "scan":
      beginScan(result)
    case "connect":
      guard let arguments = call.arguments as? [String: Any],
            let identifier = arguments["identifier"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "identifier required", details: nil))
        return
      }
      connect(identifier, result: result)
    case "disconnect":
      if pendingConnect != nil {
        failConnect(code: "connect_cancelled", message: "Bluetooth connection cancelled")
      } else {
        disconnect()
      }
      result(true)
    case "openAppSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url, options: [:]) { ok in
          result(ok)
        }
      } else {
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func ensureCentral() -> CBCentralManager {
    if let central { return central }
    let value = CBCentralManager(delegate: self, queue: .main)
    central = value
    return value
  }

  private func requestPermissions(_ result: @escaping FlutterResult) {
    if pendingPermission != nil {
      result(FlutterError(code: "permission_busy", message: "Permission request active", details: nil))
      return
    }
    pendingPermission = result
    let manager = ensureCentral()
    // Complete from centralManagerDidUpdateState once BT is powered/unauthorized.
    // Only fall back after a long timeout so the system dialog can finish.
    if manager.state != .unknown && manager.state != .resetting {
      pendingPermission = nil
      result(statusPayload())
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
      guard let self, let pending = self.pendingPermission else { return }
      self.pendingPermission = nil
      pending(self.statusPayload())
    }
  }

  private func beginScan(_ result: @escaping FlutterResult) {
    if pendingScan != nil {
      result(FlutterError(code: "scan_busy", message: "Scan already active", details: nil))
      return
    }
    pendingScan = result
    scanRows.removeAll(keepingCapacity: true)
    let manager = ensureCentral()
    if manager.state == .poweredOn {
      startScan()
    } else if manager.state != .unknown && manager.state != .resetting {
      finishScan(errorCode: manager.state == .unauthorized ? "permissions_required" : "bluetooth_off")
    }
  }

  private func startScan() {
    guard let central, central.state == .poweredOn else { return }
    central.scanForPeripherals(
      withServices: [Self.service],
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
    )
    scanTimer?.invalidate()
    scanTimer = Timer.scheduledTimer(withTimeInterval: 7, repeats: false) { [weak self] _ in
      self?.finishScan()
    }
  }

  private func stopScan() {
    scanTimer?.invalidate()
    scanTimer = nil
    central?.stopScan()
  }

  private func finishScan(errorCode: String? = nil) {
    stopScan()
    guard let result = pendingScan else { return }
    pendingScan = nil
    if let errorCode {
      result(FlutterError(code: errorCode, message: "Bluetooth scan unavailable", details: nil))
    } else {
      result(Array(scanRows.values))
    }
  }

  private func connect(_ identifier: String, result: @escaping FlutterResult) {
    guard pendingConnect == nil else {
      result(FlutterError(code: "connect_busy", message: "Bluetooth connection active", details: nil))
      return
    }
    guard identifier.count <= 80, let uuid = UUID(uuidString: identifier) else {
      result(FlutterError(code: "bad_args", message: "Invalid identifier", details: nil))
      return
    }
    let manager = ensureCentral()
    guard manager.state == .poweredOn else {
      result(FlutterError(code: "bluetooth_off", message: "Bluetooth unavailable", details: nil))
      return
    }
    let peripheral = peripherals[uuid] ?? manager.retrievePeripherals(withIdentifiers: [uuid]).first
    guard let peripheral else {
      result(FlutterError(code: "device_missing", message: "Peripheral unavailable", details: nil))
      return
    }
    disconnect()
    connectedPeripheral = peripheral
    isConnected = false
    peripheral.delegate = self
    pendingConnect = result
    connectTimer?.invalidate()
    connectTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
      self?.failConnect(code: "connect_timeout", message: "Bluetooth connection timed out")
    }
    manager.connect(peripheral, options: nil)
  }

  private func disconnect() {
    connectTimer?.invalidate()
    connectTimer = nil
    if let connectedPeripheral, let central {
      central.cancelPeripheralConnection(connectedPeripheral)
    }
    connectedPeripheral = nil
    isConnected = false
    channel.invokeMethod("connectionChanged", arguments: statusPayload())
  }

  private func completeConnect() {
    connectTimer?.invalidate()
    connectTimer = nil
    let result = pendingConnect
    pendingConnect = nil
    isConnected = true
    result?(true)
    channel.invokeMethod("connectionChanged", arguments: statusPayload())
  }

  private func failConnect(code: String, message: String) {
    connectTimer?.invalidate()
    connectTimer = nil
    let result = pendingConnect
    pendingConnect = nil
    if let connectedPeripheral, let central {
      central.cancelPeripheralConnection(connectedPeripheral)
    }
    connectedPeripheral = nil
    isConnected = false
    result?(FlutterError(code: code, message: message, details: nil))
    channel.invokeMethod("connectionChanged", arguments: statusPayload())
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if let pending = pendingPermission, central.state != .unknown && central.state != .resetting {
      pendingPermission = nil
      pending(statusPayload())
    }
    if pendingScan != nil {
      if central.state == .poweredOn {
        startScan()
      } else if central.state != .unknown && central.state != .resetting {
        finishScan(errorCode: central.state == .unauthorized ? "permissions_required" : "bluetooth_off")
      }
    }
    channel.invokeMethod("connectionChanged", arguments: statusPayload())
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    peripherals[peripheral.identifier] = peripheral
    let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
    let rawName = (peripheral.name ?? advertised ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let name = String((rawName.isEmpty ? "Sensore cardiaco" : rawName).prefix(80))
    scanRows[peripheral.identifier] = [
      "identifier": peripheral.identifier.uuidString,
      "name": name,
      "signal": RSSI.intValue,
    ]
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    guard connectedPeripheral?.identifier == peripheral.identifier else {
      central.cancelPeripheralConnection(peripheral)
      return
    }
    peripheral.discoverServices([Self.service])
    channel.invokeMethod("connectionChanged", arguments: statusPayload())
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    if connectedPeripheral?.identifier == peripheral.identifier {
      failConnect(code: "connect_failed", message: "Bluetooth connection failed")
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    if connectedPeripheral?.identifier == peripheral.identifier {
      if pendingConnect != nil {
        failConnect(code: "connect_failed", message: "Bluetooth connection interrupted")
      } else {
        isConnected = false
        connectedPeripheral = nil
        channel.invokeMethod("connectionChanged", arguments: statusPayload())
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    // Stale callbacks from a previous peripheral must not abort the current connect.
    guard connectedPeripheral?.identifier == peripheral.identifier else { return }
    guard error == nil,
          let service = peripheral.services?.first(where: { $0.uuid == Self.service })
    else {
      failConnect(code: "sensor_incompatible", message: "Heart rate service unavailable")
      return
    }
    peripheral.discoverCharacteristics([Self.measurement], for: service)
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    // Ignore discovery from a previous connection attempt.
    guard connectedPeripheral?.identifier == peripheral.identifier else { return }
    guard error == nil,
          let characteristic = service.characteristics?.first(where: { $0.uuid == Self.measurement })
    else {
      failConnect(code: "sensor_incompatible", message: "Heart rate measurement unavailable")
      return
    }
    peripheral.setNotifyValue(true, for: characteristic)
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard connectedPeripheral?.identifier == peripheral.identifier,
          characteristic.uuid == Self.measurement else { return }
    if error == nil && characteristic.isNotifying {
      completeConnect()
    } else {
      failConnect(code: "connect_failed", message: "Heart rate subscription failed")
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard connectedPeripheral?.identifier == peripheral.identifier,
          error == nil, characteristic.uuid == Self.measurement,
          let bytes = characteristic.value.map({ [UInt8]($0) }), bytes.count >= 2
    else { return }
    let isUInt16 = bytes[0] & 0x01 != 0
    let bpm: Int
    if isUInt16 {
      guard bytes.count >= 3 else { return }
      bpm = Int(bytes[1]) | Int(bytes[2]) << 8
    } else {
      bpm = Int(bytes[1])
    }
    guard (20...300).contains(bpm) else { return }
    channel.invokeMethod("heartRate", arguments: [
      "bpm": bpm,
      "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
    ])
  }

  private func statusPayload() -> [String: Any] {
    let authorization: CBManagerAuthorization
    if #available(iOS 13.1, *) {
      authorization = CBManager.authorization
    } else {
      authorization = .allowedAlways
    }
    return [
      "supported": true,
      "bluetoothEnabled": central?.state == .poweredOn,
      "permissionsGranted": authorization == .allowedAlways,
      "connected": isConnected,
      "identifier": connectedPeripheral?.identifier.uuidString as Any,
      "name": connectedPeripheral?.name as Any,
    ]
  }
}
