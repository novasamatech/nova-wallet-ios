import Foundation

extension Web3Alert {
    typealias RemoteWallet = Wallet<Web3Alert.RemoteChainId>
    typealias RemoteNotifications = Web3Alert.Notifications<Set<Web3Alert.RemoteChainId>>

    struct RemoteSettings: Codable, Equatable {
        let pushToken: String
        let updatedAt: Date
        let wallets: [RemoteWallet]
        let notifications: RemoteNotifications

        init(from local: Web3Alert.LocalSettings) {
            pushToken = local.pushToken
            updatedAt = local.updatedAt

            wallets = local.wallets.map { localWallet in
                let chainSpecific: [Web3Alert.RemoteChainId: AccountAddress] = localWallet.model.chainSpecific.reduce(
                    into: [:]
                ) {
                    let remote = Web3Alert.createRemoteChainId(from: $1.key)
                    $0[remote] = $1.value
                }

                return RemoteWallet(
                    baseSubstrate: localWallet.model.baseSubstrate,
                    baseEthereum: localWallet.model.baseEthereum,
                    chainSpecific: chainSpecific
                )
            }

            let closure: (Set<Web3Alert.LocalChainId>) -> Set<Web3Alert.RemoteChainId> = { localSet in
                let remoteItems = localSet.map { Web3Alert.createRemoteChainId(from: $0) }

                return Set(remoteItems)
            }

            notifications = RemoteNotifications(
                stakingReward: local.notifications.stakingReward?.mapConcreteValue { closure($0) },
                tokenSent: local.notifications.tokenSent?.mapConcreteValue { closure($0) },
                tokenReceived: local.notifications.tokenReceived?.mapConcreteValue { closure($0) },
                newMultisig: local.notifications.newMultisig?.mapConcreteValue { closure($0) },
                multisigApproval: local.notifications.multisigApproval?.mapConcreteValue { closure($0) },
                multisigExecuted: local.notifications.multisigExecuted?.mapConcreteValue { closure($0) },
                multisigCancelled: local.notifications.multisigCancelled?.mapConcreteValue { closure($0) }
            )
        }
    }
}
