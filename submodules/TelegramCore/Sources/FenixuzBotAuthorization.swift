import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum ImportBotAuthorizationError {
    case invalidToken
    case limitExceeded
    case generic
}

// Bot-token login. auth.importBotAuthorization is atomic (no code/password step), so this
// mirrors the tail of the phone flow: it reuses the exact same completion helpers
// (storeFutureLoginToken / AuthorizedAccountState / initializedAppSettingsAfterLogin /
// switchToAuthorizedAccount) instead of adding a new UnauthorizedAccountStateContents case.
public func importBotAuthorization(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, apiId: Int32, apiHash: String, botToken: String) -> Signal<Void, ImportBotAuthorizationError> {
    // The RPC on a given account's network.
    let performRequest: (UnauthorizedAccount) -> Signal<Api.auth.Authorization, MTRpcError> = { acc in
        return acc.network.request(Api.functions.auth.importBotAuthorization(flags: 0, apiId: apiId, apiHash: apiHash, botAuthToken: botToken), automaticFloodWait: false)
    }

    return performRequest(account)
    |> map { authorization -> (Api.auth.Authorization, UnauthorizedAccount) in
        return (authorization, account)
    }
    |> `catch` { error -> Signal<(Api.auth.Authorization, UnauthorizedAccount), MTRpcError> in
        // A bot lives on one DC. If the request hit the wrong DC the server answers
        // USER_MIGRATE_/NETWORK_MIGRATE_/PHONE_MIGRATE_<dc>: switch the account to that DC and retry
        // there (mirrors sendAuthorizationCode, Authorization.swift:201-210). Without this, users whose
        // home DC differs from the bot's just get a generic error.
        let desc = error.errorDescription ?? ""
        if let range = desc.range(of: "MIGRATE_"), let updatedMasterDatacenterId = Int32(desc[range.upperBound...]) {
            return account.changedMasterDatacenterId(accountManager: accountManager, masterDatacenterId: updatedMasterDatacenterId)
            |> mapToSignalPromotingError { updatedAccount -> Signal<(Api.auth.Authorization, UnauthorizedAccount), MTRpcError> in
                return performRequest(updatedAccount)
                |> map { authorization -> (Api.auth.Authorization, UnauthorizedAccount) in
                    return (authorization, updatedAccount)
                }
            }
        } else {
            return .fail(error)
        }
    }
    |> mapError { error -> ImportBotAuthorizationError in
        #if DEBUG
        NSLog("FENIX_BOTLOGIN_ERR desc=%@", error.errorDescription ?? "")
        #endif
        if error.errorDescription == "ACCESS_TOKEN_INVALID" || error.errorDescription == "ACCESS_TOKEN_EXPIRED" {
            return .invalidToken
        } else if (error.errorDescription ?? "").hasPrefix("FLOOD_WAIT") {
            return .limitExceeded
        } else {
            return .generic
        }
    }
    |> mapToSignal { resultAndAccount -> Signal<Void, ImportBotAuthorizationError> in
        let (result, resolvedAccount) = resultAndAccount
        return resolvedAccount.postbox.transaction { transaction -> Signal<Void, ImportBotAuthorizationError> in
            switch result {
            case let .authorization(authorizationData):
                let (futureAuthToken, apiUser) = (authorizationData.futureAuthToken, authorizationData.user)
                if let futureAuthToken = futureAuthToken {
                    storeFutureLoginToken(accountManager: accountManager, token: futureAuthToken.makeData())
                }

                let user = TelegramUser(user: apiUser)
                let state = AuthorizedAccountState(isTestingEnvironment: resolvedAccount.testingEnvironment, masterDatacenterId: resolvedAccount.masterDatacenterId, peerId: user.id, state: nil, invalidatedChannels: [])
                initializedAppSettingsAfterLogin(transaction: transaction, appVersion: resolvedAccount.networkArguments.appVersion, syncContacts: false)
                transaction.setState(state)
                // Mark this as a bot session so replayFinalState forces chat-list inclusion for
                // post-login messages (bots can't sync dialogs). See FenixuzBotSession.swift.
                setFenixuzBotSession(transaction: transaction, isBot: true)

                return accountManager.transaction { transaction in
                    switchToAuthorizedAccount(transaction: transaction, account: resolvedAccount, isSupportUser: false)
                }
                |> castError(ImportBotAuthorizationError.self)
            case .authorizationSignUpRequired:
                return .fail(.generic)
            }
        }
        |> castError(ImportBotAuthorizationError.self)
        |> switchToLatest
    }
}
