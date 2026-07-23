//
//  JSValueConvertible.swift
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

protocol JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Self?
}

extension String: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> String? {
        guard value.isString else { return nil }
        
        return value.toString()
    }
}

extension Int: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Int? {
        guard value.isNumber, let number = value.toNumber() else { return nil }
        
        return number.intValue
    }
}

extension Int32: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Int32? {
        guard value.isNumber, let number = value.toNumber() else { return nil }
        
        return number.int32Value
    }
}

extension Int64: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Int64? {
        guard value.isNumber, let number = value.toNumber() else { return nil }
        
        return number.int64Value
    }
}

extension UInt: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> UInt? {
        guard value.isNumber, let number = value.toNumber() else { return nil }
        
        return number.uintValue
    }
}

extension UInt32: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> UInt32? {
        guard value.isNumber, let number = value.toNumber() else { return nil }
        
        return number.uint32Value
    }
}

extension UInt64: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> UInt64? {
        guard value.isNumber, let number = value.toNumber() else { return nil }
        
        return number.uint64Value
    }
}

extension Float: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Float? {
        guard value.isNumber, let number = value.toNumber() else { return nil }
        
        return number.floatValue
    }
}

extension Double: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Double? {
        guard value.isNumber, let number = value.toNumber() else { return nil }
        
        return number.doubleValue
    }
}

extension Bool: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Bool? {
        guard value.isBoolean else { return nil }
        return value.toBool()
    }
}

extension Date: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Date? {
        if value.isDate, let date = value.toDate() {
            return date
        }
        return nil
    }
}

extension JSValue: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Self? {
        if value.isObject && !value.isUndefined {
            return value as? Self
        }
        return nil
    }
}

extension Dictionary: JSValueDecodable where Key: Decodable, Value: Decodable {}
extension Array: JSValueDecodable where Element: Decodable {}

extension JSValueDecodable where Self: Decodable {
    
    static func from(_ value: JSValue) throws -> Self? {
        guard value.isObject && !value.isUndefined && !value.isDate && !value.isNull else {
            return nil
        }
            
        let object: Any
        
        if value.isArray {
            object = value.toArray() ?? []
        } else if let dictionary = value.toDictionary() {
            object = dictionary
        } else {
            return nil
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: object, options: [])
            let decoder = JSONDecoder()
            return try decoder.decode(Self.self, from: jsonData)
        } catch let error as DecodingError {
            throw JSValueConversionError.decodingError(error)
        } catch {
            throw JSValueConversionError.unknown(message: error.localizedDescription)
        }
    }
}

extension JSValueDecodable where Self: Decodable, Self: RawRepresentable, Self.RawValue: JSValueDecodable {
    
    static func from(_ value: JSValue) throws -> Self? {
        guard let rawValue = try RawValue.from(value) else {
            return nil
        }
        return Self(rawValue: rawValue)
    }
}
