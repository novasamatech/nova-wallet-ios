import Foundation

enum CloudBackupChainAccountChange: Equatable, Hashable {
    case new(remote: ChainAccountModel)
    case update(local: ChainAccountModel, remote: ChainAccountModel)
    case delete(local: ChainAccountModel)
}

enum CloudBackupChange: Equatable, Hashable {
    case new(remote: MetaAccountModel)
    case delete(local: MetaAccountModel)
    case updatedChainAccounts(
        local: MetaAccountModel,
        remote: MetaAccountModel,
        changes: Set<CloudBackupChainAccountChange>
    )
    case updatedMainAccounts(
        local: MetaAccountModel,
        remote: MetaAccountModel
    )
    case updatedMetadata(local: MetaAccountModel, remote: MetaAccountModel)
}

typealias CloudBackupDiff = Set<CloudBackupChange>

protocol CloudBackupDiffCalculating {
    func calculateBetween(
        wallets: Set<MetaAccountModel>,
        publicBackupInfo: CloudBackup.PublicData
    ) throws -> CloudBackupDiff
}

final class CloudBackupDiffCalculator {
    typealias LocalStore = [MetaAccountModel.Id: MetaAccountModel]
    typealias RemoteStore = [CloudBackup.WalletId: CloudBackup.WalletPublicInfo]

    let converter: CloudBackupFileModelConverting

    init(converter: CloudBackupFileModelConverting) {
        self.converter = converter
    }

    private func findAllNew(for localStore: LocalStore, remoteStore: RemoteStore) throws -> Set<CloudBackupChange> {
        try remoteStore.reduce(into: Set<CloudBackupChange>()) { accum, keyValue in
            guard
                localStore[keyValue.key] == nil,
                let wallet = try converter.convertFromPublicInfo(models: [keyValue.value]).first else {
                return
            }

            accum.insert(.new(remote: wallet))
        }
    }

    private func findAllDeleted(for localStore: LocalStore, remoteStore: RemoteStore) -> Set<CloudBackupChange> {
        localStore.reduce(into: Set<CloudBackupChange>()) { accum, keyValue in
            guard remoteStore[keyValue.key] == nil else {
                return
            }

            accum.insert(.delete(local: keyValue.value))
        }
    }

    private func findAllMainAccountsUpdated(
        for localStore: LocalStore,
        remoteStore: RemoteStore
    ) throws -> Set<CloudBackupChange> {
        try localStore.reduce(into: Set<CloudBackupChange>()) { accum, keyValue in
            guard
                let remoteInfo = remoteStore[keyValue.key],
                let remoteWallet = try converter.convertFromPublicInfo(models: [remoteInfo]).first else {
                return
            }

            let isSubstrateChanged = keyValue.value.substrateAccountId != remoteWallet.substrateAccountId
            let isEthereumChanged = keyValue.value.ethereumAddress != remoteWallet.ethereumAddress

            guard isSubstrateChanged || isEthereumChanged else {
                return
            }

            accum.insert(.updatedMainAccounts(local: keyValue.value, remote: remoteWallet))
        }
    }

    private func findAllMetadataUpdated(
        for localStore: LocalStore,
        remoteStore: RemoteStore
    ) throws -> Set<CloudBackupChange> {
        try localStore.reduce(into: Set<CloudBackupChange>()) { accum, keyValue in
            guard
                let remoteInfo = remoteStore[keyValue.key],
                let remoteWallet = try converter.convertFromPublicInfo(models: [remoteInfo]).first,
                keyValue.value.name != remoteWallet.name else {
                return
            }

            accum.insert(.updatedMetadata(local: keyValue.value, remote: remoteWallet))
        }
    }

    private func findChainAccountsDiff(
        between local: MetaAccountModel,
        remote: MetaAccountModel
    ) -> Set<CloudBackupChainAccountChange> {
        let localByChainId = local.chainAccounts.reduce(into: [String: ChainAccountModel]()) { accum, chainAccount in
            accum[chainAccount.chainId] = chainAccount
        }

        let remoteByChainId = remote.chainAccounts.reduce(into: [String: ChainAccountModel]()) { accum, chainAccount in
            accum[chainAccount.chainId] = chainAccount
        }

        let newOrUpdatedAccounts = remoteByChainId.reduce(
            into: Set<CloudBackupChainAccountChange>()
        ) { accum, keyValue in
            guard let localAccount = localByChainId[keyValue.key] else {
                accum.insert(.new(remote: keyValue.value))
                return
            }

            if localAccount != keyValue.value {
                accum.insert(.update(local: localAccount, remote: keyValue.value))
            }
        }

        return localByChainId.reduce(into: newOrUpdatedAccounts) { accum, keyValue in
            guard remoteByChainId[keyValue.key] == nil else {
                return
            }

            accum.insert(.delete(local: keyValue.value))
        }
    }

    private func findAllChainAccountChanged(
        for localStore: LocalStore,
        remoteStore: RemoteStore
    ) throws -> Set<CloudBackupChange> {
        try localStore.reduce(into: Set<CloudBackupChange>()) { accum, keyValue in
            guard
                let remoteInfo = remoteStore[keyValue.key],
                let remoteWallet = try converter.convertFromPublicInfo(models: [remoteInfo]).first,
                keyValue.value.chainAccounts != remoteWallet.chainAccounts else {
                return
            }

            let chainAccountChanges = findChainAccountsDiff(between: keyValue.value, remote: remoteWallet)
            let change = CloudBackupChange.updatedChainAccounts(
                local: keyValue.value,
                remote: remoteWallet,
                changes: chainAccountChanges
            )

            accum.insert(change)
        }
    }
}

extension CloudBackupDiffCalculator: CloudBackupDiffCalculating {
    func calculateBetween(
        wallets: Set<MetaAccountModel>,
        publicBackupInfo: CloudBackup.PublicData
    ) throws -> Set<CloudBackupChange> {
        let localStore = wallets.reduce(into: LocalStore()) { accum, wallet in
            accum[wallet.metaId] = wallet
        }

        let remoteStore = publicBackupInfo.wallets.reduce(into: RemoteStore()) { accum, info in
            accum[info.walletId] = info
        }

        let newChanges = try findAllNew(for: localStore, remoteStore: remoteStore)
        let deleteChanges = findAllDeleted(for: localStore, remoteStore: remoteStore)
        let mainAccountsUpdateChanges = try findAllMainAccountsUpdated(for: localStore, remoteStore: remoteStore)
        let chainAccountsUpdateChanges = try findAllChainAccountChanged(for: localStore, remoteStore: remoteStore)
        let metadataUpdateChanges = try findAllMetadataUpdated(for: localStore, remoteStore: remoteStore)

        return newChanges
            .union(deleteChanges)
            .union(mainAccountsUpdateChanges)
            .union(chainAccountsUpdateChanges)
            .union(metadataUpdateChanges)
    }
}
