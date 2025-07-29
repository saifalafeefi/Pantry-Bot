import Flutter
import UIKit
import Updraft

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialize Updraft SDK for automatic iOS updates
    Updraft.shared.start(
      sdkKey: "77448ae771054537b2a617cfef129419",  // API Key as SDK Key
      appKey: "d05a3d6dfffb4836a4c8f7c4482ff6a7"    // App Key from dashboard
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
