import Foundation
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public struct TonApiRequestError: Error, Equatable {
    public let code: Int32
    public let description: String

    public init(code: Int32, description: String) {
        self.code = code
        self.description = description
    }
}

private func _internal_performTonApiRequest(
    account: Account,
    flags: Int32,
    endpoint: String,
    query: String?,
    payload: String?
) -> Signal<String, TonApiRequestError> {
    let request = Api.functions.toncenter.performApiRequest(
        flags: flags,
        endpoint: endpoint,
        query: query,
        payload: payload
    )

    return currentWebDocumentsHostDatacenterId(
        postbox: account.postbox,
        isTestingEnvironment: account.testingEnvironment
    )
    |> castError(TonApiRequestError.self)
    |> mapToSignal { datacenterId -> Signal<Api.toncenter.ApiResponse, TonApiRequestError> in
        let targetDatacenterId = Int(datacenterId)
        let signal: Signal<Api.toncenter.ApiResponse, MTRpcError>
        if account.network.datacenterId == targetDatacenterId {
            signal = account.network.request(request)
        } else {
            signal = account.network.download(datacenterId: targetDatacenterId, isMedia: false, tag: nil)
            |> castError(MTRpcError.self)
            |> mapToSignal { worker in
                return worker.request(request)
            }
        }

        return signal
        |> mapError { error in
            return TonApiRequestError(code: error.errorCode, description: error.errorDescription)
        }
    }
    |> map { result -> String in
        switch result {
        case let .apiResponse(apiResponse):
            switch apiResponse.response {
            case let .dataJSON(dataJSON):
                return dataJSON.data
            }
        }
    }
}

public extension TelegramEngine {
    final class Ton {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func performGetRequest(endpoint: String, query: String? = nil) -> Signal<String, TonApiRequestError> {
            var flags: Int32 = 0
            if query != nil {
                flags |= 1 << 1
            }

            return _internal_performTonApiRequest(
                account: self.account,
                flags: flags,
                endpoint: endpoint,
                query: query,
                payload: nil
            )
        }

        public func performPostRequest(endpoint: String, payload: String? = nil) -> Signal<String, TonApiRequestError> {
            var flags: Int32 = 1 << 0
            if payload != nil {
                flags |= 1 << 2
            }

            return _internal_performTonApiRequest(
                account: self.account,
                flags: flags,
                endpoint: endpoint,
                query: nil,
                payload: payload
            )
        }
    }
}
