import UIKit
import Google
import GoogleSignIn
//import SideMenu

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
//        var configureError: NSError?
//        GGLContext.sharedInstance().configureWithError(&configureError)
//        assert(configureError == nil, "Error configuring Google services: \(configureError!)")
        
        let _ = DBManager.instance
        let db = DBManager.instance
        db.fetchUsers { (users) in
            print("We read users: \(users)")
        }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        let source = options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String
        let annotaton = options[UIApplicationOpenURLOptionsKey.annotation]
        
        return GIDSignIn.sharedInstance().handle(url, sourceApplication: source, annotation: annotaton)
    }

}

