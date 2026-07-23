//
//  TONStreamingPublisher.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 31.03.2026.
//
//  Copyright (c) 2026 TON Connect
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation
import Combine

typealias TONStreamingWatch<Output> = (@escaping (Output) -> Void) throws -> (() -> Void)

struct TONStreamingPublisher<Output>: Publisher {
    typealias Output = Output
    typealias Failure = any Error
    
    private let watch: TONStreamingWatch<Output>
    
    init(watch: @escaping TONStreamingWatch<Output>) {
        self.watch = watch
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        let subscription = TONStreamingSubscription<Output>(
            subscriber: subscriber,
            watch: watch
        )
        subscriber.receive(subscription: subscription)
    }
}

final class TONStreamingSubscription<Output>: Subscription {
    private var sendValue: ((Output) -> Void)?
    private var sendCompletion: ((Subscribers.Completion<any Error>) -> Void)?
    private var unwatch: (() -> Void)?
    private let watch: TONStreamingWatch<Output>
    
    init<S: Subscriber>(
        subscriber: S,
        watch: @escaping TONStreamingWatch<Output>
    ) where S.Input == Output, S.Failure == any Error {
        self.sendValue = { _ = subscriber.receive($0) }
        self.sendCompletion = { subscriber.receive(completion: $0) }
        
        self.watch = watch
    }
    
    func request(_ demand: Subscribers.Demand) {
        guard unwatch == nil else { return }
        
        do {
            unwatch = try watch { [weak self] value in
                self?.sendValue?(value)
            }
        } catch {
            sendCompletion?(.failure(error))
            sendCompletion = nil
            sendValue = nil
        }
    }
    
    func cancel() {
        unwatch?()
        unwatch = nil
        sendValue = nil
        sendCompletion = nil
    }
}

