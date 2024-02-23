//
//  JSAGLogger.swift
//  algo_platform_jsag
//
//  Created by Jaehong Yoo on 2023/02/16.
//

import Foundation
import XCGLogger

public class LogManager {
    
    fileprivate static let instance = LogManager()
    
    public static var singleton: LogManager {
        return instance
    }
    
    fileprivate var loggerDict = [Tag: XCGLogger]()
    
    public func initTags(_ tags: Tag...) {
        for tag in tags {
            _ = getLogger(tag)
        }
    }
    
    public func getLogger(_ tag: Tag) -> XCGLogger {
        return loggerDict[tag.topParent] ?? initLogger(tag)
    }
    
    fileprivate func initLogger(_ tag: Tag) -> XCGLogger {
        let logger = XCGLogger(identifier: tag.topParent.name, includeDefaultDestinations: false)
        loggerDict[tag] = logger
        return logger
    }
    
//    public func setupFileLogger(level: XCGLogger.Level = .info) {
//        let logDirectoryUrl = LogManager.getPathUrl(relativePath: LogManager.logDirectory)
//        if !FileManager.default.fileExists(atPath: logDirectoryUrl.path) {
//            do {
//                try FileManager.default.createDirectory(atPath: logDirectoryUrl.path, withIntermediateDirectories: true)
//            } catch {
//                print("error:\(error)")
//            }
//        }
//        let logFileUrl = LogManager.getLogFileUrl()
//        print("logFileUrl:\(logFileUrl)")
//        let autoRotatingFileDestination = AutoRotatingFileDestination(writeToFile: logFileUrl, targetMaxLogFiles: 3)
//        autoRotatingFileDestination.outputLevel = level
//        logger.add(destination: autoRotatingFileDestination)
//    }
//    
//    public func getLoggerFiles() -> [String] {
//        let logDirectoryUrl = LogManager.getPathUrl(relativePath: LogManager.logDirectory)
//        print("logPath:\(logDirectoryUrl)")
//        do {
//            return (try FileManager.default.contentsOfDirectory(atPath: logDirectoryUrl.path))
//                .map { logDirectoryUrl.appendingPathComponent($0).path }
//        } catch {
//            print("error:\(error)")
//            return []
//        }
//    }
}

extension DestinationProtocol {
    public func addTo(tag: Tag) -> Bool {
        return LogManager.singleton.getLogger(tag).add(destination: self)
    }
}
