//
//  JSValue+Data.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 23.03.2026.
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

extension JSValue {
    
    var isUInt8Array: Bool {
        let uint8Constructor: JSValue? = context.Uint8Array
        
        if let uint8Constructor, self.isInstance(of: uint8Constructor) {
            return true
        }
        
        return false
    }
    
    var bytesNumber: Int {
        if self.isString {
            return self.toString()?.data(using: .utf8)?.count ?? 0
        }

        if let blob = self.toObjectOf(JSBlob.self) as? JSBlob {
            return Int(blob.size)
        }

        let byteLength: Int? = self.byteLength

        return byteLength ?? 0
    }
    
    static func uint8Array(from value: JSValue, context: JSContext) -> JSValue {
        let uint8Constructor: JSValue? = context.Uint8Array
        guard let uint8Constructor else { return JSValue(undefinedIn: context) }

        if value.isInstance(of: uint8Constructor) {
            return value
        }

        let dataViewConstructor: JSValue? = context.DataView

        if let dataViewConstructor, value.isInstance(of: dataViewConstructor) {
            let buffer: JSValue? = value.buffer
            let byteOffset: Int? = value.byteOffset
            let byteLength: Int? = value.byteLength

            guard let buffer, let byteOffset, let byteLength,
                  let wrapped = uint8Constructor.construct(withArguments: [buffer, byteOffset, byteLength])
                  else { return JSValue(undefinedIn: context) }

            return wrapped
        }

        let arrayBufferConstructor: JSValue? = context.ArrayBuffer
        
        if let arrayBufferConstructor, value.isInstance(of: arrayBufferConstructor) {
            guard let wrapped = uint8Constructor.construct(withArguments: [value]) else { return JSValue(undefinedIn: context) }
            
            return wrapped
        }

        let buffer: JSValue? = value.buffer

        if let buffer, !buffer.isUndefined,
           let arrayBufferConstructor, buffer.isInstance(of: arrayBufferConstructor) {
            let byteOffset: Int? = value.byteOffset
            let byteLength: Int? = value.byteLength

            guard let byteOffset, let byteLength,
                  let wrapped = uint8Constructor.construct(withArguments: [buffer, byteOffset, byteLength])
                  else { return JSValue(undefinedIn: context) }
            return wrapped
        }
        
        guard let wrapped = uint8Constructor.construct(withArguments: [value]) else { return JSValue(undefinedIn: context) }

        return wrapped
    }
}

extension Data {
    
    init?(uint8Array: JSValue) {
        if uint8Array.isUndefined || uint8Array.isNull {
            return nil
        }
        
        if !uint8Array.isUInt8Array {
            return nil
        }
        
        let length: Int32 = uint8Array.length ?? 0
        var bytes = [UInt8]()
        
        bytes.reserveCapacity(Int(length))
        
        for i in 0..<Int(length) {
            bytes.append(UInt8(clamping: uint8Array.objectAtIndexedSubscript(i)?.toInt32() ?? 0))
        }
        
        self = Self(bytes)
    }
}
