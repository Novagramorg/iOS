//
//  CRCTests.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 08.02.2026.
//
//  Copyright (c) 2026 TON Connect
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

import Testing
import Foundation
@testable import TONWalletKit

@Suite("CRC16 Tests")
struct CRC16Tests {

    @Test("CRC16 of '123456789' matches XMODEM check value")
    func crc16StandardCheckValue() {
        // CRC-16/XMODEM check value for "123456789" is 0x31C3
        let data = Data("123456789".utf8)
        let crc = data.crc16()
        #expect(crc == Data([0x31, 0xC3]))
    }

    @Test("CRC16 returns two bytes")
    func crc16ReturnsTwoBytes() {
        let data = Data([0x01, 0x02, 0x03])
        let crc = data.crc16()
        #expect(crc.count == 2)
    }

    @Test("CRC16 of empty data returns zero")
    func crc16EmptyData() {
        let crc = Data().crc16()
        #expect(crc == Data([0x00, 0x00]))
    }

    @Test("CRC16 of single byte 0x00")
    func crc16SingleZeroByte() {
        let crc = Data([0x00]).crc16()
        #expect(crc.count == 2)
    }

    @Test("CRC16 is deterministic")
    func crc16Deterministic() {
        let data = Data("hello".utf8)
        let crc1 = data.crc16()
        let crc2 = data.crc16()
        #expect(crc1 == crc2)
    }

    @Test("CRC16 differs for different inputs")
    func crc16DifferentInputs() {
        let crc1 = Data("hello".utf8).crc16()
        let crc2 = Data("world".utf8).crc16()
        #expect(crc1 != crc2)
    }
}
