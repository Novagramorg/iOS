//
//  JSTimerPolyfill.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 11.09.2025.
//
//  Copyright (c) 2025 TON Connect
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
import JavaScriptCore

@objc
public protocol JSTimerManager: JSExport {
    
    @objc(setTimeout:::) func setTimeout(callback: JSValue, interval: Double, parameters: [Any]) -> Int32
    @objc(clearTimeout:) func clearTimeout(identifier: Int32)
    @objc(setInterval:::) func setInterval(callback: JSValue, interval: Double, parameters: [Any]) -> Int32
    @objc(clearInterval:) func clearInterval(identifier: Int32)
}

class JSTimerIdentifierProvider {
    private var lastID: Int32 = 0
    
    func nextTimerIdentifier() -> Int32 {
        let id = lastID
        lastID = lastID &+ 1
        return id
    }
}

public class JSTimerPolyfill: NSObject, JSPolyfill, JSTimerManager {
    private var timers: [Int32: DispatchSourceTimer] = [:]
    private let timersQueue = DispatchQueue(label: "com.jstimers.queue")
    private let callbackQueue = DispatchQueue(label: "com.jstimers.callbacks")
    private let timerIdentifierProvider = JSTimerIdentifierProvider()

    public func apply(to context: JSContext) {
        context.setObject(self,
                          forKeyedSubscript: "__nativeTimersManager" as NSString)

        context.evaluateScript(
            """
            function setTimeout(callback, interval, ...parameters) {
                return __nativeTimersManager.setTimeout(callback, interval, parameters);
            }

            function clearTimeout(identifier) {
                __nativeTimersManager.clearTimeout(identifier);
            }

            function setInterval(callback, interval) {
                return __nativeTimersManager.setInterval(callback, interval);
            }

            function clearInterval(identifier) {
                __nativeTimersManager.clearInterval(identifier);
            }
            """
        )
    }

    @objc
    public func setTimeout(callback: JSValue, interval: Double, parameters: [Any]) -> Int32 {
        guard callback.isObject && callback.isFunction else {
            return -1
        }

        let identifier = timersQueue.sync { timerIdentifierProvider.nextTimerIdentifier() }
        let function = JSManagedValue(value: callback, andOwner: callback.context)

        let timer = DispatchSource.makeTimerSource(queue: callbackQueue)
        timer.schedule(deadline: .now() + max(0.0, interval) / 1000.0)
        timer.setEventHandler { [weak self] in
            function?.value?.call(withArguments: parameters)
            self?.removeTimer(for: identifier)
        }

        timersQueue.sync { timers[identifier] = timer }
        timer.resume()

        return identifier
    }

    @objc
    public func clearTimeout(identifier: Int32) {
        let timer: DispatchSourceTimer? = timersQueue.sync {
            timers.removeValue(forKey: identifier)
        }
        timer?.cancel()
    }

    @objc
    public func setInterval(callback: JSValue, interval: Double, parameters: [Any]) -> Int32 {
        guard callback.isObject && callback.isFunction else {
            return -1
        }

        let identifier = timersQueue.sync { self.timerIdentifierProvider.nextTimerIdentifier() }
        let function = JSManagedValue(value: callback, andOwner: callback.context)

        let intervalSeconds = max(0.0, interval) / 1000.0
        let timer = DispatchSource.makeTimerSource(queue: callbackQueue)
        timer.schedule(deadline: .now() + intervalSeconds, repeating: intervalSeconds)
        timer.setEventHandler {
            function?.value?.call(withArguments: parameters)
        }

        timersQueue.sync { timers[identifier] = timer }
        timer.resume()

        return identifier
    }

    @objc
    public func clearInterval(identifier: Int32) {
        clearTimeout(identifier: identifier)
    }

    private func removeTimer(for identifier: Int32) {
        timersQueue.async { [weak self] in
            let timer = self?.timers.removeValue(forKey: identifier)
            timer?.cancel()
        }
    }
}
