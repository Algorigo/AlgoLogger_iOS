//
//  File.swift
//
//
//  Created by Rouddy on 2/21/24.
//

import Foundation
import XCGLogger

class DefaultFormatter: LogFormatterProtocol, CustomDebugStringConvertible {
    
    fileprivate let formatter = DateFormatter()
    
    var debugDescription: String {
        get {
            var description: String = "\(self)"
            for level in XCGLogger.Level.allCases {
                description += ": \n\t- \(level)"
            }
            return description
        }
    }
    
    init() {
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    func format(logDetails: inout LogDetails, message: inout String) -> String {
        message = "\(formatter.string(for: logDetails.date) ?? String(describing: logDetails.date)) "
        + "[\(logDetails.level.description):\(logDetails.userInfo["tag"] ?? "")] "
        + "\(logDetails.message) "
        + "(\(URL(string: logDetails.fileName)!.lastPathComponent):\(logDetails.lineNumber))"
        if let error = logDetails.userInfo["error"] as? Error {
            message += "\n### \(error.localizedDescription)\n"
        }
        return message
    }
}
