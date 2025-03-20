//
//  RFDateFormatter.swift
//  AlgoLogger
//
//  Created by Rouddy on 3/18/25.
//

import Foundation

class RFDateFormatter: DateFormatter {
    
    static let formatter = RFDateFormatter()
    
    override init() {
        super.init()
        dateFormat = "yyyy-MM-dd-HH-mm-ss"
        timeZone = TimeZone(abbreviation: "UTC")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        dateFormat = "yyyy-MM-dd-HH-mm-ss"
        timeZone = TimeZone(abbreviation: "UTC")
    }
}
