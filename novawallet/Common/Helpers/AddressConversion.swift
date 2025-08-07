import Foundation
import NovaCrypto

enum ChainFormat {
    case ethereum
    case substrate(_ prefix: UInt16, legacyPrefix: UInt16? = nil)
}

extension ChainFormat {
    static var defaultSubstrateFormat: ChainFormat {
        .substrate(0, legacyPrefix: nil)
    }
}

extension AccountId {
    func toAddress(using conversion: ChainFormat) throws -> AccountAddress {
        switch conversion {
        case .ethereum:
            toHex(includePrefix: true)
        case let .substrate(prefix, _):
            try SS58AddressFactory().address(
                fromAccountId: self,
                type: prefix
            )
        }
    }
}

enum AccountAddressConversionError: Error {
    case invalidEthereumAddress
    case invalidChainAddress
}

extension AccountAddress {
    private func extractEthereumAccountId() throws -> AccountId {
        let accountId = try AccountId(hexString: self)

        guard accountId.count == SubstrateConstants.ethereumAddressLength else {
            throw AccountAddressConversionError.invalidEthereumAddress
        }

        return accountId
    }

    func toAccountId(using conversion: ChainFormat) throws -> AccountId {
        switch conversion {
        case .ethereum:
            return try extractEthereumAccountId()
        case let .substrate(prefix, legacyPrefix):
            let factory = SS58AddressFactory()
            let type = try factory.type(fromAddress: self).uint16Value

            let correspondingPrefix = if let legacyPrefix, legacyPrefix == type {
                legacyPrefix
            } else {
                prefix
            }

            return try factory.accountId(
                fromAddress: self,
                type: correspondingPrefix
            )
        }
    }

    func toAccountId() throws -> AccountId {
        if hasPrefix("0x") {
            return try extractEthereumAccountId()
        } else {
            let addressFactory = SS58AddressFactory()
            let type = try addressFactory.type(fromAddress: self).uint16Value
            return try addressFactory.accountId(fromAddress: self, type: type)
        }
    }

    func toChainAccountIdOrSubstrateGeneric(
        using conversion: ChainFormat
    ) throws -> AccountId {
        switch conversion {
        case .ethereum:
            return try extractEthereumAccountId()
        case let .substrate(prefix, legacyPrefix):
            let addressFactory = SS58AddressFactory()
            let type = try addressFactory.type(fromAddress: self).uint16Value

            guard
                type == legacyPrefix
                || type == prefix
                || type == SNAddressType.genericSubstrate.rawValue
            else {
                throw AccountAddressConversionError.invalidChainAddress
            }

            return try addressFactory.accountId(fromAddress: self, type: type)
        }
    }

    func toSubstrateAccountId(using prefix: UInt16? = nil) throws -> AccountId {
        let factory = SS58AddressFactory()

        let type: UInt16

        if let prefix = prefix {
            type = prefix
        } else {
            type = try factory.type(fromAddress: self).uint16Value
        }

        return try factory.accountId(fromAddress: self, type: type)
    }

    func toEthereumAccountId() throws -> AccountId {
        try extractEthereumAccountId()
    }

    func normalize(for chainFormat: ChainFormat) -> AccountAddress? {
        try? toAccountId(using: chainFormat).toAddress(using: chainFormat)
    }

    func toLegacySubstrateAddress(for chainFormat: ChainFormat) throws -> AccountAddress? {
        guard
            case let .substrate(_, legacyPrefix) = chainFormat,
            let legacyPrefix
        else { return nil }

        let factory = SS58AddressFactory()
        let accountId = try toAccountId(using: chainFormat)
        let legacyAddress = try factory.address(fromAccountId: accountId, type: legacyPrefix)

        return legacyAddress
    }
}

extension ChainModel {
    var chainFormat: ChainFormat {
        if isEthereumBased {
            .ethereum
        } else {
            .substrate(
                addressPrefix.toSubstrateFormat(),
                legacyPrefix: legacyAddressPrefix?.toSubstrateFormat()
            )
        }
    }
}
