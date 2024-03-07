//
//  File.swift
//  
//
//  Created by Jaehong Yoo on 2023/02/24.
//

import Foundation
import XCGLogger
import OSLog

public class OsLoggingDestination : AlgorigoLoggingDestination {
    
    public override init(owner: XCGLogger? = nil, formatter: LogFormatterProtocol? = nil, outputLevel: XCGLogger.Level = .debug, identifier: String = String(describing: OsLoggingDestination.self)) {
        super.init(owner: owner, formatter: formatter, outputLevel: outputLevel, identifier: identifier)
    }
    
    public override func write(level: XCGLogger.Level, message: String, date: Date) {
        switch level {
        case .verbose:
            os_log("%@", type: .debug, message)
        case .debug:
            os_log("%@", type: .debug, message)
        case .info:
            os_log("%@", type: .info, message)
        case .notice:
            os_log("%@", type: .info, message)
        case .warning:
            os_log("%@", type: .info, message)
        case .error:
            os_log("%@", type: .error, message)
        case .emergency:
            os_log("%@", type: .error, message)
            // AlgoLogger 이외의 Logger에서 log 시
        case .severe:
            os_log("%@", type: .error, message)
        case .alert:
            os_log("%@", type: .error, message)
        case .none:
            break
        }
    }
}
