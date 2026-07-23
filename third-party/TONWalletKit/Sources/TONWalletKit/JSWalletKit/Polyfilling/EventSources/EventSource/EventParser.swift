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

struct EventParser {
    private var buffer = Data()
    
    mutating func parse(_ data: Data) -> [Event] {
        let (chunks, remaining) = extractChunks(buffer: buffer + data)
        buffer = remaining
        return parseChunks(chunks)
    }
    
    private func parseChunks(_ chunks: [Data]) -> [Event] {
        chunks.compactMap { parseEvent(chunk: $0) }
    }
    
    private func extractChunks(buffer: Data) -> (chunks: [Data], remaining: Data) {
        var buffer = buffer
        var chunks = [Data]()
        
        while let delimeterRange = getDelimeterRange(buffer: buffer) {
            let chunk = buffer[buffer.startIndex ..< delimeterRange.lowerBound]
            chunks.append(chunk)
            
            buffer = buffer[delimeterRange.upperBound ..< buffer.endIndex]
        }
        
        return (chunks, buffer)
    }
    
    private func getDelimeterRange(buffer: Data) -> Range<Data.Index>? {
        guard let range = buffer.firstRange(of: [UInt8.nl, UInt8.nl]) else { return nil }
        return range
    }
    
    private func parseEvent(chunk: Data) -> Event? {
        guard !chunk.isEmpty && chunk.first != .colon else {
            return nil
        }
        
        let rows = chunk.split(separator: .nl)
        var event = Event()
        
        for row in rows {
            let keyValue = row.split(separator: .colon, maxSplits: 1)
            let key = keyValue[0].string
            guard var value = keyValue[safe: 1]?.string else { continue }
            if value.hasPrefix(" ") {
                value = String(value.dropFirst())
            }
            
            switch key {
            case "id": event.id = value
            case "event": event.event = value
            case "data": event.data = value
            default: continue
            }
        }
        
        guard !event.isEmpty else { return nil }
        return event
    }
}

private extension UInt8 {
    static let nl: UInt8 = 0x0A
    static let colon: UInt8 = 0x3A
}

private extension Data {
    
    var string: String {
        String(decoding: self, as: UTF8.self)
    }
}
