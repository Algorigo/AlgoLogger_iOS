//
//  DataDogDestination.swift
//  AlgoLogger
//
//  Created by Rouddy on 3/11/25.
//

import Foundation
import XCGLogger
import DatadogCore
import DatadogLogs

public class DataDogDestination: BaseDestination {
    
    fileprivate let dataDogLogDelegate: DataDogLogDelegate!
    
    public init(owner: XCGLogger? = nil, formatter: LogFormatterProtocol? = nil, outputLevel: XCGLogger.Level = .info, identifier: String = "") throws {
        if !Datadog.isInitialized() {
            throw NSError(domain: "DataDogDestination", code: 0, userInfo: [NSLocalizedDescriptionKey: "Datadog is not initialized"])
        }
        dataDogLogDelegate = LogManager.singleton.getDelegate(DataDogLogDelegate.self)
        
        super.init(owner: owner ?? LogManager.defaultLogger, identifier: identifier)
        if let formatter = formatter {
            self.formatters = [formatter, SimpleFormatter()]
        } else {
            self.formatters = [SimpleFormatter()]
        }
        self.outputLevel = outputLevel
    }
    
    public override func output(logDetails: LogDetails, message: String) {
        // Create mutable versions of our parameters
        var logDetails = logDetails
        var message = message
        
        // Apply filters, if any indicate we should drop the message, we abort before doing the actual logging
        guard !self.shouldExclude(logDetails: &logDetails, message: &message) else { return }
        
        self.applyFormatters(logDetails: &logDetails, message: &message)
        self.write(level: logDetails.level, tag: logDetails.userInfo[L.tag] as? String ?? "", message: message, date: logDetails.date, error: logDetails.userInfo[L.error] as? Error, callStackSymbols: logDetails.userInfo[L.stackTrace] as? String)
    }
    
    fileprivate func write(level: XCGLogger.Level, tag: String, message: String, date: Date, error: Error?, callStackSymbols: String?) {
        dataDogLogDelegate.getLogger(tag)?.log(level: level.toLogLevel(), message: message, error: error, attributes: ["date": date, "error.message": error?.localizedDescription, "error.stack": callStackSymbols])
    }
}

extension XCGLogger.Level {
    func toLogLevel() -> LogLevel {
        switch self {
        case .verbose:
            return .debug
        case .debug:
            return .debug
        case .info:
            return .info
        case .notice:
            return .notice
        case .warning:
            return .warn
        case .error:
            return .error
        case .severe: // aka critical
            return .critical
        case .alert:
            return .critical
        case .emergency:
            return .critical
        case .none:
            return .debug
        }
    }
}
