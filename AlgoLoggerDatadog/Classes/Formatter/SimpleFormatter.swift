//
//  SimpleFormatter.swift
//  AlgoLogger
//
//  Created by Rouddy on 3/11/25.
//

import Foundation
import XCGLogger

class SimpleFormatter: LogFormatterProtocol, CustomDebugStringConvertible {
    
    var debugDescription: String {
        get {
            var description: String = "\(self)"
            for level in XCGLogger.Level.allCases {
                description += ": \n\t- \(level)"
            }
            return description
        }
    }
    
    func format(logDetails: inout LogDetails, message: inout String) -> String {
        message = "\(logDetails.message) "
        + (logDetails.fileName.isEmpty ? "" : "(\(URL(string: logDetails.fileName)!.lastPathComponent ):\(logDetails.lineNumber))")
        return message
    }
}
