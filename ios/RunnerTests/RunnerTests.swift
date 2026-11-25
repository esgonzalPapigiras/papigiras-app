import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {
  @MainActor
  func testLaunchDisplaysFlutterInAnApplicationScene() async throws {
    // UIKit may connect the scene after the hosted test bundle starts.
    let sceneConnected = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .contains { scene in
            scene.delegate is FlutterSceneDelegate && scene.windows.contains {
              $0.rootViewController is FlutterViewController
            }
          }
      },
      object: nil
    )
    await fulfillment(of: [sceneConnected], timeout: 30)

    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.delegate is FlutterSceneDelegate })
    let controller = try XCTUnwrap(scene.windows
      .compactMap { $0.rootViewController as? FlutterViewController }.first)
    let engine = try XCTUnwrap(controller.engine)
    XCTAssertTrue(engine.hasPlugin("BackgroundLocatorPlugin"))

    let firstFrame = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "displayingFlutterUI == YES"),
      object: controller
    )
    await fulfillment(of: [firstFrame], timeout: 30)
  }
}
