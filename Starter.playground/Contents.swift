import Foundation
import Combine

var subscriptions = Set<AnyCancellable>()

example(of: "Publisher") {
  // 1
  let myNotification = Notification.Name("MyNotification")

  // 2
  let publisher = NotificationCenter.default
    .publisher(for: myNotification, object: nil)
    
    let center = NotificationCenter.default
    
    // 4
    let observer = center.addObserver(
        forName: myNotification,
        object: nil,
        queue: nil) { notification in
            print("Notification received!")
    }
    
    // 5
    center.post(name: myNotification, object: nil)
    
    // 6
    center.removeObserver(observer)
}

example(of: "Subscriber") {
  let myNotification = Notification.Name("MyNotification")

  let publisher = NotificationCenter.default
    .publisher(for: myNotification, object: nil)

  let center = NotificationCenter.default
    
    // 1 Create a subscription by calling sink on a publisher
    let subscription = publisher
      .sink { _ in
        print("Notification received from a publisher!")
      }

    // 2
    center.post(name: myNotification, object: nil)
    // 3 You are able to cancel() the subscription because it inherits froms Cancellable.
    subscription.cancel()
}


example(of: "Just") {
  // 1 New way to Create a Publisher with a primitive value type. NO need to use Notification center.
    //JUST is a publisher that emits an output to each subscriber just once, and then finishes.
  let just = Just("Hello world!")
  
  // 2 Create a subscription to the publisher
  _ = just
    .sink(
      receiveCompletion: {
        print("Received completion", $0)
      },
      receiveValue: {
        print("Received value", $0)
    })
    
    _ = just
      .sink(
        receiveCompletion: {
          print("Received completion (another)", $0)
        },
        receiveValue: {
          print("Received value (another)", $0)
      })
}

example(of: "assign(to:on:)") {
  // 1
  class SomeObject {
    var value: String = "" {
      didSet {
        print(value)
      }
    }
  }
  
  // 2
  let object = SomeObject()
  
  // 3 Create a publisher from an array of strings
  let publisher = ["Hello", "world!"].publisher
  
  // 4 Subscribe to a publisher and assign each value received to the value property of the object.
  _ = publisher
    .assign(to: \.value, on: object)
}

example(of: "Custom Subscriber") {
  // 1 Create publisher of integeres
  let publisher = (1...6).publisher
  
  // 2 define a custom subscriber
  final class IntSubscriber: Subscriber {
    // 3
    typealias Input = Int //the subscriber receives Integers
    typealias Failure = Never //the subscriber will never receive errors

    // 4 here it is specified that it will receive up to three values from the publisher
    func receive(subscription: Subscription) {
      subscription.request(.max(3))
    }
    
    // 5 do something with the values received. .none indicates the subscriber will not adjust its demand.
    func receive(_ input: Int) -> Subscribers.Demand {
      print("Received value", input)
        return .none //can be .unlimited or .max(1) -> increase the max by 1
    }

    // 6 completion event.
    func receive(completion: Subscribers.Completion<Never>) {
      print("Received completion", completion)
    }
  }
    
  let subscriber = IntSubscriber()
    
  publisher.subscribe(subscriber)
}

example(of: "Future") {
    //"A Future can be used to asynchronously produce a single result and then complete.
    //The method bellow returns a Future that will emit an Int and Never fail.
    func futureIncrement(integer: Int, afterDelay delay: TimeInterval) -> Future<Int, Never> {
        Future<Int, Never> { promise in
          print("Original")
          DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            promise(.success(integer + 1))
          }
        }
    }

    // This line creates a Future (that means an Async Publisher) after three seconds delay.
    let future = futureIncrement(integer: 1, afterDelay: 3)
    // 2
    future//The sink -> subscribes to the Future publisher
      .sink(receiveCompletion: { print($0) }, // set up the completion closure
            receiveValue: { print($0) })// set up the receive values closure
      .store(in: &subscriptions) //Store the subscription in the Subscription set var subscriptions = Set<AnyCancellable>()

    future
      .sink(receiveCompletion: { print("Second", $0) },
            receiveValue: { print("Second", $0) })
      .store(in: &subscriptions)
}

example(of: "PassthroughSubject") {
    // 1 Define custom error type
    enum MyError: Error {
        case test
    }
    
    // 2 Define Custom Subscriber of input type String and error MyError.
    final class StringSubscriber: Subscriber {
        typealias Input = String
        typealias Failure = MyError
        
        //The subscriber can receive a max of two values
        func receive(subscription: Subscription) {
            subscription.request(.max(2))
        }
        
        //Adjust the demand based on the received value.
        //It will increment the max (previously set to two) plus 1. So, the total will be three.
        func receive(_ input: String) -> Subscribers.Demand {
            print("Received value", input)
            // 3
            return input == "World" ? .max(1) : .none
        }
        
        func receive(completion: Subscribers.Completion<MyError>) {
            print("Received completion", completion)
        }
    }
    
    // 4 Create an instance of the custom subscriber
    let subscriber = StringSubscriber()
    
    // 5 PasstrhoughSubject is a type of publisher. Enables you to publish values on demand
    let subject = PassthroughSubject<String, MyError>()

    // 6 Create a subscription to the publisher
    subject.subscribe(subscriber)

    // 7 Create another subscription using sink
    let subscription = subject
      .sink(
        receiveCompletion: { completion in
          print("Received completion (sink)", completion)
        },
        receiveValue: { value in
          print("Received value (sink)", value)
        }
      )
    
    //Pass values:
    subject.send("Hello")
    subject.send("World")
    
    // 8 Cancel second subscription
    subscription.cancel()
    // 9
    subject.send("Still there?")
    
    // If the completion is an error.. the publisher is also DONE.
    subject.send(completion: .failure(MyError.test))
    // The publisher is finished
    subject.send(completion: .finished)
    subject.send("How about another one?")
}

example(of: "CurrentValueSubject") {
  // 1 create a subscription set
  var subscriptions = Set<AnyCancellable>()
  
  // CurrentValueSubject is a type of publisher
  // that wraps a single value and publishes whenever the value changes. In this case it publish an initial value 0
  let subject = CurrentValueSubject<Int, Never>(0)
  
  // 3
  subject
    .print() // It will print the type of subscription, if unlimited and when canceled.
    .sink(receiveValue: { print($0) }) //Create a subscription to the subject
    .store(in: &subscriptions) // 4 store it inout parameter
    
    subject.send(1)
    subject.send(2)
    subject.value = 3 //Same as send()
//    subject.send(completion: .finished) finish the publisher
    subject
    .print()
      .sink(receiveValue: { print("Second subscription:", $0) }) //When the second subscription is created is immediately called
      .store(in: &subscriptions)
}

example(of: "Dynamically adjusting Demand") {
  final class IntSubscriber: Subscriber {
    typealias Input = Int
    typealias Failure = Never
    
    func receive(subscription: Subscription) {
      subscription.request(.max(2))
    }
    
    func receive(_ input: Int) -> Subscribers.Demand {
      print("Received value", input)
      
      switch input {
      case 1:
        return .max(2) // the new max is four
      case 3:
        return .max(1) // the new max if five
      default:
        return .none // wont add more values
      }
    }
    
    func receive(completion: Subscribers.Completion<Never>) {
      print("Received completion", completion)
    }
  }
  
  let subscriber = IntSubscriber()
  
  let subject = PassthroughSubject<Int, Never>()
  
  subject.subscribe(subscriber)
  
  subject.send(1)
  subject.send(2)
  subject.send(3)
  subject.send(4)
  subject.send(5)
  subject.send(6)
}

example(of: "Type erasure") {
    // 1
    let subject = PassthroughSubject<Int, Never>()
    
    //THIS TYPE of publisher allows you to hide
    //details about the publisher that you don't want to expose
    //to the subscribers
    let publisher = subject.eraseToAnyPublisher() //AnyPublisher <Int Never>
    //
    
    // 3
    publisher
        .sink(receiveValue: { print($0) })
        .store(in: &subscriptions)
    
    // 4
    subject.send(0)
}

// DIFF BTWN ANYCANCELLABLE AND ANYPUBLISHER
// AnyCancellable -> allows callers cancel the subscription
// without knowing the underlying subscription

// AnyPublisher -> let outside callers only access the public
// publisher for subscribing but not be able to send values.

/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.
