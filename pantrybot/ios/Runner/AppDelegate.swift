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
    
    // Initialize Updraft SDK for automatic iOS updates with DEBUG LOGGING
    print("🔧 BEFORE Updraft SDK initialization")
    
    Updraft.shared.logLevel = .info  // Enable detailed logging for debugging
    print("🔧 Set Updraft log level to .info")
    
            Updraft.shared.start(
          sdkKey: "ef480248ff8745b193419b42524a3c94",  // NEW SDK Key from dashboard
          appKey: "d05a3d6dfffb4836a4c8f7c4482ff6a7"    // App Key from dashboard
        )
    
    print("🚀 Updraft SDK initialized with logging enabled")
    print("📱 Debug Console: Updraft SDK is ready for automatic updates")
    print("🔍 Debug Console: You can view these logs in the app's debug console")
    print("🔧 AFTER Updraft SDK initialization - SDK should be running now")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
