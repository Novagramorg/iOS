//
//  JSWalletAdapter.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 17.10.2025.
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

@objc protocol JSWalletAdapter: JSExport {
    @objc(getPublicKey) func publicKey() -> JSValue
    @objc(getWalletId) func identifier() -> JSValue
    @objc(getNetwork) func network() -> JSValue
    
    @objc(getAddress:) func address(options: JSValue) -> JSValue
    @objc(getStateInit) func stateInit() -> JSValue
    
    @objc(getSignedSendTransaction::) func signedSendTransaction(input: JSValue, options: JSValue) -> JSValue
    @objc(getSignedSignMessage::) func signedSignMessage(input: JSValue, options: JSValue) -> JSValue
    @objc(getSignedSignData::) func signedSignData(input: JSValue, options: JSValue) -> JSValue
    @objc(getSignedTonProof::) func signedTonProof(input: JSValue, options: JSValue) -> JSValue
    
    @objc(getSupportedFeatures) func supportedFeatures() -> JSValue
}
