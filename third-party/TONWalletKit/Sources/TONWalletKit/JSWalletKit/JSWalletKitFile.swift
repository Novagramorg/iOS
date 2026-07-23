//
//  JSWalletKitFile.swift
//  TONWalletKit
//
//  Created by Nikita Rodionov on 12.09.2025.
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

protocol JSScript {
    func load() async throws -> String
}

struct JSWalletKitScript: JSScript {

    func load() async throws -> String {
        let jsFile = "walletkit-ios-bridge"
        let type = "mjs"
        
        guard let path = Bundle.module.path(forResource: jsFile, ofType: type) else {
            throw JSWalletKitResourceError.resourceNotFound(name: "\(jsFile).\(type)")
        }
        
        var code = try String(contentsOfFile: path, encoding: .utf8)
        
        code = code.replacingOccurrences(
            of: "export {\n  A3 as main\n};",
            with: """
            // Make main function available globally for JavaScriptCore
            var main = A3;
            
            // Auto-initialize on load
            console.log('🚀 WalletKit iOS Bridge starting from MJS...');
            try {
                main();
                console.log('✅ WalletKit main() called successfully from MJS');
            } catch (error) {
                console.error('❌ Error calling main() from MJS:', error);
            }
            """
        )
        
        return code
    }
}
