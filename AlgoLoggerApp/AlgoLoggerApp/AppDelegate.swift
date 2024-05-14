//
//  AppDelegate.swift
//  AlgoLoggerApp
//
//  Created by Jaehong Yoo on 2023/02/23.
//

import UIKit
import XCGLogger
import AlgoLogger
import AWSS3
import RxSwift

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static let accessKey = ""
    static let secretKey = ""
    static let identityPoolId = ""
    static let region = AWSRegionType.APNortheast2


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        LogManager.singleton.initTags(TestTag, TestTag.TestTag2, TestTag.TestTag2.TestTag3, TestTag.TestTag4)
        let osLoggingDestination = OsLoggingDestination(outputLevel: .verbose)
        _ = osLoggingDestination.addTo(tag: TestTag)
        
//        let consoleDestination = ConsoleDestination()
//        consoleDestination.outputLevel = .verbose
//        _ = consoleDestination.addTo(tag: TestTag)
        
        if let rotatingFileDestination = try? RotatingFileDestination(relativePath: "log/native.log", identifier: "RotatingFileDestination", shouldAppend: true, maxFileSize: 100) {
            _ = rotatingFileDestination.addTo(tag: TestTag)
        }
        
        let cloudWatchDestination = CloudWatchDestination(
            logGroupName: "/test/algorigo_logger_ios_native",
            logStreamName: "device_id",
            identityPoolId: AppDelegate.identityPoolId,
            region: AppDelegate.region,
            outputLevel: .info,
            logGroupRetentionDays: .day_1
        )
        _ = cloudWatchDestination.addTo(tag: TestTag)
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
