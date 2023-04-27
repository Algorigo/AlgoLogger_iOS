//
//  File.swift
//  
//
//  Created by Rouddy on 2/21/24.
//

import Foundation
import XCGLogger

public class AlgorigoLoggingDestination : BaseDestination {
    
    public override var showDate: Bool {
        get {
            return false
        }
        set {}
    }
    public override var showLogIdentifier: Bool {
        get {
            return false
        }
        set {}
    }
    public override var showThreadName: Bool {
        get {
            return false
        }
        set {}
    }
    public override var showFunctionName: Bool {
        get {
            return false
        }
        set {}
    }
    
    fileprivate var logQueue: DispatchQueue? = nil
    
    public init(formatter: LogFormatterProtocol? = nil, outputLevel: XCGLogger.Level = .info) {
        super.init(owner: nil, identifier: String(describing: OsLoggingDestination.self))
        if let formatter = formatter {
            self.formatters = [formatter, DefaultFormatter()]
        } else {
            self.formatters = [DefaultFormatter()]
        }
        self.outputLevel = outputLevel
    }
    
    open override func output(logDetails: LogDetails, message: String) {
        let outputClosure = {
            // Create mutable versions of our parameters
            var logDetails = logDetails
            var message = message
            
            // Apply filters, if any indicate we should drop the message, we abort before doing the actual logging
            guard !self.shouldExclude(logDetails: &logDetails, message: &message) else { return }
            
            self.applyFormatters(logDetails: &logDetails, message: &message)
            self.write(level: logDetails.level, message: message)
        }
        
        if let logQueue = logQueue {
            logQueue.async(execute: outputClosure)
        }
        else {
            outputClosure()
        }
    }
    
    open func write(level: XCGLogger.Level, message: String) {
        fatalError("write(level:message:) must be overridden in the subclass")
    }
}
