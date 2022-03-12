import Foundation
import SoraFoundation

protocol OperationDetailsViewModelFactoryProtocol {
    func createViewModel(
        from model: OperationDetailsModel,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> OperationDetailsViewModel
}

final class OperationDetailsViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dateFormatter: LocalizableResource<DateFormatter> = DateFormatter.txDetails,
        networkViewModelFactory: NetworkViewModelFactoryProtocol = NetworkViewModelFactory(),
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol =
            DisplayAddressViewModelFactory(),
        quantityFormatter: LocalizableResource<NumberFormatter> =
            NumberFormatter.quantity.localizableResource()
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dateFormatter = dateFormatter
        self.networkViewModelFactory = networkViewModelFactory
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.quantityFormatter = quantityFormatter
    }

    private func createTransferViewModel(
        from model: OperationTransferModel,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> OperationTransferViewModel {
        let amountString = Decimal.fromSubstrateAmount(
            model.amount,
            precision: assetInfo.assetPrecision
        ).map { amount in
            balanceViewModelFactory.amountFromValue(amount).value(for: locale)
        } ?? ""

        let feeString = Decimal.fromSubstrateAmount(
            model.fee,
            precision: assetInfo.assetPrecision
        ).map { amount in
            balanceViewModelFactory.amountFromValue(amount).value(for: locale)
        } ?? ""

        let sender = displayAddressViewModelFactory.createViewModel(from: model.sender)
        let recepient = displayAddressViewModelFactory.createViewModel(from: model.receiver)

        return OperationTransferViewModel(
            amount: amountString,
            fee: feeString,
            isOutgoing: model.outgoing,
            sender: sender,
            recepient: recepient,
            transactionHash: model.txHash
        )
    }

    private func createExtrinsicViewModel(
        from model: OperationExtrinsicModel,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> OperationExtrinsicViewModel {
        let feeString = Decimal.fromSubstrateAmount(
            model.fee,
            precision: assetInfo.assetPrecision
        ).map { amount in
            balanceViewModelFactory.amountFromValue(amount).value(for: locale)
        } ?? ""

        let sender = displayAddressViewModelFactory.createViewModel(from: model.sender)

        return OperationExtrinsicViewModel(
            fee: feeString,
            sender: sender,
            transactionHash: model.txHash,
            module: model.module.displayModule,
            call: model.call.displayCall
        )
    }

    private func createRewardViewModel(
        from model: OperationRewardModel,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> OperationRewardViewModel {
        let amountString = Decimal.fromSubstrateAmount(
            model.amount,
            precision: assetInfo.assetPrecision
        ).map { amount in
            balanceViewModelFactory.amountFromValue(amount).value(for: locale)
        } ?? ""

        let validatorViewModel = model.validator.map { model in
            displayAddressViewModelFactory.createViewModel(from: model)
        }

        let eraString: String? = model.era.map { era in
            if let eraString = quantityFormatter.value(for: locale)
                .string(from: NSNumber(value: era)) {
                return R.string.localizable.commonEraFormat(
                    eraString,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                return ""
            }
        }

        return OperationRewardViewModel(
            eventId: model.eventId,
            amount: amountString,
            validator: validatorViewModel,
            era: eraString
        )
    }

    private func createSlashViewModel(
        from model: OperationSlashModel,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> OperationSlashViewModel {
        let amountString = Decimal.fromSubstrateAmount(
            model.amount,
            precision: assetInfo.assetPrecision
        ).map { amount in
            balanceViewModelFactory.amountFromValue(amount).value(for: locale)
        } ?? ""

        let validatorViewModel = model.validator.map { model in
            displayAddressViewModelFactory.createViewModel(from: model)
        }

        let eraString: String? = model.era.map { era in
            if let eraString = quantityFormatter.value(for: locale)
                .string(from: NSNumber(value: era)) {
                return R.string.localizable.commonEraFormat(
                    eraString,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                return ""
            }
        }

        return OperationSlashViewModel(
            eventId: model.eventId,
            amount: amountString,
            validator: validatorViewModel,
            era: eraString
        )
    }

    private func createContentViewModel(
        from data: OperationDetailsModel.OperationData,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> OperationDetailsViewModel.ContentViewModel {
        switch data {
        case let .transfer(model):
            let viewModel = createTransferViewModel(
                from: model,
                assetInfo: assetInfo,
                locale: locale
            )

            return .transfer(viewModel)
        case let .extrinsic(model):
            let viewModel = createExtrinsicViewModel(
                from: model,
                assetInfo: assetInfo,
                locale: locale
            )

            return .extrinsic(viewModel)
        case let .reward(model):
            let viewModel = createRewardViewModel(
                from: model,
                assetInfo: assetInfo,
                locale: locale
            )

            return .reward(viewModel)
        case let .slash(model):
            let viewModel = createSlashViewModel(
                from: model,
                assetInfo: assetInfo,
                locale: locale
            )

            return .slash(viewModel)
        }
    }
}

extension OperationDetailsViewModelFactory: OperationDetailsViewModelFactoryProtocol {
    func createViewModel(
        from model: OperationDetailsModel,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> OperationDetailsViewModel {
        let timeString = dateFormatter.value(for: locale).string(from: model.time)
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        let contentViewModel = createContentViewModel(
            from: model.operation,
            assetInfo: chainAsset.assetDisplayInfo,
            locale: locale
        )

        return OperationDetailsViewModel(
            time: timeString,
            status: model.status,
            networkViewModel: networkViewModel,
            content: contentViewModel
        )
    }
}
