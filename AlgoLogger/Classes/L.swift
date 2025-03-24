//
//  File.swift
//  
//
//  Created by Rouddy on 2/20/24.
//

import Foundation
import AlgoLoggerCommon

public class L {
    
    public static func verbose(_ tag: Tag, _ closure: @autoclosure () -> Any?, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line, userInfo: [String: Any] = [:], error: Error? = nil, callStackSymbols: [String]? = nil) {
        let userInfo = generateUserInfo(userInfo, tag, error, callStackSymbols)
        LogManager.singleton.getLogger(tag).logln(.verbose, functionName: functionName, fileName: fileName, lineNumber: lineNumber, userInfo: userInfo, closure: closure)
    }
    
    public static func debug(_ tag: Tag, _ closure: @autoclosure () -> Any?, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line, userInfo: [String: Any] = [:], error: Error? = nil, callStackSymbols: [String]? = nil) {
        let userInfo = generateUserInfo(userInfo, tag, error, callStackSymbols)
        LogManager.singleton.getLogger(tag).logln(.debug, functionName: functionName, fileName: fileName, lineNumber: lineNumber, userInfo: userInfo, closure: closure)
    }
    
    public static func info(_ tag: Tag, _ closure: @autoclosure () -> Any?, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line, userInfo: [String: Any] = [:], error: Error? = nil, callStackSymbols: [String]? = nil) {
        let userInfo = generateUserInfo(userInfo, tag, error, callStackSymbols)
        LogManager.singleton.getLogger(tag).logln(.info, functionName: functionName, fileName: fileName, lineNumber: lineNumber, userInfo: userInfo, closure: closure)
    }
    
    public static func notice(_ tag: Tag, _ closure: @autoclosure () -> Any?, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line, userInfo: [String: Any] = [:], error: Error? = nil, callStackSymbols: [String]? = nil) {
        let userInfo = generateUserInfo(userInfo, tag, error, callStackSymbols)
        LogManager.singleton.getLogger(tag).logln(.notice, functionName: functionName, fileName: fileName, lineNumber: lineNumber, userInfo: userInfo, closure: closure)
    }
    
    public static func warning(_ tag: Tag, _ closure: @autoclosure () -> Any?, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line, userInfo: [String: Any] = [:], error: Error? = nil, callStackSymbols: [String]? = nil) {
        let userInfo = generateUserInfo(userInfo, tag, error, callStackSymbols)
        LogManager.singleton.getLogger(tag).logln(.warning, functionName: functionName, fileName: fileName, lineNumber: lineNumber, userInfo: userInfo, closure: closure)
    }
    
    public static func error(_ tag: Tag, _ closure: @autoclosure () -> Any?, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line, userInfo: [String: Any] = [:], error: Error? = nil, callStackSymbols: [String]? = nil) {
        let userInfo = generateUserInfo(userInfo, tag, error, callStackSymbols)
        LogManager.singleton.getLogger(tag).logln(.error, functionName: functionName, fileName: fileName, lineNumber: lineNumber, userInfo: userInfo, closure: closure)
    }
    
    public static func assert(_ tag: Tag, _ closure: @autoclosure () -> Any?, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line, userInfo: [String: Any] = [:], error: Error? = nil, callStackSymbols: [String]? = nil) {
        let userInfo = generateUserInfo(userInfo, tag, error, callStackSymbols)
        LogManager.singleton.getLogger(tag).logln(.severe, functionName: functionName, fileName: fileName, lineNumber: lineNumber, userInfo: userInfo, closure: closure)
    }
    
    fileprivate static func generateUserInfo(_ userInfo: [String: Any], _ tag: Tag, _ error: Error? = nil, _ callStackSymbols: [String]? = nil) -> [String: Any] {
        var userInfo = userInfo
        userInfo[_Key.tagKey] = tag.name
        if let error = error {
            userInfo[_Key.errorKey] = error
        }
        if let callStackSymbols = callStackSymbols {
            userInfo[_Key.stackTraceKey] = callStackSymbols.joined(separator: "\n")
        }
        return userInfo
    }
}
