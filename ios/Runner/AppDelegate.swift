import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var documentController: UIDocumentInteractionController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OpenLocalFile") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.nucleus.nucleus/open_file",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result("Invalid arguments")
        return
      }
      let url = URL(fileURLWithPath: path)
      guard FileManager.default.fileExists(atPath: path) else {
        result("File not found")
        return
      }
      let controller = UIDocumentInteractionController(url: url)
      self?.documentController = controller
      guard let rootView = self?.window?.rootViewController?.view else {
        result("No window")
        return
      }
      let rect = CGRect(x: rootView.bounds.midX, y: rootView.bounds.midY, width: 0, height: 0)
      if controller.presentOpenInMenu(from: rect, in: rootView, animated: true) {
        result(nil)
        return
      }
      if controller.presentOptionsMenu(from: rect, in: rootView, animated: true) {
        result(nil)
        return
      }
      result("No app found to open this file")
    }
  }
}
