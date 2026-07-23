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
import UniformTypeIdentifiers

// MARK: - MIMEType

/// A data type representing a MIME type.
public struct MIMEType: RawRepresentable, Hashable, Sendable, Codable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

// MARK: - ExpressibleByStringLiteral

extension MIMEType: ExpressibleByStringLiteral {
  public init(stringLiteral value: StringLiteralType) {
    self.init(rawValue: value)
  }
}

// MARK: - Of URL Init

extension MIMEType {
  /// Attempts to create a mime type by using the path extension of a `URL`.
  ///
  /// This initializer returns nil if the URL is a directory URL, or not a filesystem URL.
  ///
  /// - Parameter url: A filesystem `URL`.
  @available(iOS 14, macOS 11, tvOS 14, watchOS 7, visionOS 1, *)
  public init?(of url: URL) {
    guard !url.hasDirectoryPath && url.isFileURL else { return nil }
    if let identifier = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType {
      self.init(rawValue: identifier)
    } else {
      self = .octetStream
    }
  }
}

// MARK: - MIME Types

extension MIMEType {
  public static let empty: Self = ""
  public static let zipArchive: Self = "application/zip"
  public static let text: Self = "text/plain"
  public static let png: Self = "image/png"
  public static let jpeg: Self = "image/jpeg"
  public static let html: Self = "text/html"
  public static let pdf: Self = "application/pdf"
  public static let xml: Self = "application/xml"
  public static let json: Self = "application/json"
  public static let octetStream: Self = "application/octet-stream"
}
