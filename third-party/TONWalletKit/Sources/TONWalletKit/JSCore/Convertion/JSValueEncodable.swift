//
//  JSValueEncodable.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 22.10.2025.
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

protocol JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any
}

extension JSValue: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension String: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension Int: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension Int32: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension Int64: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension UInt8: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension UInt: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension UInt32: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension UInt64: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension Float: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension Double: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension Bool: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension Date: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension NSNull: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any { self }
}

extension Array: JSValueEncodable where Element: JSValueEncodable {

    func encode(in context: JSContext) throws -> Any {
        try self.map { element in
            try element.encode(in: context)
        }
    }
}

extension Dictionary: JSValueEncodable where Key == String, Value: JSValueEncodable & Encodable {

    func encode(in context: JSContext) throws -> Any {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            let object = try JSONSerialization.jsonObject(with: data)

            guard let value = JSValue(object: object, in: context) else {
                throw JSValueConversionError.unknown(message: "Unable to encode dictionary [String: \(Value.self)] to JSValue")
            }
            return value
        } catch let error as DecodingError {
            throw JSValueConversionError.decodingError(error)
        } catch {
            throw JSValueConversionError.unknown(message: error.localizedDescription)
        }
    }
}

extension JSValueEncodable where Self: Encodable, Self: RawRepresentable, Self.RawValue: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any {
        try rawValue.encode(in: context)
    }
}

extension JSValueEncodable where Self: Encodable {
    
    func encode(in context: JSContext) throws -> Any {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            let object = try JSONSerialization.jsonObject(with: data)
            
            // TODO: handle case when object is Encodable but it's not a json
            guard let value = JSValue(object: object, in: context) else {
                throw JSValueConversionError.unknown(message: "Unable to encode value: \(Self.self) to JSValue")
            }
            return value
        } catch let error as DecodingError {
            throw JSValueConversionError.decodingError(error)
        } catch {
            throw JSValueConversionError.unknown(message: error.localizedDescription)
        }
    }
}

extension Optional: JSValueEncodable where Wrapped: JSValueEncodable {
    
    func encode(in context: JSContext) throws -> Any {
        switch self {
        case .none:
            return JSValue(nullIn: context) as Any
        case .some(let wrapped):
            return try wrapped.encode(in: context)
        }
    }
}

extension JSValueEncodable where Self: JSExport {
    
    func encode(in context: JSContext) throws -> Any {
        self
    }
}
