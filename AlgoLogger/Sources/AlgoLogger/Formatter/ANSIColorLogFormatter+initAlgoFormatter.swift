//
//  File.swift
//  
//
//  Created by Rouddy on 2/21/24.
//

import Foundation
import XCGLogger

public extension ANSIColorLogFormatter {
    static func initAlgoFormatter() -> ANSIColorLogFormatter {
        let ansiColorLogFormatter: ANSIColorLogFormatter = ANSIColorLogFormatter()
        ansiColorLogFormatter.colorize(level: .verbose, with: .colorIndex(number: 244), options: [.faint])
        ansiColorLogFormatter.colorize(level: .debug, with: .black)
        ansiColorLogFormatter.colorize(level: .info, with: .blue, options: [.underline])
        ansiColorLogFormatter.colorize(level: .notice, with: .green, options: [.italic])
        ansiColorLogFormatter.colorize(level: .warning, with: .red, options: [.faint])
        ansiColorLogFormatter.colorize(level: .error, with: .red, options: [.bold])
        ansiColorLogFormatter.colorize(level: .severe, with: .white, on: .red)
        ansiColorLogFormatter.colorize(level: .alert, with: .white, on: .red, options: [.bold])
        ansiColorLogFormatter.colorize(level: .emergency, with: .white, on: .red, options: [.bold, .blink])
        return ansiColorLogFormatter
    }
}
