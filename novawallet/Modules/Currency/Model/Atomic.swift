//
//  Atomic.swift
//  novawallet
//
//  Created by Holyberry on 05.08.2022.
//  Copyright © 2022 Nova Foundation. All rights reserved.
//

import Foundation

@propertyWrapper
struct Atomic<Value> where Value: Initiable {
    private let lock = NSLock()
    private var value: Value

    init(defaultValue: Value) {
        value = defaultValue
    }

    var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }
}
