//
//  main.swift
//  CopyOnWriteTest
//
//  Created by 김민중 on 2022/12/27.
//

import Foundation

struct CopyOnWriteTest {
    var count: Int = 5
}

func address(_ object: UnsafeRawPointer) -> String {
    let address = Int(bitPattern: object)
    return NSString(format: "%p", address) as String
}

// 실험1: struct
var a1 = CopyOnWriteTest()
var a2 = a1

print("\n실험1: struct")
print("BEFORE")
print("address of a1: \(address(&a1))")
print("address of a2: \(address(&a2))")
a2.count = 10
print("AFTER")
print("address of a1: \(address(&a1))")
print("address of a2: \(address(&a2))")

// 실험2: Array
var a3 = [3, 4, 5, 6]
var a4 = a3

print("\n실험2: Array")
print("BEFORE")
print("address of a3: \(address(&a3))")
print("address of a4: \(address(&a4))")
a4.append(0)
print("AFTER")
print("address of a3: \(address(&a3))")
print("address of a4: \(address(&a4))")

// 실험3: custom COW 구현
final class Ref<T> {
    var val: T
    init(_ val: T) {
        self.val = val
    }
}

struct Box<T> {
    var ref: Ref<T>
    init(_ ref: T) {
        self.ref = Ref(ref)
    }
    
    var value: T {
        get { return ref.val}
        set {
            if !isKnownUniquelyReferenced(&ref) {
                ref = Ref(newValue)
                return
            }
            ref.val = newValue
        }
    }
}

var a5 = Box(CopyOnWriteTest())
var a6 = a5

print("\n실험3: custom COW 구현")
print("BEFORE")
print("address of a5: \(address(&a5.ref.val))")
print("address of a6: \(address(&a6.ref.val))")
a6.value.count = 10
print("AFTER")
print("address of a5: \(address(&a5.ref.val))")
print("address of a6: \(address(&a6.ref.val))")
