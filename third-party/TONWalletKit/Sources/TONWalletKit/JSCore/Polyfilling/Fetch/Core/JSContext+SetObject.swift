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

import JavaScriptCore

extension JSContext {
  /// Sets an object in this context using a nestable path.
  ///
  /// ```swift
  /// let context = JSContext()!
  ///
  /// // Use "." to set nested properties as you would in Javascript.
  /// context.setObject("hello", forPath: "foo.bar.baz")
  /// let value = context.evaluateScript("foo.bar.baz")
  /// #expect(value?.toString() == "hello")
  /// ```
  ///
  /// - Parameters:
  ///   - object: The object value to set the property at the path to.
  ///   - path: The path to the object property.
  public func setObject(_ object: Any?, forPath path: String) {
    self.globalObject.setValue(object, forPath: path)
  }
}

extension JSValue {
  /// Sets an object in this value using a nestable path.
  ///
  /// ```swift
  /// let value = JSValue(newObjectIn: .current())!
  ///
  /// // Use "." to set nested properties as you would in Javascript.
  /// value.setValue("hello", forPath: "foo.bar.baz")
  /// let value = value.context.evaluateScript("foo.bar.baz")
  /// #expect(value?.toString() == "hello")
  /// ```
  ///
  /// - Parameters:
  ///   - object: The object value to set the property at the path to.
  ///   - path: The path to the object property.
  public func setValue(_ object: Any?, forPath path: String) {
    let subpaths = path.split(separator: ".")
    guard let firstPath = subpaths.first, let lastPath = subpaths.last else { return }
    if subpaths.count == 1 {
      self.setObject(object, forKeyedSubscript: firstPath as NSString)
    } else {
      var currentValue = self.objectForKeyedSubscript(firstPath as NSString)
      for subpath in subpaths.dropLast() {
        if let object = self.objectForKeyedSubscript(subpath as NSString), !object.isUndefined {
          currentValue = object
          continue
        }
        let object = JSValue(newObjectIn: self.context)
        if let currentValue, currentValue.isUndefined {
          self.setObject(object, forKeyedSubscript: subpath as NSString)
        } else {
          currentValue?.setObject(object, forKeyedSubscript: subpath as NSString)
        }
        currentValue = object
      }
      currentValue?.setObject(object, forKeyedSubscript: lastPath as NSString)
    }
  }
}
