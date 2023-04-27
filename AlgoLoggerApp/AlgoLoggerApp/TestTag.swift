//
//  TestTag.swift
//  AlgoLoggerApp
//
//  Created by Rouddy on 2/20/24.
//

import Foundation
import AlgoLogger

let TestTag = _TestTag()
class _TestTag: Tag {
    let TestTag2 = _TestTag2()
    let TestTag4 = _TestTag4()
}
class _TestTag2: Tag {
    let TestTag3 = _TestTag3()
    
    required init() {
        super.init(parent: _TestTag.self)
    }
}
class _TestTag3: Tag {
    required init() {
        super.init(parent: _TestTag2.self)
    }
}
class _TestTag4: Tag {
    required init() {
        super.init(parent: _TestTag.self)
    }
}
