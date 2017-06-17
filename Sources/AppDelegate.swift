//
//  AppDelegate.swift
//  Priorstats
//
//  Created by Roman Gardukevich on 6/4/17.
//  Copyright © 2017 Roman Gardukevich. All rights reserved.
//

import UIKit
import Google
import GoogleSignIn

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let _ = try! JSONDecoder().decode(Array<User>.self, from: data)
        var configureError: NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        assert(configureError == nil, "Error configuring Google services: \(configureError!)")
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        let source = options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String
        let annotaton = options[UIApplicationOpenURLOptionsKey.annotation]
        
        return GIDSignIn.sharedInstance().handle(url, sourceApplication: source, annotation: annotaton)
    }

}

