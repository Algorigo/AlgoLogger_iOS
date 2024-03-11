//
//  File.swift
//  
//
//  Created by Rouddy on 3/6/24.
//

import Foundation

fileprivate protocol RegexProtocol {
    func firstMatches(_ input: String) -> [String]
}

@available(iOS 16.0, *)
fileprivate class RegexiOSOver16: RegexProtocol {
    fileprivate let regex: Regex<AnyRegexOutput>!
    
    init(_ pattern: String) {
        regex = try! Regex(pattern)
    }
    
    func firstMatches(_ input: String) -> [String] {
        if let matches = try? regex.firstMatch(in: input) {
            var result = [String]()
            for index in 1..<matches.count {
                result.append(String(matches[index].value as! Substring))
            }
            return result
        } else {
            return []
        }
    }
}

fileprivate class RegexiOSBelow15: RegexProtocol {
    fileprivate let regex: NSRegularExpression!
    
    init(_ pattern: String) {
        regex = try! NSRegularExpression(pattern: pattern, options: [])
    }
    
    func firstMatches(_ input: String) -> [String] {
        if let matches = regex.firstMatch(in: input, options: [], range: NSRange(location: 0, length: input.count)) {
            var result = [String]()
            for index in 1..<matches.numberOfRanges {
                let range = Range(matches.range(at: index), in: input)!
                result.append(String(input[range]))
            }
            return result
        } else {
            return []
        }
    }
}

public class KeyFormatter: DateFormatter {
    
    fileprivate var formats: [DateFormatter]!
    fileprivate var normalStrings: [String]!
    fileprivate var regexProtocol: RegexProtocol!
    fileprivate var dateOnlyFormat: DateFormatter!
    
    public override var dateFormat: String! {
        get {
            return super.dateFormat
        }
        set {
            super.dateFormat = newValue
            setPattern(newValue)
        }
    }
    
    public init(pattern: String) {
        super.init()
        setPattern(pattern)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    fileprivate func setPattern(_ pattern: String) {
        let split = pattern.split(separator: "@")
        let enumerated = split.enumerated()
        let formatStrings = enumerated.filter { index, string in
            index % 2 == 1
        }.map { _, string in
            String(string)
        }
        formats = formatStrings.map { string in
            let formatter = DateFormatter()
            formatter.dateFormat = String(string)
            return formatter
        }
        normalStrings = enumerated.filter { index, string in
            index % 2 == 0
        }.map { _, string in
            String(string)
        }
        if #available(iOS 16.0, *) {
            regexProtocol = RegexiOSOver16("^" + normalStrings.joined(separator: "(.*)") + "$")
        } else {
            regexProtocol = RegexiOSBelow15("^" + normalStrings.joined(separator: "(.*)") + "$")
        }
        dateOnlyFormat = DateFormatter()
        dateOnlyFormat.dateFormat = formatStrings.joined(separator: "")
    }
    
    public override func string(from date: Date) -> String {
        var buffer = ""
        for index in formats.indices {
            buffer += normalStrings[index]
            buffer += formats[index].string(from: date)
        }
        buffer += normalStrings.last!
        return buffer
    }
    
    public override func date(from string: String) -> Date? {
        let matches = regexProtocol.firstMatches(string)
        return dateOnlyFormat.date(from: matches.joined(separator: ""))
    }
}
