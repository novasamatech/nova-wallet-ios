import Foundation
import IrohaCrypto
import SoraFoundation
import SubstrateSdk

protocol StakingRewardDetailsViewModelFactoryProtocol {
    func createViewModel(
        input: StakingRewardDetailsInput,
        priceData: PriceData?,
        locale: Locale
    ) throws -> StakingRewardDetailsViewModel
}

final class StakingRewardDetailsViewModelFactory: StakingRewardDetailsViewModelFactoryProtocol {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainFormat: ChainFormat

    private lazy var accountViewModelFactory = DisplayAddressViewModelFactory()
    private lazy var numberFormatter = NumberFormatter.quantity

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainFormat: ChainFormat
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainFormat = chainFormat
    }

    func createViewModel(
        input: StakingRewardDetailsInput,
        priceData: PriceData?,
        locale: Locale
    ) throws -> StakingRewardDetailsViewModel {
        let amountViewModel = balanceViewModelFactory.balanceFromPrice(
            input.payoutInfo.reward,
            priceData: priceData
        ).value(for: locale)

        let validatorViewModel = try createValidatorViewModel(from: input.payoutInfo)

        let eraViewModel = createEraViewModel(from: input.payoutInfo.era, locale: locale)

        return StakingRewardDetailsViewModel(
            amount: amountViewModel,
            validator: validatorViewModel,
            era: eraViewModel
        )
    }

    private func createValidatorViewModel(from payoutInfo: PayoutInfo) throws -> StackCellViewModel {
        let validator = DisplayAddress(
            address: try payoutInfo.validator.toAddress(using: chainFormat),
            username: payoutInfo.identity?.displayName ?? ""
        )

        return accountViewModelFactory.createViewModel(from: validator).cellViewModel
    }

    private func createEraViewModel(from index: EraIndex, locale: Locale) -> StackCellViewModel {
        let details: String

        if let stringIndex = numberFormatter.string(from: NSNumber(value: index)) {
            details = R.string.localizable.commonEraFormat(stringIndex, preferredLanguages: locale.rLanguages)
        } else {
            details = ""
        }

        return StackCellViewModel(details: details, imageViewModel: nil)
    }
}
