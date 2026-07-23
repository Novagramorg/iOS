//
//  JSEventSourcePolyfill.swift
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
@preconcurrency import JavaScriptCore

public class JSEventSourcePolyfill: JSPolyfill {
    private var eventSources: [String: EventSourceTask] = [:]
    private let stateQueue = DispatchQueue(label: "com.eventsource.state")
    private let callbackQueue = DispatchQueue(label: "com.eventsource.callbacks")

    deinit {
        for (_, task) in eventSources {
            Task { @EventSourceActor in
                task.cancel()
            }
        }
        eventSources.removeAll()
    }

    public func apply(to context: JSContext) {
        let eventSourceCreate: @convention(block) (
            String,
            String,
            JSValue?
        ) -> String = { [weak context] url, eventSourceId, options in
            guard let context else {
                return "failure"
            }

            Task {
                await self.createEventSource(
                    in: context,
                    url: url,
                    eventSourceID: eventSourceId,
                    options: options
                )
            }
            return "success"
        }

        let eventSourceClose: @convention(block) (String) -> Void = { eventSourceId in
            self.closeEventSource(eventSourceId: eventSourceId)
        }

        context.setObject(eventSourceCreate, forKeyedSubscript: "nativeEventSourceCreate" as NSString)
        context.setObject(eventSourceClose, forKeyedSubscript: "nativeEventSourceClose" as NSString)
    }

    private func createEventSource(
        in context: JSContext,
        url: String,
        eventSourceID: String,
        options: JSValue?
    ) async {
        guard let requestUrl = URL(string: url) else {
            handleEventSourceError(
                in: context,
                eventSourceID: eventSourceID,
                error: NSError(
                    domain: "EventSourceError",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
                )
            )
            return
        }

        var urlRequest = URLRequest(url: requestUrl)
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let task = await Task { @EventSourceActor in
            let eventSource = EventSource()
            return eventSource.createTask(urlRequest: urlRequest)
        }.value

        stateQueue.sync { self.eventSources[eventSourceID] = task }

        Task { [weak self] in
            guard let self = self else { return }

            for await event in await task.eventsStream() {
                self.handleEventSourceEvent(
                    in: context,
                    eventSourceID: eventSourceID,
                    event: event
                )
            }
        }
    }

    private func handleEventSourceEvent(
        in context: JSContext,
        eventSourceID: String,
        event: EventSourceTask.TaskEvent
    ) {
        let script = Self.script(for: event, eventSourceID: eventSourceID)
        callbackQueue.async {
            context.evaluateScript(script)
        }
    }

    private func closeEventSource(eventSourceId: String) {
        let task: EventSourceTask? = stateQueue.sync {
            self.eventSources.removeValue(forKey: eventSourceId)
        }
        guard let task else { return }
        Task { @EventSourceActor in
            task.cancel()
        }
    }

    private func handleEventSourceError(
        in context: JSContext,
        eventSourceID: String,
        error: Error
    ) {
        let script = Self.errorScript(for: error, eventSourceID: eventSourceID)
        callbackQueue.async {
            _ = context.evaluateScript(script)
        }
        closeEventSource(eventSourceId: eventSourceID)
    }

    private static func script(
        for event: EventSourceTask.TaskEvent,
        eventSourceID: String
    ) -> String {
        switch event {
        case .open:
            return """
                if (window.eventSourceInstances && window.eventSourceInstances['\(eventSourceID)']) {
                    window.eventSourceInstances['\(eventSourceID)']._handleOpen();
                }
            """

        case .closed:
            return """
                if (window.eventSourceInstances && window.eventSourceInstances['\(eventSourceID)']) {
                    const instance = window.eventSourceInstances['\(eventSourceID)'];
                    instance.readyState = 2; // CLOSED
                    delete window.eventSourceInstances['\(eventSourceID)'];
                }
            """

        case .event(let eventData):
            let data = eventData.data?.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r") ?? ""

            let eventType = eventData.event?.replacingOccurrences(of: "'", with: "\\'") ?? "message"
            let eventId = eventData.id?.replacingOccurrences(of: "'", with: "\\'") ?? ""

            return """
                if (window.eventSourceInstances && window.eventSourceInstances['\(eventSourceID)']) {
                    window.eventSourceInstances['\(eventSourceID)']._handleMessage('\(data)', '\(eventType)', '\(eventId)');
                }
            """

        case .error(let error):
            return errorScript(for: error, eventSourceID: eventSourceID)
        }
    }

    private static func errorScript(
        for error: Error,
        eventSourceID: String
    ) -> String {
        let errorMessage = error.localizedDescription.replacingOccurrences(of: "'", with: "\\'")
        return """
            if (window.eventSourceInstances && window.eventSourceInstances['\(eventSourceID)']) {
                window.eventSourceInstances['\(eventSourceID)']._handleError(new Error('\(errorMessage)'));
            }
        """
    }
}
