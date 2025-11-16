import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Create window
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Set up root view controller
        let contentViewController = ContentViewController()
        window?.rootViewController = contentViewController
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Pause AR session when app becomes inactive
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Clean up resources when app enters background
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Prepare to resume AR session
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Resume AR session when app becomes active
    }
}