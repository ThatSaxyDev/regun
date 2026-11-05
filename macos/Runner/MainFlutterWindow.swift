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
    let controller = FlutterMethodChannel(
      name: "regun/controller", binaryMessenger: flutterViewController.engine.binaryMessenger)
    controller.setMethodCallHandler { call, result in
      guard call.method == "read" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let pad = GCController.controllers().compactMap({ $0.extendedGamepad }).first else {
        result(nil)
        return
      }
      let values: [Float] = [
        pad.leftThumbstick.xAxis.value, -pad.leftThumbstick.yAxis.value,
        pad.rightThumbstick.xAxis.value, -pad.rightThumbstick.yAxis.value,
        pad.buttonA.value, pad.buttonB.value, pad.buttonX.value, pad.buttonY.value,
        pad.leftShoulder.value, pad.rightShoulder.value,
        pad.leftTrigger.value, pad.rightTrigger.value,
        0, pad.buttonMenu.value, 0, 0,
        pad.dpad.up.value, pad.dpad.down.value, pad.dpad.left.value, pad.dpad.right.value
      ]
      result(values.map { NSNumber(value: $0) })
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
