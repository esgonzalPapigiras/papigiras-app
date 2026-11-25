import Flutter
import UIKit
import LocalAuthentication
import Security
import background_locator_2

func registerLocationPlugins(registry: FlutterPluginRegistry) {
  GeneratedPluginRegistrant.register(with: registry)
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Install the headless location callback before the scene creates its engine.
    BackgroundLocatorPlugin.setPluginRegistrantCallback(registerLocationPlugins)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // UIScene owns the window; the launch callback must not look up its controller.
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let credentials = FlutterMethodChannel(
      name: "com.papigiras.lab/credentials",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    credentials.setMethodCallHandler(Self.handleCredential)
  }

  /// One credential per role, encrypted by Keychain and readable only while
  /// this device is unlocked. No iCloud synchronization or backup migration.
  /// This also works in Simulator, which has no device passcode to enroll.
  private static func handleCredential(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: String],
          let role = arguments["role"],
          ["attorney", "passenger", "coordinator"].contains(role) else {
      result(FlutterError(code: "invalid-role", message: nil, details: nil))
      return
    }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.papigiras.lab.pilo.sign-in",
      kSecAttrAccount as String: role
    ]
    let unavailable = FlutterError(code: "keychain-unavailable", message: nil, details: nil)

    switch call.method {
    case "contains":
      var lookup = query
      lookup[kSecReturnAttributes as String] = true
      lookup[kSecMatchLimit as String] = kSecMatchLimitOne
      let context = LAContext()
      context.interactionNotAllowed = true
      lookup[kSecUseAuthenticationContext as String] = context
      var item: CFTypeRef?
      let status = SecItemCopyMatching(lookup as CFDictionary, &item)
      result(status == errSecSuccess || status == errSecInteractionNotAllowed)
    case "read":
      DispatchQueue.global(qos: .userInitiated).async {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext()
        context.localizedReason = "Autentícate para usar tu contraseña de Papigiras"
        lookup[kSecUseAuthenticationContext as String] = context
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        DispatchQueue.main.async {
          switch status {
          case errSecSuccess:
            guard let data = item as? Data,
                  let payload = try? JSONDecoder().decode([String: String].self, from: data) else {
              result(unavailable)
              return
            }
            result(payload)
          case errSecUserCanceled, errSecItemNotFound:
            result(nil)
          default:
            result(unavailable)
          }
        }
      }
    case "save":
      guard let rut = arguments["rut"], !rut.isEmpty,
            let password = arguments["password"], !password.isEmpty,
            let data = try? JSONEncoder().encode(["rut": rut, "password": password]) else {
        result(unavailable)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        var entry = query
        entry[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        entry[kSecValueData as String] = data
        var status = SecItemAdd(entry as CFDictionary, nil)
        if status == errSecDuplicateItem {
          let context = LAContext()
          context.localizedReason = "Autentícate para actualizar tu contraseña guardada"
          var lookup = query
          lookup[kSecUseAuthenticationContext as String] = context
          status = SecItemUpdate(
            lookup as CFDictionary, [kSecValueData as String: data] as CFDictionary
          )
        }
        DispatchQueue.main.async {
          if status == errSecSuccess {
            result(nil)
          } else {
            result(unavailable)
          }
        }
      }
    case "delete":
      let status = SecItemDelete(query as CFDictionary)
      if status == errSecSuccess || status == errSecItemNotFound {
        result(nil)
      } else {
        result(unavailable)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
