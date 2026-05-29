import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum ReportContentResult {
    public struct Option: Equatable {
        public let text: String
        public let option: Data
    }
    
    case options(title: String, options: [Option])
    case addComment(optional: Bool, option: Data)
    case reported
}

public enum ReportContentError {
    case generic
    case messageIdRequired
}

public enum ReportContentSubject: Equatable {
    case peer(EnginePeer.Id, sourceMessageId: EngineMessage.Id? = nil)
    case messages([EngineMessage.Id])
    case stories(EnginePeer.Id, [Int32])
    
    public var peerId: EnginePeer.Id {
        switch self {
        case let .peer(peerId, _):
            return peerId
        case let .messages(messageIds):
            return messageIds.first!.peerId
        case let .stories(peerId, _):
            return peerId
        }
    }
}

private let ephemeralReportOptions: [(title: String, value: String)] = [
    ("Spam", "spam"),
    ("Violence", "violence"),
    ("Pornography", "pornography"),
    ("Child Abuse", "child_abuse"),
    ("Illegal Drugs", "illegal_drugs"),
    ("Personal Details", "personal_details"),
    ("Other", "other")
]

private func ephemeralReportOptionData(_ value: String) -> Data {
    return value.data(using: .utf8) ?? Data()
}

private func ephemeralReportReason(option: Data) -> Api.ReportReason? {
    guard let value = String(data: option, encoding: .utf8) else {
        return nil
    }

    switch value {
    case "spam":
        return .inputReportReasonSpam
    case "violence":
        return .inputReportReasonViolence
    case "pornography":
        return .inputReportReasonPornography
    case "child_abuse":
        return .inputReportReasonChildAbuse
    case "illegal_drugs":
        return .inputReportReasonIllegalDrugs
    case "personal_details":
        return .inputReportReasonPersonalDetails
    case "other":
        return .inputReportReasonOther
    default:
        return nil
    }
}

func _internal_reportContent(account: Account, subject: ReportContentSubject, option: Data?, message: String?) -> Signal<ReportContentResult, ReportContentError> {
    return account.postbox.transaction { transaction -> Signal<ReportContentResult, ReportContentError> in
        if case let .messages(messageIds) = subject, !messageIds.isEmpty, messageIds.allSatisfy({ $0.namespace == Namespaces.Message.EphemeralLocal }) {
            guard let option else {
                return .single(.options(title: "Report", options: ephemeralReportOptions.map { option in
                    ReportContentResult.Option(text: option.title, option: ephemeralReportOptionData(option.value))
                }))
            }

            if String(data: option, encoding: .utf8) == "other", message == nil {
                return .single(.addComment(optional: false, option: option))
            }

            guard let reason = ephemeralReportReason(option: option) else {
                return .fail(.generic)
            }

            var requests: [Signal<Api.ReportResult, MTRpcError>] = []
            for messageId in messageIds {
                guard let peer = transaction.getPeer(messageId.peerId), let inputPeer = apiInputPeer(peer), let _ = transaction.getMessage(messageId)?.attributes.first(where: { $0 is EphemeralMessageAttribute }) as? EphemeralMessageAttribute else {
                    continue
                }
                requests.append(account.network.request(Api.functions.ephemeral.reportMessage(peer: inputPeer, id: messageId.id, reason: reason, message: message ?? "")))
            }

            if requests.isEmpty {
                return .fail(.generic)
            }

            return combineLatest(requests)
            |> mapError { _ -> ReportContentError in
                return .generic
            }
            |> map { _ -> ReportContentResult in
                return .reported
            }
        }

        let sourceMessageId: MessageId?
        if case let .peer(_, messageId) = subject {
            sourceMessageId = messageId
        } else {
            sourceMessageId = nil
        }
        guard let peer = transaction.getPeer(subject.peerId), let inputPeer = apiInputPeer(peer, sourceMessageId: sourceMessageId, transaction: transaction) else {
            return .fail(.generic)
        }
        
        let request: Signal<Api.ReportResult, MTRpcError>
        if case let .stories(_, ids) = subject {
            request = account.network.request(Api.functions.stories.report(peer: inputPeer, id: ids, option: Buffer(data: option), message: message ?? ""))
        } else {
            var ids: [Int32] = []
            if case let .messages(messageIds) = subject {
                ids = messageIds.map { $0.id }
            }
            request = account.network.request(Api.functions.messages.report(peer: inputPeer, id: ids, option: Buffer(data: option), message: message ?? ""))
        }
        
        return request
        |> mapError { error -> ReportContentError in
            if error.errorDescription == "MESSAGE_ID_REQUIRED" {
                return .messageIdRequired
            }
            return .generic
        }
        |> map { result -> ReportContentResult in
            switch result {
            case let .reportResultChooseOption(reportResultChooseOptionData):
                let (title, options) = (reportResultChooseOptionData.title, reportResultChooseOptionData.options)
                return .options(title: title, options: options.map {
                    switch $0 {
                    case let .messageReportOption(messageReportOptionData):
                        let (text, option) = (messageReportOptionData.text, messageReportOptionData.option)
                        return ReportContentResult.Option(text: text, option: option.makeData())
                    }
                })
            case let .reportResultAddComment(reportResultAddCommentData):
                let (flags, option) = (reportResultAddCommentData.flags, reportResultAddCommentData.option)
                return .addComment(optional: (flags & (1 << 0)) != 0, option: option.makeData())
            case .reportResultReported:
                return .reported
            }
        }
    }
    |> castError(ReportContentError.self)
    |> switchToLatest
}
