import Foundation
import NovaCrypto

protocol DAppSignBytesChainResolving {
    func resolveChainForBytesSigning(
        for address: AccountAddress,
        wallet: MetaAccountModel,
        chains: [ChainModel]
    ) throws -> ChainModel
}

enum DAppBrowserSigningChainResolverError: Error {
    case noChainFound
}

final class DAppSignBytesChainResolver {}

private extension DAppSignBytesChainResolver {
    func deriveChainForPolkadotVaultWallet(
        for addressPrefix: UInt16,
        chains: [ChainModel]
    ) -> ChainModel? {
        let prefixMatchingChains = chains.filter { $0.addressPrefix == addressPrefix }

        // there is only one possible chain
        if let chain = prefixMatchingChains.first, prefixMatchingChains.count == 1 {
            return chain
        }

        if addressPrefix == UInt16(SNAddressType.kusamaMain.rawValue) {
            return chains.first { $0.chainId == KnowChainId.kusama }
        }

        // either unsupported prefix or more then one chain detected then fallback to polkadot
        return chains.first { $0.chainId == KnowChainId.polkadot }
    }

    func deriveChainForWallet(
        for address: AccountAddress,
        wallet: MetaAccountModel,
        chains: [ChainModel]
    ) throws -> ChainModel? {
        let accountId = try address.toAccountId()
        let addressPrefix = try SS58AddressFactory().type(fromAddress: address).uint16Value

        switch wallet.type {
        case .secrets,
             .watchOnly,
             .paritySigner,
             .ledger,
             .genericLedger,
             .proxied:
            let prefixMatchingChains = chains.filter { $0.addressPrefix == addressPrefix }

            return prefixMatchingChains
                .sorted { $0.order < $1.order }
                .first { wallet.fetch(for: $0.accountRequest())?.accountId == accountId }
        case .polkadotVault, .polkadotVaultRoot:
            let walletMatchingChains = chains.filter {
                wallet.fetch(for: $0.accountRequest())?.accountId == accountId
            }

            return deriveChainForPolkadotVaultWallet(for: addressPrefix, chains: walletMatchingChains)
        }
    }
}

extension DAppSignBytesChainResolver: DAppSignBytesChainResolving {
    func resolveChainForBytesSigning(
        for address: AccountAddress,
        wallet: MetaAccountModel,
        chains: [ChainModel]
    ) throws -> ChainModel {
        guard
            let chain = try deriveChainForWallet(
                for: address,
                wallet: wallet,
                chains: chains
            ) else {
            throw DAppBrowserSigningChainResolverError.noChainFound
        }

        return chain
    }
}
