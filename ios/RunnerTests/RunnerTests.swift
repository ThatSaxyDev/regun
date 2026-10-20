import Flutter
import UIKit
import XCTest
import AVFAudio

class RunnerTests: XCTestCase {

  func testGameLaunchConfiguresPlaybackSession() {
    let session = AVAudioSession.sharedInstance()
    XCTAssertEqual(session.category, .playback)
    XCTAssertTrue(session.categoryOptions.contains(.mixWithOthers))
    XCTAssertGreaterThan(session.sampleRate, 0)
  }

  func testForegroundRestoresPlaybackCategory() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.ambient)
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    XCTAssertEqual(session.category, .playback)
    XCTAssertTrue(session.categoryOptions.contains(.mixWithOthers))
  }

}
