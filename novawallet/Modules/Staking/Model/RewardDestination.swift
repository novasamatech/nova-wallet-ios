import Foundation
import IrohaCrypto

enum RewardDestination<A> {
    case restake
    case payout(account: A)

    var account: A? {
        switch self {
        case .restake:
            return nil
        case let .payout(account):
            return account
        }
    }

    func map<T>(_ closure: (A) -> T) -> RewardDestination<T> {
        switch self {
        case .restake:
            return .restake
        case let .payout(account):
            let mappedAccount = closure(account)
            return .payout(account: mappedAccount)
        }
    }

    func flatMap<T>(_ closure: (A) -> T?) -> RewardDestination<T>? {
        switch self {
        case .restake:
            return .restake
        case let .payout(account):
            if let mappedAccount = closure(account) {
                return .payout(account: mappedAccount)
            } else {
                return nil
            }
        }
    }
}

extension RewardDestination: Equatable where A == AccountAddress {
    init(payee: RewardDestinationArg, stashItem: StashItem, chainFormat: ChainFormat) throws {
        switch payee {
        case .staked:
            self = .restake
        case .stash:
            self = .payout(account: stashItem.stash)
        case .controller:
            self = .payout(account: stashItem.controller)
        case let .account(accountId):
            let address = try accountId.toAddress(using: chainFormat)
            self = .payout(account: address)
        }
    }
}

extension RewardDestination where A == ChainAccountResponse {
    var accountAddress: RewardDestination<AccountAddress>? {
        flatMap { $0.toAddress() }
    }

    var payoutAccount: ChainAccountResponse? { account }
}

extension RewardDestination where A == MetaChainAccountResponse {
    var accountAddress: RewardDestination<AccountAddress>? {
        flatMap { $0.chainAccount.toAddress() }
    }

    var walletDisplay: RewardDestination<WalletDisplayAddress>? {
        flatMap { response in
            guard let address = response.chainAccount.toAddress() else {
                return nil
            }

            return WalletDisplayAddress(
                address: address,
                walletName: response.chainAccount.name,
                walletIconData: response.substrateAccountId
            )
        }
    }

    var payoutAccount: MetaChainAccountResponse? { account }

    var chainPayoutRewardDestination: RewardDestination<ChainAccountResponse> {
        map(\.chainAccount)
    }
}
