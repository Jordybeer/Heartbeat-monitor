import SwiftUI
import UserNotifications
import HealthKitUI

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if options.shouldHandleActiveWorkoutRecovery {
            UserDefaults.standard.set(true, forKey: "workoutWasActive")
            Task { @MainActor in await MonitorModel.shared.recoverSystemWorkout() }
        }
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {}

@main
struct HeartbeatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = MonitorModel.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).tint(Palette.accent)
                .sheet(isPresented: Binding(get: { !model.hasOnboarded }, set: { _ in })) {
                    OnboardingView().environmentObject(model).tint(Palette.accent).interactiveDismissDisabled()
                }
                .onChange(of: scenePhase) { _, value in if value == .active { model.createLiveActivity() } }
        }
    }
}
