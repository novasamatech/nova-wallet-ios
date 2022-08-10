import Foundation
import IrohaCrypto

enum ChainFormat {
    case ethereum
    case substrate(_ prefix: UInt16)
}

extension AccountId {
    func toAddress(using conversion: ChainFormat) throws -> AccountAddress {
        switch conversion {
        case .ethereum:
            return toHex(includePrefix: true)
        case let .substrate(prefix):
            return try SS58AddressFactory().address(fromAccountId: self, type: prefix)
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
        case let .substrate(prefix):
            return try SS58AddressFactory().accountId(fromAddress: self, type: prefix)
        }
    }

    func toAccountId() throws -> AccountId {
        if hasPrefix("0x") {
            return try extractEthereumAccountId()
        } else {
            let addressFactory = SS58AddressFactory()
            let type = try addressFactory.type(fromAddress: self)
            return try addressFactory.accountId(fromAddress: self, type: type.uint16Value)
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
}

extension ChainModel {
    var chainFormat: ChainFormat {
        if isEthereumBased {
            return .ethereum
        } else {
            return .substrate(addressPrefix)
        }
    }
}
