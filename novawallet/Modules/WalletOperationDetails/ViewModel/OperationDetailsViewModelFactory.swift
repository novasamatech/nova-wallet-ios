import Foundation
import SoraFoundation
import BigInt

protocol OperationDetailsViewModelFactoryProtocol {
    func createViewModel(
        from model: OperationDetailsModel,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> OperationDetailsViewModel
}

final class OperationDetailsViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let feeViewModelFactory: BalanceViewModelFactoryProtocol?
    let dateFormatter: LocalizableResource<DateFormatter>
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        feeViewModelFactory: BalanceViewModelFactoryProtocol?,
        dateFormatter: LocalizableResource<DateFormatter> = DateFormatter.txDetails,
        networkViewModelFactory: NetworkViewModelFactoryProtocol = NetworkViewModelFactory(),
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol =
            DisplayAddressViewModelFactory(),
        quantityFormatter: LocalizableResource<NumberFormatter> =
            NumberFormatter.quantity.localizableResource()
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.feeViewModelFactory = feeViewModelFactory
        self.dateFormatter = dateFormatter
        self.networkViewModelFactory = networkViewModelFactory
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.quantityFormatter = quantityFormatter
    }

    private func createIconViewModel(
        from model: OperationDetailsModel.OperationData,
        assetInfo: AssetBalanceDisplayInfo
    ) -> ImageViewModelProtocol? {
        switch model {
        case let .transfer(data):
            let image = data.outgoing ?
                R.image.iconOutgoingTransfer()! :
                R.image.iconIncomingTransfer()!

            return StaticImageViewModel(image: image)
        case .reward, .slash:
            let image = R.image.iconRewardOperation()!
            return StaticImageViewModel(image: image)
        case .extrinsic:
            if let url = assetInfo.icon {
                return RemoteImageViewModel(url: url)
            } else {
                return nil
            }
        }
    }

    private func createAmount(
        from model: OperationDetailsModel.OperationData,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        let amount: BigUInt
        let prefix: String

        switch model {
        case let .transfer(model):
            amount = model.amount
            prefix = model.outgoing ? "−" : "+"
        case let .extrinsic(model):
            amount = model.fee
            prefix = "−"
        case let .reward(model):
            amount = model.amount
            prefix = "+"
        case let .slash(model):
            amount = model.amount
            prefix = "−"
        }

        return Decimal.fromSubstrateAmount(
            amount,
            precision: assetInfo.assetPrecision
        ).map { amountDecimal in
            let amountString = balanceViewModelFactory.amountFromValue(amountDecimal)
                .value(for: locale)
            return prefix + amountString
        } ?? ""
    }

    private func createTransferViewModel(
        from model: OperationTransferModel,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> OperationTransferViewModel {
        let feeString = Decimal.fromSubstrateAmount(
            model.fee,
            precision: assetInfo.assetPrecision
        ).map { amount in
            let viewModelFactory = feeViewModelFactory ?? balanceViewModelFactory
            return viewModelFactory.amountFromValue(amount).value(for: locale)
        } ?? ""

        let sender = displayAddressViewModelFactory.createViewModel(from: model.sender)
        let recepient = displayAddressViewModelFactory.createViewModel(from: model.receiver)

        return OperationTransferViewModel(
            fee: feeString,
            isOutgoing: model.outgoing,
            sender: sender,
            recepient: recepient,
            transactionHash: model.txHash
        )
    }

    private func createExtrinsicViewModel(
        from model: OperationExtrinsicModel
    ) -> OperationExtrinsicViewModel {
        let sender = displayAddressViewModelFactory.createViewModel(from: model.sender)

        return OperationExtrinsicViewModel(
            sender: sender,
            transactionHash: model.txHash,
            module: model.module.displayModule,
            call: model.call.displayCall
        )
    }

    private func createRewardViewModel(
        from model: OperationRewardModel,
        locale: Locale
    ) -> OperationRewardViewModel {
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
            validator: validatorViewModel,
            era: eraString
        )
    }

    private func createSlashViewModel(
        from model: OperationSlashModel,
        locale: Locale
    ) -> OperationSlashViewModel {
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
            let viewModel = createExtrinsicViewModel(from: model)
            return .extrinsic(viewModel)
        case let .reward(model):
            let viewModel = createRewardViewModel(
                from: model,
                locale: locale
            )

            return .reward(viewModel)
        case let .slash(model):
            let viewModel = createSlashViewModel(
                from: model,
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

        let assetInfo = chainAsset.assetDisplayInfo

        let contentViewModel = createContentViewModel(
            from: model.operation,
            assetInfo: chainAsset.assetDisplayInfo,
            locale: locale
        )

        let amount = createAmount(from: model.operation, assetInfo: assetInfo, locale: locale)

        let iconViewModel = createIconViewModel(from: model.operation, assetInfo: assetInfo)

        return OperationDetailsViewModel(
            time: timeString,
            status: model.status,
            amount: amount,
            networkViewModel: networkViewModel,
            iconViewModel: iconViewModel,
            content: contentViewModel
        )
    }
}
