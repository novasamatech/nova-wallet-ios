import Foundation
import BigInt

protocol MultisigTxDetailsViewModelFactoryProtocol {
    func createViewModel(
        multisigTxDetails: MultisigTxDetails,
        depositAsset: ChainAsset,
        assetPrice: PriceData?,
        prettifiedJsonString: String?,
        locale: Locale
    ) -> MultisigTxDetailsViewModel

    func createDepositViewModel(
        multisigTxDetails: MultisigTxDetails,
        depositAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) -> MultisigTxDetailsViewModel.SectionField<BalanceViewModelProtocol>
}

final class MultisigTxDetailsViewModelFactory {
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.utilityBalanceViewModelFactory = utilityBalanceViewModelFactory
    }
}

// MARK: - Private

private extension MultisigTxDetailsViewModelFactory {
    func createDepositSection(
        from multisigTxDetails: MultisigTxDetails,
        depositAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) throws -> MultisigTxDetailsViewModel.Section {
        let depositorViewModel = try displayAddressViewModelFactory.createViewModel(
            from: multisigTxDetails.depositor,
            chain: depositAsset.chain
        )
        let depositorField = MultisigTxDetailsViewModel.SectionField(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonDepositor(),
            value: depositorViewModel
        )
        let depositViewModel = createDepositViewModel(
            deposit: multisigTxDetails.depositAmount,
            depositAsset: depositAsset,
            assetPrice: assetPrice,
            locale: locale
        )
        let depositField = MultisigTxDetailsViewModel.SectionField(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonMultisigDeposit(),
            value: depositViewModel
        )
        let sectionModel = MultisigTxDetailsViewModel.Deposit(
            depositor: depositorField,
            deposit: depositField
        )

        return .deposit(sectionModel)
    }

    func createCallDataSection(
        from multisigTxDetails: MultisigTxDetails,
        locale: Locale
    ) -> MultisigTxDetailsViewModel.Section {
        let callHashModel = StackCellViewModel(
            details: multisigTxDetails.callHash.toHexWithPrefix(),
            imageViewModel: nil
        )
        let callHashField = MultisigTxDetailsViewModel.SectionField(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonCallHash(),
            value: callHashModel
        )

        var callDataField: MultisigTxDetailsViewModel.SectionField<StackCellViewModel>?

        if let callData = multisigTxDetails.callData {
            let callDataModel = StackCellViewModel(
                details: callData.toHexWithPrefix(),
                imageViewModel: nil
            )

            callDataField = MultisigTxDetailsViewModel.SectionField(
                title: R.string(preferredLanguages: locale.rLanguages).localizable.commonCallData(),
                value: callDataModel
            )
        }

        let sectionModel = MultisigTxDetailsViewModel.CallData(
            callHash: callHashField,
            callData: callDataField
        )

        return .callData(sectionModel)
    }

    func createCallJSONSection(
        prettifiedJsonString: String?,
        locale: Locale
    ) -> MultisigTxDetailsViewModel.Section? {
        guard let prettifiedJsonString else { return nil }

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.operationDetailsCheckHint()

        let field = MultisigTxDetailsViewModel.SectionField(
            title: title,
            value: prettifiedJsonString
        )

        return .callJson(field)
    }

    func createDepositViewModel(
        deposit: BigUInt,
        depositAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let assetInfo = depositAsset.asset.displayInfo

        let depositDecimal = deposit.decimal(assetInfo: assetInfo)

        let balanceViewModel = utilityBalanceViewModelFactory.balanceFromPrice(
            depositDecimal,
            priceData: assetPrice
        ).value(for: locale)

        return balanceViewModel
    }
}

// MARK: - MultisigTxDetailsViewModelFactoryProtocol

extension MultisigTxDetailsViewModelFactory: MultisigTxDetailsViewModelFactoryProtocol {
    func createViewModel(
        multisigTxDetails: MultisigTxDetails,
        depositAsset: ChainAsset,
        assetPrice: PriceData?,
        prettifiedJsonString: String?,
        locale: Locale
    ) -> MultisigTxDetailsViewModel {
        let depositSection = try? createDepositSection(
            from: multisigTxDetails,
            depositAsset: depositAsset,
            assetPrice: assetPrice,
            locale: locale
        )
        let callDataSection = createCallDataSection(
            from: multisigTxDetails,
            locale: locale
        )
        let callJSONSection = createCallJSONSection(
            prettifiedJsonString: prettifiedJsonString,
            locale: locale
        )
        let sections: [MultisigTxDetailsViewModel.Section] = [
            depositSection,
            callDataSection,
            callJSONSection
        ].compactMap { $0 }

        return MultisigTxDetailsViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonTxDetails(),
            sections: sections
        )
    }

    func createDepositViewModel(
        multisigTxDetails: MultisigTxDetails,
        depositAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) -> MultisigTxDetailsViewModel.SectionField<BalanceViewModelProtocol> {
        let depositViewModel = createDepositViewModel(
            deposit: multisigTxDetails.depositAmount,
            depositAsset: depositAsset,
            assetPrice: assetPrice,
            locale: locale
        )

        return MultisigTxDetailsViewModel.SectionField(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonMultisigDeposit(),
            value: depositViewModel
        )
    }
}
