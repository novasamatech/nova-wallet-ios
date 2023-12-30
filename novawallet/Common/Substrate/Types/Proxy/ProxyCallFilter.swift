import Foundation

protocol ProxyCallFilterProtocol {
    func matches(call: CallCodingPath) -> Bool
}

extension ProxyCallFilter {
    struct ConstantMatches: ProxyCallFilterProtocol {
        let result: Bool

        init(result: Bool) {
            self.result = result
        }

        func matches(call _: CallCodingPath) -> Bool {
            result
        }
    }

    struct MatchesPallet: ProxyCallFilterProtocol {
        let palletPossibleNames: Set<String>

        init(pallet: String) {
            palletPossibleNames = [pallet]
        }

        init(palletPossibleNames: Set<String>) {
            self.palletPossibleNames = palletPossibleNames
        }

        func matches(call: CallCodingPath) -> Bool {
            palletPossibleNames.contains(call.moduleName)
        }
    }

    struct MatchesCall: ProxyCallFilterProtocol {
        let callPath: CallCodingPath

        init(callPath: CallCodingPath) {
            self.callPath = callPath
        }

        func matches(call: CallCodingPath) -> Bool {
            callPath == call
        }
    }

    struct NotMatches: ProxyCallFilterProtocol {
        let innerFilter: ProxyCallFilterProtocol

        init(innerFilter: ProxyCallFilterProtocol) {
            self.innerFilter = innerFilter
        }

        func matches(call: CallCodingPath) -> Bool {
            !innerFilter.matches(call: call)
        }
    }

    struct OrMatches: ProxyCallFilterProtocol {
        let innerFilters: [ProxyCallFilterProtocol]

        init(innerFilters: [ProxyCallFilterProtocol]) {
            self.innerFilters = innerFilters
        }

        func matches(call: CallCodingPath) -> Bool {
            innerFilters.contains { $0.matches(call: call) }
        }
    }
}

enum ProxyCallFilter {
    private static var proxyTypeToFilter: [Proxy.ProxyType: ProxyCallFilterProtocol] {
        [
            Proxy.ProxyType.any: ConstantMatches(result: true),
            Proxy.ProxyType.nonTransfer: NotMatches(
                innerFilter: OrMatches(
                    innerFilters: [
                        MatchesPallet(pallet: BalancesPallet.name),
                        MatchesPallet(pallet: PalletAssets.name),
                        MatchesPallet(pallet: UniquesPallet.name)
                    ]
                )
            ),
            Proxy.ProxyType.governance: OrMatches(
                innerFilters: [
                    MatchesPallet(pallet: ConvictionVoting.name),
                    MatchesPallet(pallet: Referenda.name),
                    MatchesPallet(pallet: Treasury.name),
                    MatchesPallet(pallet: "Bounties"),
                    MatchesPallet(pallet: "ChildBounties"),
                    MatchesPallet(pallet: "Whitelist"),
                    MatchesPallet(pallet: "Democracy")
                ]
            ),
            Proxy.ProxyType.staking: OrMatches(
                innerFilters: [
                    MatchesPallet(pallet: Staking.module),
                    MatchesPallet(pallet: NominationPools.module),
                    MatchesPallet(palletPossibleNames: Set(BagList.possibleModuleNames)),
                    MatchesPallet(pallet: "FastUnstake"),
                    MatchesPallet(pallet: "Session")
                ]
            ),
            Proxy.ProxyType.nominationPools: MatchesPallet(pallet: NominationPools.module),
            Proxy.ProxyType.auction: OrMatches(
                innerFilters: [
                    MatchesPallet(pallet: "Auctions"),
                    MatchesPallet(pallet: "Crowdloan"),
                    MatchesPallet(pallet: "Registrar"),
                    MatchesPallet(pallet: "Slots")
                ]
            ),
            Proxy.ProxyType.cancelProxy: MatchesCall(
                callPath: .init(moduleName: Proxy.moduleName, callName: "reject_announcement")
            ),
            Proxy.ProxyType.identityJudgement: MatchesCall(
                callPath: .init(moduleName: "Identity", callName: "provide_judgement")
            )
        ]
    }

    static func getProxyTypes(for call: CallCodingPath) -> Set<Proxy.ProxyType> {
        let types = proxyTypeToFilter
            .filter { $0.value.matches(call: call) }
            .keys

        return Set(types)
    }
}
