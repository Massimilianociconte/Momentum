import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var watchBridge: RallyMateWatchBridge?
  private var notificationBridge: RallyMateNotificationBridge?
  private var healthBridge: HealthKitBridge?
  private var garminBridge: GarminConnectIqBridge?
  private var bleHeartRateBridge: BleHeartRateBridge?
  private var pendingLaunchNotificationDeepLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      pendingLaunchNotificationDeepLink = RallyMateNotificationBridge.deepLink(from: userInfo)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    watchBridge = RallyMateWatchBridge(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    notificationBridge = RallyMateNotificationBridge(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    if let deepLink = pendingLaunchNotificationDeepLink {
      notificationBridge?.acceptInitialDeepLink(deepLink)
      pendingLaunchNotificationDeepLink = nil
    }
    healthBridge = HealthKitBridge(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    garminBridge = GarminConnectIqBridge(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    bleHeartRateBridge = BleHeartRateBridge(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let source = options[.sourceApplication] as? String
    if GarminConnectIqBridge.receiveSelectionURL(url, sourceApplication: source) { return true }
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
    notificationBridge?.didRegisterForRemoteNotifications(deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
    notificationBridge?.didFailToRegisterForRemoteNotifications(error)
  }
}

private final class RallyMateNotificationBridge: NSObject, UNUserNotificationCenterDelegate {
  private static let openActionIdentifier = "RALLYMATE_OPEN"
  private static let categoryIdentifiers = [
    "FRIEND_REQUEST", "FRIEND_ACCEPTED", "TEAM_REQUEST",
    "TEAM_REQUEST_ACCEPTED", "TEAM_INVITE", "TEAM_INVITE_ACCEPTED",
    "MATCH_PROPOSAL", "MATCH_PROPOSAL_ACCEPTED",
    "DUO_JOINED", "COACH_ASSIGNMENT", "COACH_PACKAGE_UPDATED",
    "TRAINING_REMINDER", "CRITICAL_SYNC", "ACCOUNT",
    "match", "training", "recap", "reminder", "status",
  ]
  private let channel: FlutterMethodChannel
  private let center = UNUserNotificationCenter.current()
  private var pendingRegistrationResult: FlutterResult?
  private var pendingRegistrationTimeout: DispatchWorkItem?
  private var initialDeepLink: String?

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.rallymate/notifications",
      binaryMessenger: binaryMessenger
    )
    super.init()
    center.delegate = self
    configureCategories()
    channel.setMethodCallHandler(handle)
  }

  private func configureCategories() {
    let openAction = UNNotificationAction(
      identifier: Self.openActionIdentifier,
      title: "Apri Padelandia",
      options: [.foreground]
    )
    center.setNotificationCategories(Set(
      Self.categoryIdentifiers.map {
        UNNotificationCategory(
          identifier: $0,
          actions: [openAction],
          intentIdentifiers: [],
          options: []
        )
      }
    ))
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      status(result)
    case "requestPermission":
      requestPermission(result)
    case "registerRemote":
      registerRemote(result)
    case "unregisterRemote":
      unregisterRemote(result)
    case "initialNotification":
      result(initialDeepLink)
      initialDeepLink = nil
    case "show":
      show(call.arguments, result: result)
    case "schedule":
      schedule(call.arguments, result: result)
    case "cancel":
      cancel(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func status(_ result: @escaping FlutterResult) {
    center.getNotificationSettings { settings in
      DispatchQueue.main.async {
        result(self.statusPayload(settings))
      }
    }
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
      self.status(result)
    }
  }

  private func registerRemote(_ result: @escaping FlutterResult) {
    center.getNotificationSettings { settings in
      DispatchQueue.main.async {
        guard self.isAuthorized(settings.authorizationStatus) else {
          result(FlutterError(
            code: "permission_required",
            message: "Notification permission required",
            details: nil
          ))
          return
        }
        guard self.pendingRegistrationResult == nil else {
          result(FlutterError(
            code: "busy",
            message: "APNs registration already pending",
            details: nil
          ))
          return
        }
        self.pendingRegistrationResult = result
        let timeout = DispatchWorkItem { [weak self] in
          self?.finishRegistration(errorCode: "token_timeout", message: "APNs token timed out")
        }
        self.pendingRegistrationTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
        UIApplication.shared.registerForRemoteNotifications()
      }
    }
  }

  private func unregisterRemote(_ result: @escaping FlutterResult) {
    finishRegistration(errorCode: "registration_cancelled", message: "Registration cancelled")
    UIApplication.shared.unregisterForRemoteNotifications()
    result(nil)
  }

  func didRegisterForRemoteNotifications(_ deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    guard token.count == 64 else {
      finishRegistration(errorCode: "invalid_token", message: "APNs returned an invalid token")
      return
    }
    pendingRegistrationTimeout?.cancel()
    pendingRegistrationTimeout = nil
    if let result = pendingRegistrationResult {
      pendingRegistrationResult = nil
      result(remoteTokenPayload(token))
    } else {
      channel.invokeMethod("remoteTokenChanged", arguments: remoteTokenPayload(token))
    }
  }

  func didFailToRegisterForRemoteNotifications(_ error: Error) {
    finishRegistration(
      errorCode: "token_unavailable",
      message: error.localizedDescription
    )
  }

  func acceptInitialDeepLink(_ value: String) {
    guard let safe = Self.validDeepLink(value) else { return }
    initialDeepLink = safe
  }

  private func show(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let request = makeRequest(arguments, trigger: nil) else {
      result(FlutterError(code: "bad_args", message: "Invalid notification payload", details: nil))
      return
    }
    add(request, result: result)
  }

  private func schedule(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let scheduledAtMs = args["scheduledAtMs"] as? NSNumber
    else {
      result(FlutterError(code: "bad_args", message: "scheduledAtMs required", details: nil))
      return
    }
    let scheduledAt = Date(timeIntervalSince1970: scheduledAtMs.doubleValue / 1000)
    let delay = max(1, scheduledAt.timeIntervalSinceNow)
    guard let request = makeRequest(
      arguments,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
    ) else {
      result(FlutterError(code: "bad_args", message: "Invalid notification payload", details: nil))
      return
    }
    add(request, result: result)
  }

  private func cancel(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let id = args["id"] as? String
    else {
      result(FlutterError(code: "bad_args", message: "id required", details: nil))
      return
    }
    center.removePendingNotificationRequests(withIdentifiers: [id])
    center.removeDeliveredNotifications(withIdentifiers: [id])
    result(nil)
  }

  private func makeRequest(
    _ arguments: Any?,
    trigger: UNNotificationTrigger?
  ) -> UNNotificationRequest? {
    guard let args = arguments as? [String: Any],
          let id = args["id"] as? String,
          let title = args["title"] as? String
    else {
      return nil
    }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = args["body"] as? String ?? ""
    content.sound = .default
    content.categoryIdentifier = args["category"] as? String ?? "status"
    if let payload = args["payload"] as? String {
      content.userInfo = ["payload": payload]
    }
    return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
  }

  private func add(_ request: UNNotificationRequest, result: @escaping FlutterResult) {
    center.add(request) { error in
      DispatchQueue.main.async {
        result(error == nil)
      }
    }
  }

  private func statusPayload(_ settings: UNNotificationSettings) -> [String: Any] {
    if #available(iOS 14.0, *), settings.authorizationStatus == .ephemeral {
      return [
        "status": "ephemeral",
        "granted": true,
        "canRequest": false,
      ]
    }
    let status: String
    let granted: Bool
    switch settings.authorizationStatus {
    case .authorized:
      status = "authorized"
      granted = true
    case .provisional:
      status = "provisional"
      granted = true
    case .ephemeral:
      status = "ephemeral"
      granted = true
    case .notDetermined:
      status = "notDetermined"
      granted = false
    case .denied:
      status = "denied"
      granted = false
    @unknown default:
      status = "denied"
      granted = false
    }
    return [
      "status": status,
      "granted": granted,
      "canRequest": settings.authorizationStatus == .notDetermined,
    ]
  }

  private func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
    switch status {
    case .authorized, .provisional, .ephemeral:
      return true
    default:
      return false
    }
  }

  private func finishRegistration(errorCode: String, message: String) {
    guard let result = pendingRegistrationResult else { return }
    pendingRegistrationResult = nil
    pendingRegistrationTimeout?.cancel()
    pendingRegistrationTimeout = nil
    result(FlutterError(code: errorCode, message: message, details: nil))
  }

  private func remoteTokenPayload(_ token: String) -> [String: String] {
    #if DEBUG
    let environment = "SANDBOX"
    #else
    let environment = "PRODUCTION"
    #endif
    return [
      "token": token,
      "platform": "IOS",
      "transport": "APNS",
      "environment": environment,
    ]
  }

  static func deepLink(from userInfo: [AnyHashable: Any]) -> String? {
    for key in ["deep_link", "payload"] {
      if let value = userInfo[key] as? String,
         let safe = validDeepLink(value) {
        return safe
      }
    }
    return nil
  }

  private static func validDeepLink(_ raw: String) -> String? {
    let candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard candidate.count <= 512,
          let components = URLComponents(string: candidate),
          components.scheme?.lowercased() == "rallymate",
          let host = components.host?.lowercased(),
          components.user == nil,
          components.password == nil,
          components.port == nil,
          components.fragment == nil,
          [
            "auth-callback", "coach", "devices", "friends", "invite",
            "match", "recap", "social", "teams", "training",
          ].contains(host)
    else {
      return nil
    }
    return candidate
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    _ = center
    _ = notification
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    _ = center
    if let deepLink = Self.deepLink(from: response.notification.request.content.userInfo) {
      initialDeepLink = deepLink
      channel.invokeMethod("notificationOpened", arguments: deepLink)
    }
    completionHandler()
  }
}
