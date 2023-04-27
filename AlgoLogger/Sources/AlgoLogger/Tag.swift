//
//  File.swift
//  
//
//  Created by Rouddy on 2/20/24.
//

import Foundation

open class Tag {
    
    fileprivate let parent: Tag.Type?
    
    var topParent: Tag {
        return parent?.init().topParent ?? self
    }
    
    public required init() {
        parent = nil
    }
    
    public init<T: Tag>(parent: T.Type) {
        self.parent = parent
    }
    
    public var name: String {
        if let parent = parent {
            return parent.init().name + "." + getSingleName()
        } else {
            return getSingleName()
        }
    }
    
    fileprivate func getSingleName() -> String {
        return String(String(describing: self).split(separator: ".").last!).replacingOccurrences(of: "_", with: "")
    }
}

extension Tag: Hashable {
    public static func == (lhs: Tag, rhs: Tag) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
