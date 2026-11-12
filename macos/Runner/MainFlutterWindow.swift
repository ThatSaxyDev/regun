import Cocoa
import GameController
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let minimumSize = NSSize(width: 960, height: 540)
    let preferredSize = NSSize(width: 1280, height: 720)
    contentMinSize = minimumSize
    isRestorable = false
    collectionBehavior.insert(.fullScreenPrimary)
    self.contentViewController = flutterViewController
    let availableSize = (screen ?? NSScreen.main).map {
      contentRect(forFrameRect: $0.visibleFrame).size
    } ?? preferredSize
    setContentSize(NSSize(
      width: max(minimumSize.width, min(preferredSize.width, availableSize.width)),
      height: max(minimumSize.height, min(preferredSize.height, availableSize.height))
    ))
    center()

    RegisterGeneratedPlugins(registry: flutterViewController)
    (NSApp.delegate as? AppDelegate)?.registerPushChannel(flutterViewController.engine.binaryMessenger)
    let controller = FlutterMethodChannel(
      name: "regun/controller", binaryMessenger: flutterViewController.engine.binaryMessenger)
    FlutterEventChannel(
      name: "regun/controller/connections", binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setStreamHandler(ControllerConnections())
    controller.setMethodCallHandler { call, result in
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

    let display = FlutterMethodChannel(
      name: "regun/display", binaryMessenger: flutterViewController.engine.binaryMessenger)
    display.setMethodCallHandler { [weak self] call, result in
      if call.method == "quit" {
        result(nil)
        NSApp.terminate(nil)
        return
      }
      guard call.method == "toggleFullscreen", let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.toggleFullScreen(nil)
      result(true)
    }
    super.awakeFromNib()
  }
}

private final class ControllerConnections: NSObject, FlutterStreamHandler {
  private var observers: [NSObjectProtocol] = []

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stop()
    for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
      observers.append(NotificationCenter.default.addObserver(
        forName: name, object: nil, queue: .main
      ) { _ in events(true) })
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stop()
    return nil
  }

  deinit { stop() }

  private func stop() {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers.removeAll()
  }
}
