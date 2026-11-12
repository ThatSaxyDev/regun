import Cocoa
import FlutterMacOS
import Security
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var pushToken: String?
  private var pendingAvailabilityTap = false
  private var suppressForeground = false
  private var registering = false
  private var registrationError = false
  private var lastRegistrationAttempt: Date?

  private var pushEnvironment: String? {
    guard let task = SecTaskCreateFromSelf(nil),
          let value = SecTaskCopyValueForEntitlement(
            task, "com.apple.developer.aps-environment" as CFString, nil
          ) as? String else { return nil }
    if value == "development" { return "sandbox" }
    return value == "production" ? value : nil
  }

  func registerPushChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "regun/mac_push", binaryMessenger: messenger)
    pushChannel = channel
    UNUserNotificationCenter.current().delegate = self
    channel.setMethodCallHandler { [weak self] call, reply in
      guard let self else { reply(nil); return }
      switch call.method {
      case "status":
        self.reportPushStatus(reply)
      case "request":
        guard self.pushEnvironment != nil else { reply(false); return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
          DispatchQueue.main.async {
            if granted { self.startPushRegistration() }
            reply(granted)
          }
        }
      case "suppress":
        self.suppressForeground = call.arguments as? Bool ?? false
        reply(nil)
      default:
        reply(FlutterMethodNotImplemented)
      }
    }
  }

  private func startPushRegistration() {
    guard pushToken == nil && !registering else { return }
    let now = Date()
    if let previous = lastRegistrationAttempt, now.timeIntervalSince(previous) < 60 { return }
    lastRegistrationAttempt = now
    registering = true
    registrationError = false
    NSApplication.shared.registerForRemoteNotifications()
  }

  private func reportPushStatus(_ reply: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        let environment = self.pushEnvironment
        let granted = settings.authorizationStatus == .authorized ||
          settings.authorizationStatus == .provisional
        if granted && environment != nil { self.startPushRegistration() }
        let status: [String: Any] = [
          "environment": environment ?? "",
          "permission": granted ? "granted" :
            settings.authorizationStatus == .denied ? "denied" : "default",
          "token": self.pushToken ?? "",
          "registrationError": self.registrationError,
          "opened": self.pendingAvailabilityTap,
        ]
        self.pendingAvailabilityTap = false
        reply(status)
      }
    }
  }

  override func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    pushToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    registering = false
    registrationError = false
    pushChannel?.invokeMethod("changed", arguments: nil)
  }

  override func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    registering = false
    registrationError = true
    pushChannel?.invokeMethod("changed", arguments: nil)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    DispatchQueue.main.async {
      completionHandler(self.suppressForeground ? [] : [.banner, .list, .sound])
    }
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    DispatchQueue.main.async {
      if response.notification.request.content.userInfo["availability"] as? String == "true" {
        self.pendingAvailabilityTap = true
        self.pushChannel?.invokeMethod("changed", arguments: nil)
      }
      completionHandler()
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
