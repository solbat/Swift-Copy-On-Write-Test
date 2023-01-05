## 일반적으로 Copy-On-Write(COW)란?

- 말 그대로 작성 시 이전의 내용을 Copy 한다는 의미
- 언제 발생하는가?
    - Linux(UNIX)에서는 자식 프로세스(child process)를 생성(fork)하면 같은 메모리 공간을 공유하게 됨
    
    ![https://openwiki.kr/_media/tech/copy-on-write-234731.png?cache=&w=660&h=435&tok=f02374](https://openwiki.kr/_media/tech/copy-on-write-234731.png?cache=&w=660&h=435&tok=f02374)
    
    - 그런데 부모 프로세스가 데이터를 새로 넣거나, 수정하거나, 지우게 되면 같은 메모리 공간을 공유할 수 없게 됨
    - 이때 부모 프로세스는 해당 페이지를 복사한 다음 수정함
    
    ![https://openwiki.kr/_media/tech/copy-on-write-234748.png?cache=&w=656&h=442&tok=9d5a9f](https://openwiki.kr/_media/tech/copy-on-write-234748.png?cache=&w=656&h=442&tok=9d5a9f)
    
    - 이를 Copy-On-Write(COW)라고 한다!
- 만약 자식 프로세스가 없었다면?
    - 페이지를 복사하지 않고 바로 수정하였을 것임
    - 자식 프로세스가 생성되어 작업을 하는동안 데이터 입력/수정/삭제가 발생하면 해당 메모리 페이지를 복사해야 되기 때문에 평소보다 더 많은 메모리가 필요해짐

## Swift Copy-On-Write

### Value Type

- 선언할 때 사용한 `let`/`var` 이외에는 참조할 수 없는 type
- 새로운 `let`/`var`에 대입되면 복사됨
- 함수나 메소드의 인자로 넘어가거나 return되면 복사됨
- 사본을 수정해도 원본에는 영향이 없음
- 그렇다면 매번 복사할까?
    - 아니! 논리적으로는 copy이지만 reference처럼 동작함
    - 따라서 성능에 큰 영향 없음!
    - 이를 Copy on Write이라고 함

<aside>
💡 **Copy on Write**
: 성능 상의 이유로 내용물을 매번 복사하는 것이 아니라 컴파일러가 복사본의 변경 유무를 판단하여 기존의 값을 재사용할지 새로 만들지 판단하게 됨

</aside>

## Swift Copy-On-Write 실험

### Code

```swift
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
```

### Output

> **실험1: struct**
> 
> 
> **BEFORE**
> 
> **address of a1: 0x10000c1c0**
> 
> **address of a2: 0x10000c1c8**
> 
> **AFTER**
> 
> **address of a1: 0x10000c1c0**
> 
> **address of a2: 0x10000c1c8**
> 
> **실험2: Array**
> 
> **BEFORE**
> 
> **address of a3: 0x60000170c0e0**
> 
> **address of a4: 0x60000170c0e0**
> 
> **AFTER**
> 
> **address of a3: 0x60000170c0e0**
> 
> **address of a4: 0x600002608020**
> 

### 설명

- value type은 선언할 때 사용한 `let`/`var` 이외에는 참조할 수 없으므로 새로운 `let`/`var`에 대입되면 값이 복사됨
- 그러나 매번 값이 복사될 경우 메모리 낭비가 발생하므로 Copy-On-Write 기법이 적용됨
- Swift에서 가장 대표적인 value type인 struct와 Array에 대해 진행한 실험

### 결과

- struct : COW이 수행되지 않고 참조 시 값을 복사
- Array : COW이 수행되었음
- 같은 value type인데 COW가 수행되는 경우가 다르다?!
    
    → 찾아보니 Swift에서 COW는 Collection 타입(Array, Dictionary, Set 등)에서만 사용할 수 있음
    

## Swift Custom Copy-On-Write 구현

### Code

```swift
import Foundation

struct CopyOnWriteTest {
    var count: Int = 5
}

func address(_ object: UnsafeRawPointer) -> String {
    let address = Int(bitPattern: object)
    return NSString(format: "%p", address) as String
}

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
```

### Output

> **실험3: custom COW 구현**
> 
> 
> **BEFORE**
> 
> **address of a5: 0x600000209030**
> 
> **address of a6: 0x600000209030**
> 
> **AFTER**
> 
> **address of a5: 0x600000209030**
> 
> **address of a6: 0x600000209050**
> 

### 설명

- value type이더라도 컴파일러의 판단 하에 COW가 수행되지 않는 경우가 있음
- 기본적으로 Swift에서는 Collection 타입(Array, Dictionary, Set 등)에서만 COW가 사용됨
- 따라서 struct에서도 적용할 수 있는 custom COW를 구현

### 결과

- 대표적인 value type인 struct에서도 custom COW가 수행되었음

## Swift Copy-On-Write 시간 측정

### Code

```swift
import Foundation

func address(_ object: UnsafeRawPointer) -> String {
    let address = Int(bitPattern: object)
    return NSString(format: "%p", address) as String
}

// 실험4: COW 시간 측정
func measureTime(_ closure: () -> ()) -> Double {
    let startTime = DispatchTime.now()
    closure()
    let endTime = DispatchTime.now()
    let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
    let timeInterval = Double(nanoTime) / 1_000_000_000
    return timeInterval
}

var a7 = [8, 9, 10, 11]
var a8 = a7

print("\n실험4: COW 시간 측정")
print("BEFORE")
print("address of a7: \(address(of: &a7))")
print("address of a8: \(address(of: &a8))")
print("첫 번째 수정")
print(
    measureTime {
        a8.append(12)
    }
)
print("두 번째 수정")
print(
    measureTime {
        a8.append(13)
    }
)
print("세 번째 수정")
print(
    measureTime {
        a8.append(14)
    }
)
print("AFTER")
print("address of a7: \(address(of: &a7))")
print("address of a8: \(address(of: &a8))")
```

### Output

> **실험4: COW 시간 측정**
> 
> 
> **BEFORE**
> 
> **address of a7: 0x6000017083a0**
> 
> **address of a8: 0x6000017083a0**
> 
> **첫 번째 수정**
> 
> **1.053e-06**
> 
> **두 번째 수정**
> 
> **2.59e-07**
> 
> **세 번째 수정**
> 
> **1.99e-07**
> 
> **AFTER**
> 
> **address of a7: 0x6000017083a0**
> 
> **address of a8: 0x600002608080**
> 

### 설명

- 다음은 Copy-on-write에 대한 위키피디아 설명
    
    > Copy-on-write (COW), sometimes referred to as implicit sharing[1] or shadowing,[2] is a resource-management technique used in computer programming to efficiently implement a "duplicate" or "copy" operation on modifiable resources.[3] If a resource is duplicated but not modified, it is not necessary to create a new resource; the resource can be shared between the copy and the original. Modifications must still create a copy, hence the technique: the copy operation is deferred until the first write. By sharing resources in this way, it is possible to significantly reduce the resource consumption of unmodified copies, while adding a small overhead to resource-modifying operations.
    > 
- 마지막 문장 **while adding a small overhead to resource-modifying operation**과 같이 COW가 수행될 때 오버헤드가 발생함
- 따라서 COW 수행 시 시간을 측정하는 실험을 진행

### 결과

- COW가 적용되는 Array에 대하여 첫 번째 수정은 1.053e-06, 두 번째 수정은 2.59e-07, 세 번째 수정은 1.99e-07초가 소요됨
- COW가 수행 시 그렇지 않은 것과 비교하여 약 5배의 오버헤드가 발생함을 직접 확인할 수 있음
