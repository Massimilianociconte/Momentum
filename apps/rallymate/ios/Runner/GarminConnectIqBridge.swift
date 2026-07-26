import ConnectIQ
import CryptoKit
import Flutter
import UIKit

final class GarminConnectIqBridge: NSObject, IQDeviceEventDelegate, IQAppMessageDelegate, IQUIOverrideDelegate {
  static weak var shared: GarminConnectIqBridge?
  private static var deferredSelectionURL: URL?
  private static let garminConnectBundleID = "com.garmin.connect.mobile"

  private let channel: FlutterMethodChannel
  private let defaults = UserDefaults.standard
  private let sdk = ConnectIQ.sharedInstance()!
  private let appUUID = UUID(uuidString: "5735e52b-850f-42c8-8708-2915700c92ad")!
  private let maxQueueEntries = 128
  private let queueLock = NSLock()
  private var devices: [IQDevice] = []
  private var apps: [String: IQApp] = [:]

  private enum Keys {
    static let devices = "rallymate.garmin.devices.v1"
    static let queue = "rallymate.garmin.messages.v1"
  }

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.rallymate/provider_wearables",
      binaryMessenger: binaryMessenger
    )
    super.init()
    Self.shared = self
    restoreDevices()
    sdk.initialize(
      withUrlScheme: "rallymate-garmin",
      uiOverrideDelegate: self,
      stateRestorationIdentifier: "com.rallymate.garmin.ble"
    )
    channel.setMethodCallHandler(handle)
    registerDevices()
    if let url = Self.deferredSelectionURL {
      Self.deferredSelectionURL = nil
      _ = handleSelectionURL(url)
    }
  }

  deinit {
    sdk.unregister(forAllAppMessages: self)
    sdk.unregister(forAllDeviceEvents: self)
    channel.setMethodCallHandler(nil)
  }

  static func receiveSelectionURL(_ url: URL, sourceApplication: String? = nil) -> Bool {
    if let sourceApplication, sourceApplication != garminConnectBundleID {
      return false
    }
    if let shared {
      return shared.handleSelectionURL(url)
    }
    guard url.scheme == "rallymate-garmin" else { return false }
    deferredSelectionURL = url
    return true
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "providerLocalTimeZone":
      result(TimeZone.current.identifier)
    case "garminInitialize", "garminStatus":
      result(statusPayload())
    case "garminDevices":
      result(devices.map(devicePayload))
    case "garminSelectDevices":
      sdk.showDeviceSelection()
      result(true)
    case "garminRegisterDevice":
      registerDevice(call.arguments, result: result)
    case "garminSend":
      send(call.arguments, result: result)
    case "garminOpenStore":
      openStore(call.arguments, result: result)
    case "garminOpenCompanionStore":
      sdk.showAppStoreForConnectMobile()
      result(true)
    case "garminDrainMessages":
      result(drainQueue())
    case "garminAcknowledgeMessages":
      acknowledge(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func statusPayload() -> [String: Any] {
    [
      "provider": "GARMIN_CONNECT_IQ",
      "sdkReady": true,
      "companionInstalled": UIApplication.shared.canOpenURL(URL(string: "gcm-ciq://")!),
      "devices": devices.map(devicePayload),
      "pendingMessages": drainQueue().count,
    ]
  }

  private func handleSelectionURL(_ url: URL) -> Bool {
    guard url.scheme == "rallymate-garmin" else { return false }
    guard let selected = sdk.parseDeviceSelectionResponse(from: url) as? [IQDevice] else {
      return false
    }
    devices = deduplicated(selected)
    persistDevices()
    registerDevices()
    DispatchQueue.main.async {
      self.channel.invokeMethod("garminDevicesSelected", arguments: self.devices.map(self.devicePayload))
    }
    return true
  }

  private func registerDevices() {
    for device in devices {
      sdk.register(forDeviceEvents: device, delegate: self)
      registerApp(for: device)
    }
  }

  private func registerDevice(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let nativeID = args["nativeId"] as? String,
          let device = device(nativeID)
    else {
      result(FlutterError(code: "device_not_found", message: "Garmin non disponibile", details: nil))
      return
    }
    sdk.register(forDeviceEvents: device, delegate: self)
    let app = app(for: device)
    sdk.getAppStatus(app) { [weak self] status in
      guard let self else { return }
      if status?.isInstalled == true {
        self.apps[nativeID] = app
        self.sdk.register(forAppMessages: app, delegate: self)
      }
      DispatchQueue.main.async {
        result([
          "registered": true,
          "appInstalled": status?.isInstalled == true,
          "version": Int(status?.version ?? 0),
          "device": self.devicePayload(device),
        ])
      }
    }
  }

  private func registerApp(for device: IQDevice) {
    let app = app(for: device)
    sdk.getAppStatus(app) { [weak self] status in
      guard let self, status?.isInstalled == true else { return }
      let key = device.uuid.uuidString
      self.apps[key] = app
      self.sdk.register(forAppMessages: app, delegate: self)
    }
  }

  private func app(for device: IQDevice) -> IQApp {
    IQApp(uuid: appUUID, store: appUUID, device: device)
  }

  private func send(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let nativeID = args["nativeId"] as? String,
          let payload = args["payload"],
          let app = apps[nativeID]
    else {
      result(FlutterError(code: "not_ready", message: "Registra prima il dispositivo Garmin", details: nil))
      return
    }
    sdk.sendMessage(payload, to: app, progress: { _, _ in }) { sendResult in
      DispatchQueue.main.async { result(sendResult == .success) }
    }
  }

  private func openStore(_ arguments: Any?, result: FlutterResult) {
    let args = arguments as? [String: Any]
    let nativeID = args?["nativeId"] as? String
    guard let device = nativeID.flatMap(device) ?? devices.first else {
      result(false)
      return
    }
    sdk.showStore(for: app(for: device))
    result(true)
  }

  func needsToInstallConnectMobile() {
    DispatchQueue.main.async {
      self.channel.invokeMethod("garminConnectRequired", arguments: nil)
    }
  }

  func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
    DispatchQueue.main.async {
      self.channel.invokeMethod(
        "garminDeviceChanged",
        arguments: self.devicePayload(device).merging(["status": self.statusName(status)]) { _, new in new }
      )
    }
  }

  func deviceCharacteristicsDiscovered(_ device: IQDevice) {
    registerApp(for: device)
  }

  func receivedMessage(_ message: Any, from app: IQApp) {
    guard let queued = enqueue(message: message, device: app.device) else { return }
    DispatchQueue.main.async {
      self.channel.invokeMethod("garminMessage", arguments: queued)
    }
  }

  private func enqueue(message: Any, device: IQDevice) -> [String: Any]? {
    queueLock.lock()
    defer { queueLock.unlock() }
    guard var queue = readQueueUnlocked() else {
      // Corrupt storage: refuse to overwrite unacknowledged parcels.
      NSLog("RallyMate Garmin queue unreadable; watch event not enqueued")
      return nil
    }
    let normalized = propertyListValue(message)
    let fingerprint = digest(String(describing: normalized))
    if let existing = queue.first(where: { $0["fingerprint"] as? String == fingerprint }) {
      return existing
    }
    // Never evict an unacknowledged score event. If the phone queue is full,
    // leaving the parcel uncommitted makes the Garmin retry from its journal.
    guard queue.count < maxQueueEntries else {
      NSLog("RallyMate Garmin queue full; watch event remains unacknowledged")
      return nil
    }
    let item: [String: Any] = [
      "queueId": UUID().uuidString,
      "nativeId": device.uuid.uuidString,
      "deviceId": digest(device.uuid.uuidString),
      "deviceName": device.friendlyName ?? device.modelName ?? "Garmin",
      "receivedAtMs": Int(Date().timeIntervalSince1970 * 1000),
      "fingerprint": fingerprint,
      "payload": normalized,
    ]
    queue.append(item)
    defaults.set(queue, forKey: Keys.queue)
    return item
  }

  private func drainQueue() -> [[String: Any]] {
    queueLock.lock()
    defer { queueLock.unlock() }
    return readQueueUnlocked() ?? []
  }

  /// `nil` means storage is present but not a valid array (do not wipe).
  private func readQueueUnlocked() -> [[String: Any]]? {
    guard let stored = defaults.object(forKey: Keys.queue) else {
      return []
    }
    return stored as? [[String: Any]]
  }

  private func acknowledge(_ arguments: Any?, result: FlutterResult) {
    let args = arguments as? [String: Any]
    let ids = Set(args?["queueIds"] as? [String] ?? [])
    guard !ids.isEmpty else {
      result(false)
      return
    }
    queueLock.lock()
    defer { queueLock.unlock() }
    guard let queue = readQueueUnlocked() else {
      result(false)
      return
    }
    defaults.set(queue.filter { item in
      guard let id = item["queueId"] as? String else { return false }
      return !ids.contains(id)
    }, forKey: Keys.queue)
    result(true)
  }

  private func devicePayload(_ device: IQDevice) -> [String: Any] {
    [
      "nativeId": device.uuid.uuidString,
      "deviceId": digest(device.uuid.uuidString),
      "name": device.friendlyName ?? device.modelName ?? "Garmin",
      "model": device.modelName ?? "",
      "status": statusName(sdk.getDeviceStatus(device)),
      "appRegistered": apps[device.uuid.uuidString] != nil,
    ]
  }

  private func device(_ nativeID: String) -> IQDevice? {
    devices.first { $0.uuid.uuidString == nativeID }
  }

  private func statusName(_ status: IQDeviceStatus) -> String {
    switch status {
    case .connected: return "CONNECTED"
    case .notConnected: return "NOT_CONNECTED"
    case .notFound: return "NOT_FOUND"
    case .bluetoothNotReady: return "BLUETOOTH_NOT_READY"
    case .invalidDevice: return "INVALID_DEVICE"
    @unknown default: return "UNKNOWN"
    }
  }

  private func deduplicated(_ input: [IQDevice]) -> [IQDevice] {
    var seen = Set<String>()
    return input.filter { seen.insert($0.uuid.uuidString).inserted }
  }

  private func persistDevices() {
    let encoded = devices.compactMap {
      try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
    }
    defaults.set(encoded, forKey: Keys.devices)
  }

  private func restoreDevices() {
    let encoded = defaults.array(forKey: Keys.devices) as? [Data] ?? []
    devices = encoded.compactMap {
      try? NSKeyedUnarchiver.unarchivedObject(ofClass: IQDevice.self, from: $0)
    }
  }

  private func propertyListValue(_ value: Any) -> Any {
    if let dictionary = value as? [String: Any] {
      return dictionary.mapValues(propertyListValue)
    }
    if let array = value as? [Any] {
      return array.map(propertyListValue)
    }
    if value is String || value is NSNumber || value is Data || value is Date {
      return value
    }
    if value is NSNull { return NSNull() }
    return String(describing: value)
  }

  private func digest(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
  }
}
