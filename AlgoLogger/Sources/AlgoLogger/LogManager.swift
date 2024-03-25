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
    
    static let defaultLogger = XCGLogger(identifier: "AlgoLogger", includeDefaultDestinations: true)
    
    public static var singleton: LogManager {
        return instance
    }
    
    fileprivate var loggerDict = [String: XCGLogger]()
    
    public func initTags(_ tags: Tag...) {
        for tag in tags {
            _ = getLogger(tag)
        }
    }
    
    public func getLogger(_ tag: Tag) -> XCGLogger {
        return getLogger(tag.topParent.name)
    }
    
    public func getLogger(_ identifier: String) -> XCGLogger {
        return loggerDict[identifier] ?? initLogger(identifier)
    }
    
    fileprivate func initLogger(_ identifier: String) -> XCGLogger {
        let logger = XCGLogger(identifier: identifier, includeDefaultDestinations: false)
        loggerDict[identifier] = logger
        return logger
    }
}

extension DestinationProtocol {
    public func addTo(tag: Tag) -> Bool {
        return LogManager.singleton.getLogger(tag).add(destination: self)
    }
}
