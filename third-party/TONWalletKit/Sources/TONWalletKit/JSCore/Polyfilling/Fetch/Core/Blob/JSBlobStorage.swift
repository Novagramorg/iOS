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

// MARK: - JSBlobStorage

/// A protocol that allows the creation of ``JSBlob`` by using an arbitrary source of bytes such
/// as a file.
public protocol JSBlobStorage: Sendable {
    /// The size (in bytes) of the stored UTF8 content.
    var utf8SizeInBytes: Int64 { get }

    /// Returns the stored UTF8 bytes.
    ///
    /// - Parameters:
    ///   - startIndex: The starting index in the UTF8 data.
    ///   - endIndex: The ending index in the UTF8 data.
    ///   - context: The `JSContext` of the blob fetching bytes.
    /// - Throws: A ``JSValueError``.
    /// - Returns: UTF8 data.
    func utf8Bytes(
        startIndex: Int64,
        endIndex: Int64,
        context: JSContext
    ) async throws(JSValueError) -> String.UTF8View

    /// Returns the raw bytes for `Blob.bytes()` / `Blob.arrayBuffer()`.
    ///
    /// Binary-safe — does not round-trip through UTF-8. The default implementation
    /// derives bytes from ``utf8Bytes(startIndex:endIndex:context:)`` for storages that
    /// only have a textual source.
    func rawBytes(
        startIndex: Int64,
        endIndex: Int64,
        context: JSContext
    ) async throws(JSValueError) -> Data
}

extension JSBlobStorage {
    public func rawBytes(
        startIndex: Int64,
        endIndex: Int64,
        context: JSContext
    ) async throws(JSValueError) -> Data {
        let utf8 = try await self.utf8Bytes(startIndex: startIndex, endIndex: endIndex, context: context)
        return Data(utf8)
    }
}

// MARK: - String Conformances

extension String: JSBlobStorage {
    public func utf8Bytes(
        startIndex: Int64,
        endIndex: Int64,
        context: JSContext
    ) -> String.UTF8View {
        self.utf8.utf8Bytes(startIndex: startIndex, endIndex: endIndex, context: context)
    }
}

extension Substring: JSBlobStorage {
    public func utf8Bytes(
        startIndex: Int64,
        endIndex: Int64,
        context: JSContext
    ) -> String.UTF8View {
        self.utf8.utf8Bytes(startIndex: startIndex, endIndex: endIndex, context: context)
    }
}

extension StringProtocol where Self: JSBlobStorage {
    public var utf8SizeInBytes: Int64 { Int64(self.utf8.count) }
}

extension String.UTF8View: JSBlobStorage {
    public var utf8SizeInBytes: Int64 { Int64(self.count) }
    
    public func utf8Bytes(startIndex: Int64, endIndex: Int64, context: JSContext) -> Self {
        self[self.startIndex..<self.endIndex]
            .utf8Bytes(startIndex: startIndex, endIndex: endIndex, context: context)
    }
}

extension Substring.UTF8View: JSBlobStorage {
    public var utf8SizeInBytes: Int64 { Int64(self.count) }
    
    public func utf8Bytes(
        startIndex: Int64,
        endIndex: Int64,
        context: JSContext
    ) -> String.UTF8View {
        guard startIndex >= 0 && endIndex >= startIndex else {
            return String(self)?.utf8 ?? "".utf8
        }
        
        guard startIndex < self.count && endIndex <= self.count else {
            return String(self)?.utf8 ?? "".utf8
        }
        
        let startIndex = self.index(self.startIndex, offsetBy: Int(startIndex))
        let endIndex = self.index(self.startIndex, offsetBy: Int(endIndex))
        return String(Substring(self[startIndex..<endIndex])).utf8
    }
}
