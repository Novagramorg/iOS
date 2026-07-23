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

@preconcurrency import JavaScriptCore

public struct JSAbortControllerInstaller: JSContextInstallable, Sendable {
  let sleep: @Sendable (TimeInterval) async throws -> Void

  public func install(in context: JSContext) throws {
    let timeout: @convention(block) (JSValue, TimeInterval) -> Void = { controller, time in
      Task { try await self.sleep(controller: controller, time: time) }
    }
    context.setObject(timeout, forPath: "_jsCoreExtrasAbortSignalTimeout")
    try context.install([.domException, .jsCoreExtrasBundled(path: "AbortController.js")])
  }

  private func sleep(controller: JSValue, time: TimeInterval) async throws {
    try await self.sleep(time)
    let exception = controller.context.objectForKeyedSubscript("DOMException")
      .construct(withArguments: ["signal timed out", "TimeoutError"])!
    _ = controller.invokeMethod("abort", withArguments: [exception])
  }
}

extension JSContextInstallable where Self == JSAbortControllerInstaller {
  /// An installable that installs `AbortController` and `AbortSignal` functionallity.
  public static var abortController: Self {
    JSAbortControllerInstaller { interval in
      await withUnsafeContinuation { continuation in
        DispatchQueue.global()
          .asyncAfter(deadline: .now() + interval) {
            continuation.resume()
          }
      }
    }
  }

  /// An installable that installs `AbortController` and `AbortSignal` functionallity.
  ///
  /// - Parameter sleep: A function to sleep for a specified duration when `AbortSignal.timeout` is called.
  /// - Returns: An installable.
  public static func abortController(
    sleep: @Sendable @escaping (TimeInterval) async throws -> Void
  ) -> Self {
    JSAbortControllerInstaller(sleep: sleep)
  }
}
