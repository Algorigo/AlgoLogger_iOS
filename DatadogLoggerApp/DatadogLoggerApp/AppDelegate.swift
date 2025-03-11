//
//  AppDelegate.swift
//  DatadogLoggerApp
//
//  Created by Rouddy on 3/11/25.
//

import UIKit
import AlgoLogger
import DatadogLogs
import DatadogInternal

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let dataDogLogDelegate = DataDogLogDelegate(clientToken: "", env: "dev", service: "log_test_ios", verbosityLevel: .debug, remoteLogThreshold: .info)
        dataDogLogDelegate.addDDTag("tagName", "tagValue")
        dataDogLogDelegate.addAttribute("attributeName", "attributeValue")
        LogManager.singleton.addDelegate(dataDogLogDelegate)
        LogManager.singleton.initTags(TestTag, TestTag.TestTag2, TestTag.TestTag2.TestTag3, TestTag.TestTag4)
        
        if let dataDogDestination = try? DataDogDestination(outputLevel: .verbose) {
            _ = dataDogDestination.addTo(tag: TestTag)
        }
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

