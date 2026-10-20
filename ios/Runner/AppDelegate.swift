import Flutter
import UIKit
import AVFAudio

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
  }
}
