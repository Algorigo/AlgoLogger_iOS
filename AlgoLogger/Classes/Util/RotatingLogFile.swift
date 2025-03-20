//
//  LogFile.swift
//  AlgoLogger
//
//  Created by Rouddy on 3/18/25.
//

import Foundation

public struct RatatingLogFile {
    let basePrefix: String
    let baseExtention: String
    public let rotatedDate: Date
    public let postfix: String
    
    public var path: String {
        "\(basePrefix)\(RFDateFormatter.formatter.string(from: rotatedDate))\(postfix)\(baseExtention)"
    }
    
    private init(basePrefix: String, baseExtention: String, rotatedDate: Date, postfix: String) {
        self.basePrefix = basePrefix
        self.baseExtention = baseExtention
        self.rotatedDate = rotatedDate
        self.postfix = postfix
    }
    
    init(base: String, rotatedDate: Date = Date(), postfix: String = "") {
        if let lastDot = base.lastIndex(of: ".") {
            self.basePrefix = String(base[..<lastDot])
            self.baseExtention = String(base[lastDot...])
        } else {
            self.basePrefix = base
            self.baseExtention = ""
        }
        self.rotatedDate = rotatedDate
        self.postfix = postfix
    }
    
    init?(url: URL) {
        let rotatedDateString: String
        if #available(iOS 16.0, *) {
            let fullPath = url.path(percentEncoded: true)
            guard let regex = try? Regex("^(.*)([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2})(.*)$") else {
                return nil
            }
            guard let match = try? regex.firstMatch(in: fullPath) else {
                return nil
            }
            guard let match1 = match[1].value as? Substring else {
                return nil
            }
            guard let match2 = match[2].value as? Substring else {
                return nil
            }
            guard let match3 = match[3].value as? Substring else {
                return nil
            }
            self.basePrefix = String(match1)
            rotatedDateString = String(match2)
            let postfixAndExtention = String(match3)
            if let lastDot = postfixAndExtention.lastIndex(of: ".") {
                self.postfix = String(postfixAndExtention[..<lastDot])
                self.baseExtention = String(postfixAndExtention[lastDot...])
            } else {
                self.postfix = postfixAndExtention
                self.baseExtention = ""
            }
        } else {
            let fullPath = url.path
            guard let regex = try? NSRegularExpression(pattern: "^(.*)([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2})(.*)$", options: []) else {
                return nil
            }
            guard let match = regex.firstMatch(in: fullPath, options: [], range: NSRange(location: 0, length: fullPath.count)) else {
                return nil
            }
            guard let range1 = Range(match.range(at: 1), in: fullPath) else {
                return nil
            }
            guard let range2 = Range(match.range(at: 2), in: fullPath) else {
                return nil
            }
            guard let range3 = Range(match.range(at: 3), in: fullPath) else {
                return nil
            }
            self.basePrefix = String(fullPath[range1])
            rotatedDateString = String(fullPath[range2])
            let postfixAndExtention = String(fullPath[range3])
            if let lastDot = postfixAndExtention.lastIndex(of: ".") {
                self.postfix = String(postfixAndExtention[..<lastDot])
                self.baseExtention = String(postfixAndExtention[lastDot...])
            } else {
                self.postfix = postfixAndExtention
                self.baseExtention = ""
            }
        }
        guard let rotatedDate = RFDateFormatter.formatter.date(from: rotatedDateString) else {
            return nil
        }
        self.rotatedDate = rotatedDate
    }

    func withPostfix(postfix: String) -> RatatingLogFile {
        return RatatingLogFile(basePrefix: basePrefix, baseExtention: baseExtention, rotatedDate: rotatedDate, postfix: postfix)
    }
}
