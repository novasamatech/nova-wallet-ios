import Foundation
import BigInt

protocol AssetExchangeCommissionPolicyProtocol {
    func hasChargingSite(in path: AssetExchangeGraphPath) -> Bool

    func resolveCommission(for route: AssetExchangeRoute) -> AssetExchangeCommission?

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance
}

extension AssetExchangeCommissionPolicyProtocol {
    func isValid(commission: AssetExchangeCommission?, for route: AssetExchangeRoute) -> Bool {
        resolveCommission(for: route) == commission
    }
}

final class AssetExchangeCommissionPolicy {
    let rate: BigRational

    var rateOfGross: BigRational { rate.asShareOfGross }

    let beneficiary: AccountId

    let assetHubBeneficiaries: [ChainModel.Id: AccountId]

    init(
        rate: BigRational,
        beneficiary: AccountId,
        assetHubBeneficiaries: [ChainModel.Id: AccountId] = [:]
    ) {
        self.rate = rate
        self.beneficiary = beneficiary
        self.assetHubBeneficiaries = assetHubBeneficiaries
    }
}

private extension AssetExchangeCommissionPolicy {
    func beneficiary(for edge: AnyAssetExchangeEdge) -> AccountId? {
        guard edge.origin.chainId == edge.destination.chainId else {
            return nil
        }

        switch edge.type {
        case .hydraSwap:
            return beneficiary
        case .assetHubSwap:
            return assetHubBeneficiaries[edge.destination.chainId]
        case .crossChain:
            return nil
        }
    }

    func findChargingSite(in path: AssetExchangeGraphPath) -> (index: Int, beneficiary: AccountId)? {
        for index in path.indices.reversed() {
            if let beneficiary = beneficiary(for: path[index]) {
                return (index, beneficiary)
            }
        }

        return nil
    }
}

extension AssetExchangeCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func hasChargingSite(in path: AssetExchangeGraphPath) -> Bool {
        findChargingSite(in: path) != nil
    }

    func grossingUpAmountOut(_ netAmountOut: Balance, for path: AssetExchangeGraphPath) -> Balance {
        guard hasChargingSite(in: path) else {
            return netAmountOut
        }

        return netAmountOut + rate.mul(value: netAmountOut)
    }

    func resolveCommission(for route: AssetExchangeRoute) -> AssetExchangeCommission? {
        let path = route.items.map(\.edge)

        guard let site = findChargingSite(in: path) else {
            return nil
        }

        let bound = route.items[site.index].amountOut(for: route.direction)
        let amount = rateOfGross.mul(value: bound)

        guard amount > 0 else {
            return nil
        }

        return AssetExchangeCommission(
            chargingEdgeIndex: site.index,
            asset: route.items[site.index].edge.destination,
            amount: amount,
            beneficiary: site.beneficiary
        )
    }
}

final class AssetExchangeNoCommissionPolicy: AssetExchangeCommissionPolicyProtocol {
    func hasChargingSite(in _: AssetExchangeGraphPath) -> Bool {
        false
    }

    func resolveCommission(for _: AssetExchangeRoute) -> AssetExchangeCommission? {
        nil
    }

    func grossingUpAmountOut(_ netAmountOut: Balance, for _: AssetExchangeGraphPath) -> Balance {
        netAmountOut
    }
}

enum AssetExchangeCommissionPolicyFactory {
    static func createHydrationPolicy(logger: LoggerProtocol) -> AssetExchangeCommissionPolicyProtocol {
        createSwapPolicy(assetHubBeneficiaryAddresses: [:], logger: logger)
    }

    static func createSwapPolicy(
        assetHubBeneficiaryAddresses: [ChainModel.Id: AccountAddress],
        logger: LoggerProtocol
    ) -> AssetExchangeCommissionPolicyProtocol {
        do {
            let hydrationBeneficiary = try AssetExchangeCommissionConstants
                .hydrationBeneficiaryAddress
                .toAccountId()

            let assetHubBeneficiaries = assetHubBeneficiaryAddresses.reduce(
                into: [ChainModel.Id: AccountId]()
            ) { accum, keyValue in
                do {
                    let accountId = try keyValue.value.toAccountId()

                    guard accountId.count == SubstrateConstants.accountIdLength else {
                        throw CommonError.dataCorruption
                    }

                    accum[keyValue.key] = accountId
                } catch {
                    logger.error("Invalid Asset Hub commission beneficiary for \(keyValue.key): \(error)")
                }
            }

            return AssetExchangeCommissionPolicy(
                rate: AssetExchangeCommissionConstants.rate,
                beneficiary: hydrationBeneficiary,
                assetHubBeneficiaries: assetHubBeneficiaries
            )
        } catch {
            logger.error("Invalid commission beneficiary address: \(error)")

            return AssetExchangeNoCommissionPolicy()
        }
    }
}
