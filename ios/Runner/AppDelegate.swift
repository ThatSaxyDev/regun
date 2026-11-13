import Flutter
import UIKit
import AVFAudio
import GameController

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // SoLoud intentionally leaves iOS session ownership to the application.
    // Activate before Dart starts the Audio Unit, and recover on foregrounding.
    activateGameAudio()
    let notifications = NotificationCenter.default
    notifications.addObserver(self, selector: #selector(activateGameAudio(_:)),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    notifications.addObserver(self, selector: #selector(activateGameAudio(_:)),
      name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    notifications.addObserver(self, selector: #selector(audioInterrupted(_:)),
      name: AVAudioSession.interruptionNotification, object: nil)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func activateGameAudio(_ notification: Notification? = nil) {
    guard UIApplication.shared.applicationState != .background else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      // Game preferences control music/SFX; mix politely with other apps.
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
      NSLog("Regun audio session active: %@, output volume %.2f",
        session.category.rawValue, session.outputVolume)
    } catch {
      NSLog("Regun audio session activation failed: %@", String(describing: error))
    }
  }

  @objc private func audioInterrupted(_ notification: Notification) {
    guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      type == AVAudioSession.InterruptionType.ended.rawValue,
      UIApplication.shared.applicationState == .active else { return }
    let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
    if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
      activateGameAudio()
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(
      name: "regun/controller", binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "read" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let devices = GCController.controllers().compactMap { controller -> [String: Any]? in
        guard let pad = controller.extendedGamepad else { return nil }
        let values: [Float] = [
          pad.leftThumbstick.xAxis.value, -pad.leftThumbstick.yAxis.value,
          pad.rightThumbstick.xAxis.value, -pad.rightThumbstick.yAxis.value,
          pad.buttonA.value, pad.buttonB.value, pad.buttonX.value, pad.buttonY.value,
          pad.leftShoulder.value, pad.rightShoulder.value,
          pad.leftTrigger.value, pad.rightTrigger.value,
          pad.buttonOptions?.value ?? 0, pad.buttonMenu.value,
          pad.leftThumbstickButton?.value ?? 0, pad.rightThumbstickButton?.value ?? 0,
          pad.dpad.up.value, pad.dpad.down.value, pad.dpad.left.value, pad.dpad.right.value
        ]
        return [
          "id": String(describing: ObjectIdentifier(controller)),
          "name": controller.vendorName ?? "",
          "values": values.map { NSNumber(value: $0) },
        ]
      }
      result(devices)
    }

    FlutterMethodChannel(
      name: "regun/push_timezone", binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      if call.method == "current" {
        result(TimeZone.autoupdatingCurrent.identifier)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
