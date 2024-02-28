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
}

extension DestinationProtocol {
    public func addTo(tag: Tag) -> Bool {
        return LogManager.singleton.getLogger(tag).add(destination: self)
    }
}
