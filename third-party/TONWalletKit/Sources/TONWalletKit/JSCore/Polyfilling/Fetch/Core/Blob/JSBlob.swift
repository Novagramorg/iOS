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
@preconcurrency import JavaScriptCore

// MARK: - JSBlob

@objc private protocol JSBlobExport: JSExport {
  var size: Int64 { get }
  var type: String { get }

  init?(blobParts iterable: JSValue, options: JSValue)

  func text() -> JSValue
  func bytes() -> JSValue
  func arrayBuffer() -> JSValue

  func slice(_ start: JSValue, _ end: JSValue, _ type: JSValue) -> JSBlob
}

/// A class representing a Javascript `Blob`.
///
/// > Note: The Objective C class name of this class is `Blob` instead of `JSBlob`. This is to
/// > ensure that JavaScriptCore recognizes the constructor name as `"Blob"` instead of `"JavaScriptCoreExtras.JSBlob"`.
///
/// You can create blobs through Javascript, but also by leveraging the ``JSBlobStorage``
/// protocol which allows you to create a blob with bytes from an arbitrary source such as a file.
@objc(Blob) open class JSBlob: NSObject {
  /// The `MIMEType` of this blob.
  public let mimeType: MIMEType

  private let indexedStorage: IndexedStorage

  /// Creates a blob using its Javascript initializer.
  ///
  /// See [MDN docs](https://developer.mozilla.org/en-US/docs/Web/API/Blob/Blob).
  public required convenience init?(blobParts iterable: JSValue, options: JSValue) {
    guard let context = JSContext.current() else { return nil }

    self.init(blobParts: iterable, options: options, context: context)
  }
    
    public convenience init?(blobParts iterable: JSValue, options: JSValue, context: JSContext) {
      let type = options.isUndefined ? "" : options.objectForKeyedSubscript("type").toString() ?? ""
      guard iterable.isUndefined || (iterable.isIterable && !iterable.isString) else {
        context.exception = .constructError(
          className: "Blob",
          message: "The provided value cannot be converted to a sequence.",
          in: context
        )
        return nil
      }
      guard !iterable.isUndefined else {
        self.init(storage: "", type: MIMEType(rawValue: type))
        return
      }
      let map: @convention(block) (JSValue) -> String = { $0.toString() }
      let strings = context.objectForKeyedSubscript("Array")
        .invokeMethod("from", withArguments: [iterable])
        .invokeMethod("map", withArguments: [unsafeBitCast(map, to: JSValue.self)])
        .toArray()
        .compactMap { $0 as? String }
      self.init(storage: strings.joined(), type: MIMEType(rawValue: type))
    }

  /// Creates a blob from another blob.
  ///
  /// - Parameter blob: Another blob.
  public init(blob: JSBlob) {
    self.mimeType = blob.mimeType
    self.indexedStorage = blob.indexedStorage
  }

  /// Creates a blob from a backing ``JSBlobStorage`` and `MIMEType`.
  ///
  /// ```swift
  /// let blob = JSBlob(storage: "Hello world!", type: .text)
  /// ```
  ///
  /// - Parameters:
  ///   - storage: A ``JSBlobStorage``.
  ///   - type: A `MIMEType`.
  public init(storage: some JSBlobStorage, type: MIMEType) {
    self.mimeType = type
    self.indexedStorage = IndexedStorage(
      startIndex: 0,
      endIndex: storage.utf8SizeInBytes,
      storage: storage
    )
  }

  private init(state: IndexedStorage, type: MIMEType) {
    self.indexedStorage = state
    self.mimeType = type
  }
}

// MARK: - Subscript

extension JSBlob {
  fileprivate subscript(range: Range<Int64>, type mimeType: MIMEType? = nil) -> JSBlob {
    var state = self.indexedStorage
    state.startIndex = range.lowerBound
    state.endIndex = range.upperBound
    return JSBlob(state: state, type: mimeType ?? self.mimeType)
  }

  fileprivate subscript(range: PartialRangeFrom<Int64>, type mimeType: MIMEType? = nil) -> JSBlob {
    var state = self.indexedStorage
    state.startIndex = range.lowerBound
    state.endIndex = self.size
    return JSBlob(state: state, type: mimeType ?? self.mimeType)
  }
}

// MARK: - UTF8

extension JSBlob {
  /// Returns the UTF8 view from this blob.
  public func utf8(context: JSContext) async throws -> String.UTF8View {
    try await self.indexedStorage.utf8(context: context)
  }
}

// MARK: - JSExport Conformance

extension JSBlob: JSBlobExport {
  /// The mime type as a raw string.
  public var type: String {
    self.mimeType.rawValue
  }

  /// The size (in bytes) of this blob.
  public var size: Int64 {
    self.indexedStorage.storage.utf8SizeInBytes
  }

  /// Returns the text of this blob as a `JSValue`.
  public func text() -> JSValue {
    self.utf8Promise { utf8, _ in String(utf8) }
  }

  /// Returns the bytes of this blob as a `JSValue`.
  public func bytes() -> JSValue {
    self.dataPromise { bufferWithRawBytes(data: $0, in: $1)?.bytes }
  }

  /// Returns a Javascript `ArrayBuffer` of this blob as a `JSValue`.
  public func arrayBuffer() -> JSValue {
    self.dataPromise { bufferWithRawBytes(data: $0, in: $1)?.buffer }
  }

  /// The implementation of Javascript's `Blob.slice`.
  ///
  /// Follows the [MDN spec](https://developer.mozilla.org/en-US/docs/Web/API/Blob/slice):
  /// negative indices are interpreted relative to `size`, both bounds are clamped to `[0, size]`,
  /// and `end <= start` yields an empty slice.
  public func slice(_ start: JSValue, _ end: JSValue, _ type: JSValue) -> JSBlob {
    let mimeType = MIMEType(rawValue: type.isUndefined ? self.type : type.toString() ?? "")
    let size = self.size
    let normalizedStart = normalizeSliceIndex(start, default: 0, size: size)
    let normalizedEnd = normalizeSliceIndex(end, default: size, size: size)
    let upper = max(normalizedStart, normalizedEnd)
    return self[normalizedStart..<upper, type: mimeType]
  }

  private func utf8Promise(
    _ map: @Sendable @escaping (String.UTF8View, JSContext) -> Any?
  ) -> JSValue {
      guard let context = JSContext.current() else {
          return JSValue(
              newPromiseRejectedWithReason: "No context exists to perform \(#function)",
              in: JSContext()
          )
      }

    let indexedStorage = self.indexedStorage
    return JSValue(newPromiseIn: context) { resolve, reject in
      Task {
        do {
          let utf8 = try await indexedStorage.utf8(context: context)
          resolve?.call(withArguments: [map(utf8, context) as Any])
        } catch let error as JSValueError {
          reject?.call(withArguments: [error.value as Any])
        }
      }
    }
  }

  private func dataPromise(
    _ map: @Sendable @escaping (Data, JSContext) -> Any?
  ) -> JSValue {
      guard let context = JSContext.current() else {
          return JSValue(
              newPromiseRejectedWithReason: "No context exists to perform \(#function)",
              in: JSContext()
          )
      }

    let indexedStorage = self.indexedStorage
    return JSValue(newPromiseIn: context) { resolve, reject in
      Task {
        do {
          let data = try await indexedStorage.rawBytes(context: context)
          resolve?.call(withArguments: [map(data, context) as Any])
        } catch let error as JSValueError {
          reject?.call(withArguments: [error.value as Any])
        }
      }
    }
  }
}

// MARK: - Helpers

extension JSBlob {
  private struct IndexedStorage: Sendable {
    var startIndex: Int64
    var endIndex: Int64
    let storage: any JSBlobStorage

    func utf8(context: JSContext) async throws(JSValueError) -> String.UTF8View {
      try await self.storage.utf8Bytes(
        startIndex: self.startIndex,
        endIndex: self.endIndex,
        context: context
      )
    }

    func rawBytes(context: JSContext) async throws(JSValueError) -> Data {
      try await self.storage.rawBytes(
        startIndex: self.startIndex,
        endIndex: self.endIndex,
        context: context
      )
    }
  }
}

private func normalizeSliceIndex(_ value: JSValue, default defaultValue: Int64, size: Int64) -> Int64 {
  guard !value.isUndefined else { return defaultValue }
  let raw = Int64(value.toInt32())
  if raw < 0 {
    return max(size + raw, 0)
  }
  return min(raw, size)
}

private func bufferWithRawBytes(
  data: Data,
  in context: JSContext
) -> (buffer: JSValue, bytes: JSValue)? {
  // Bridge the bytes into JS in a single call by passing them through `JSValue(object:)`
  // (which converts a `[UInt8]` to a JS Array), then constructing the typed array via
  // `Uint8Array.from(...)`. This avoids the O(N) per-byte bridge crossings of the previous
  // approach while keeping the implementation Swift-only (no JSC C API).
  guard let arrayValue = JSValue(object: Array(data), in: context) else { return nil }
  guard let bytes = context.objectForKeyedSubscript("Uint8Array")
    .invokeMethod("from", withArguments: [arrayValue]) else { return nil }
  guard let buffer = bytes.objectForKeyedSubscript("buffer") else { return nil }
  return (buffer, bytes)
}

// MARK: - Blob Installer

public struct JSBlobInstaller: JSContextInstallable, Sendable {
  public func install(in context: JSContext) {
    context.setObject(JSBlob.self, forPath: "Blob")
  }
}

extension JSContextInstallable where Self == JSBlobInstaller {
  /// An installable that installs the Blob class.
  public static var blob: Self { JSBlobInstaller() }
}
