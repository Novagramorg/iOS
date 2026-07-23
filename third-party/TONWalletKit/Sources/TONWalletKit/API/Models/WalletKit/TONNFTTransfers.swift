//
//  TONNFTTransfers.swift
//  TONWalletKit
//

import Foundation

public enum TONNFTTransferDirection: String, Codable, CaseIterable {
    case incoming = "in"
    case outgoing = "out"
}

public struct TONNFTTransfersRequest: Codable {
    public var ownerAddresses: [TONUserFriendlyAddress]
    public var itemAddresses: [TONUserFriendlyAddress]
    public var direction: TONNFTTransferDirection?
    public var pagination: TONPagination?

    public init(
        ownerAddresses: [TONUserFriendlyAddress],
        itemAddresses: [TONUserFriendlyAddress],
        direction: TONNFTTransferDirection? = nil,
        pagination: TONPagination? = nil
    ) {
        self.ownerAddresses = ownerAddresses
        self.itemAddresses = itemAddresses
        self.direction = direction
        self.pagination = pagination
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case ownerAddresses
        case itemAddresses
        case direction
        case pagination
    }
}

public struct TONNFTTransfer: Codable, Equatable {
    public var nftAddress: TONUserFriendlyAddress
    public var oldOwner: TONUserFriendlyAddress?
    public var newOwner: TONUserFriendlyAddress?
    public var transactionNow: Int32
    public var transactionAborted: Bool

    public init(
        nftAddress: TONUserFriendlyAddress,
        oldOwner: TONUserFriendlyAddress? = nil,
        newOwner: TONUserFriendlyAddress? = nil,
        transactionNow: Int32,
        transactionAborted: Bool
    ) {
        self.nftAddress = nftAddress
        self.oldOwner = oldOwner
        self.newOwner = newOwner
        self.transactionNow = transactionNow
        self.transactionAborted = transactionAborted
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case nftAddress
        case oldOwner
        case newOwner
        case transactionNow
        case transactionAborted
    }
}

public struct TONNFTTransfersResponse: Codable, Equatable {
    public var transfers: [TONNFTTransfer]

    public init(transfers: [TONNFTTransfer]) {
        self.transfers = transfers
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case transfers
    }
}

extension TONNFTTransfersRequest: JSValueCodable {}
extension TONNFTTransfer: JSValueCodable {}
extension TONNFTTransfersResponse: JSValueCodable {}
