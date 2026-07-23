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

// MARK: - Reading

extension NSFileCoordinator {
  func coordinate<T>(
    readingItemAt url: URL,
    options: NSFileCoordinator.ReadingOptions = [],
    byAccessor: (URL) throws -> T
  ) throws -> T {
    try self.coordinate { pointer, state in
      self.coordinate(readingItemAt: url, error: pointer) { url in
        state.perform { try byAccessor(url) }
      }
    }
  }
}

// MARK: - Helper

private struct CoordinateState<T> {
  private(set) var value: T?
  private(set) var error: (any Error)?

  mutating func perform(_ work: () throws -> T) {
    do {
      self.value = try work()
    } catch {
      self.error = error
    }
  }
}

extension NSFileCoordinator {
  private func coordinate<T>(
    _ coordinate: (NSErrorPointer, inout CoordinateState<T>) throws -> Void
  ) throws -> T {
    var state = CoordinateState<T>()
    var coordinatorError: NSError?
    try coordinate(&coordinatorError, &state)
    if let error = coordinatorError ?? state.error {
      throw error
    }
    return state.value!
  }
}
