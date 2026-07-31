//
//  JSAPIClient.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 20.01.2026.
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

import Foundation
import JavaScriptCore

@objc protocol JSAPIClient: JSExport {

    @objc(getNetwork)
    func getNetwork() -> JSValue
    
    @objc(sendBoc:)
    func send(boc: JSValue) -> JSValue
    
    @objc(runGetMethod::::)
    func runGetMethod(
        address: JSValue,
        method: JSValue,
        stack: JSValue,
        seqno: JSValue
    ) -> JSValue
    
    @objc(getMasterchainInfo)
    func masterchainInfo() -> JSValue

    @objc(nftItemsByAddress:)
    func nftItemsByAddress(request: JSValue) -> JSValue

    @objc(nftItemsByOwner:)
    func nftItemsByOwner(request: JSValue) -> JSValue

    @objc(getNftTransfers:)
    func getNftTransfers(request: JSValue) -> JSValue

    @objc(fetchEmulation::)
    func fetchEmulation(messageBoc: JSValue, ignoreSignature: JSValue) -> JSValue

    @objc(getAccountState::)
    func getAccountState(address: JSValue, seqno: JSValue) -> JSValue

    @objc(getAccountStates:)
    func getAccountStates(addresses: JSValue) -> JSValue

    @objc(getAccountTransactions:)
    func getAccountTransactions(request: JSValue) -> JSValue

    @objc(getAccountActions:)
    func getAccountActions(request: JSValue) -> JSValue

    @objc(getBalance::)
    func getBalance(address: JSValue, seqno: JSValue) -> JSValue

    @objc(resolveDnsWallet:)
    func resolveDnsWallet(domain: JSValue) -> JSValue

    @objc(backResolveDnsWallet:)
    func backResolveDnsWallet(address: JSValue) -> JSValue
}
