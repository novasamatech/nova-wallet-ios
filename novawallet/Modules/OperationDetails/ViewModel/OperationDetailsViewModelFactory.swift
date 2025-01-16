import Foundation
import Foundation_iOS
import BigInt

protocol OperationDetailsViewModelFactoryProtocol {
    func createViewModel(
        from model: OperationDetailsModel,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> OperationDetailsViewModel
}

final class OperationDetailsViewModelFactory {
    let dateFormatter: LocalizableResource<DateFormatter>
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>
    lazy var poolIconFactory: NominationPoolsIconFactoryProtocol = NominationPoolsIconFactory()
    lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    init(
        dateFormatter: LocalizableResource<DateFormatter> = DateFormatter.txDetails,
        networkViewModelFactory: NetworkViewModelFactoryProtocol = NetworkViewModelFactory(),
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol =
            DisplayAddressViewModelFactory(),
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory(),
        quantityFormatter: LocalizableResource<NumberFormatter> =
            NumberFormatter.quantity.localizableResource(),
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    ) {
        self.dateFormatter = dateFormatter
        self.networkViewModelFactory = networkViewModelFactory
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory
        self.quantityFormatter = quantityFormatter
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
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
        case .reward, .slash, .poolReward, .poolSlash:
            let image = R.image.iconRewardOperation()!
            return StaticImageViewModel(image: image)
        case .extrinsic, .contract:
            return assetIconViewModelFactory.createAssetIconViewModel(
                for: assetInfo.icon?.getPath(),
                with: .white,
                defaultURL: assetInfo.icon?.getURL()
            )
        case .swap:
            let image = R.image.iconSwap()!
            return StaticImageViewModel(image: image)
        }
    }

    private func createAmount(
        from model: OperationDetailsModel.OperationData,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        let amount: BigUInt
        let priceData: PriceData?
        let prefix: String
        var precision = assetInfo.assetPrecision

        switch model {
        case let .transfer(model):
            amount = model.amount
            priceData = model.amountPriceData
            prefix = model.outgoing ? "−" : "+"
        case let .extrinsic(model):
            amount = model.fee
            priceData = model.feePriceData
            prefix = "−"
        case let .contract(model):
            amount = model.fee
            priceData = model.feePriceData
            prefix = "−"
        case let .reward(model):
            amount = model.amount
            priceData = model.priceData
            prefix = "+"
        case let .slash(model):
            amount = model.amount
            priceData = model.priceData
            prefix = "−"
        case let .poolReward(model):
            amount = model.amount
            priceData = model.priceData
            prefix = "+"
        case let .poolSlash(model):
            amount = model.amount
            priceData = model.priceData
            prefix = "-"
        case let .swap(model):
            switch model.direction {
            case .sell:
                amount = model.amountIn
                priceData = model.priceIn
                prefix = "-"
                precision = model.assetIn.displayInfo.assetPrecision
            case .buy:
                amount = model.amountOut
                priceData = model.priceOut
                prefix = "+"
                precision = model.assetOut.displayInfo.assetPrecision
            }
        }

        return Decimal.fromSubstrateAmount(
            amount,
            precision: precision
        ).map { amountDecimal in
            let amountViewModel = balanceViewModelFactoryFacade.balanceFromPrice(
                targetAssetInfo: assetInfo,
                amount: amountDecimal,
                priceData: priceData
            ).value(for: locale)
            return BalanceViewModel(amount: prefix + amountViewModel.amount, price: amountViewModel.price)
        }
    }

    private func createContractViewModel(
        from model: OperationContractCallModel
    ) -> OperationContractCallViewModel {
        let sender = displayAddressViewModelFactory.createViewModel(from: model.sender)
        let contract = displayAddressViewModelFactory.createViewModel(from: model.contract)

        return .init(
            sender: sender,
            transactionHash: model.txHash,
            contract: contract,
            functionName: model.functionName
        )
    }

    private func createTransferViewModel(
        from model: OperationTransferModel,
        feeAssetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> OperationTransferViewModel {
        let fee = Decimal.fromSubstrateAmount(
            model.fee,
            precision: feeAssetInfo.assetPrecision
        ).map { amount in
            balanceViewModelFactoryFacade.balanceFromPrice(
                targetAssetInfo: feeAssetInfo,
                amount: amount,
                priceData: model.feePriceData
            ).value(for: locale)
        }
        let sender = displayAddressViewModelFactory.createViewModel(from: model.sender)
        let recepient = displayAddressViewModelFactory.createViewModel(from: model.receiver)

        return OperationTransferViewModel(
            fee: fee,
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

    private func createRewardOrSlashViewModel(
        from model: OperationRewardOrSlashModel,
        locale: Locale
    ) -> OperationRewardOrSlashViewModel {
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

        return OperationRewardOrSlashViewModel(
            eventId: model.eventId,
            validator: validatorViewModel,
            era: eraString
        )
    }

    private func createPoolRewardOrSlashViewModel(
        from model: OperationPoolRewardOrSlashModel,
        chainAsset: ChainAsset,
        locale _: Locale
    ) -> OperationPoolRewardOrSlashViewModel {
        guard let pool = model.pool else {
            return .init(eventId: model.eventId, pool: nil)
        }

        let poolViewModel = displayAddressViewModelFactory.createViewModel(
            from: pool,
            chainAsset: chainAsset
        )

        return OperationPoolRewardOrSlashViewModel(eventId: model.eventId, pool: poolViewModel)
    }

    private func createSwapViewModel(
        from model: OperationSwapModel,
        locale: Locale
    ) -> OperationSwapViewModel {
        let assetInViewModel = assetViewModel(
            chain: model.chain,
            asset: model.assetIn,
            amount: model.amountIn,
            priceData: model.priceIn,
            locale: locale
        )
        let assetOutViewModel = assetViewModel(
            chain: model.chain,
            asset: model.assetOut,
            amount: model.amountOut,
            priceData: model.priceOut,
            locale: locale
        )
        let rateViewModel = rateViewModel(
            from: .init(
                assetDisplayInfoIn: model.assetIn.displayInfo,
                assetDisplayInfoOut: model.assetOut.displayInfo,
                amountIn: model.amountIn,
                amountOut: model.amountOut
            ),
            locale: locale
        )
        let feeAmountDecimal = Decimal.fromSubstrateAmount(
            model.fee,
            precision: model.feeAsset.displayInfo.assetPrecision
        ) ?? 0
        let feeBalanceViewModel = balanceViewModelFactoryFacade.balanceFromPrice(
            targetAssetInfo: model.feeAsset.displayInfo,
            amount: feeAmountDecimal,
            priceData: model.feePrice
        ).value(for: locale)
        let walletViewModel = try? walletViewModelFactory.createViewModel(from: model.wallet)

        return OperationSwapViewModel(
            direction: model.direction,
            assetIn: assetInViewModel,
            assetOut: assetOutViewModel,
            rate: rateViewModel,
            fee: feeBalanceViewModel,
            wallet: walletViewModel ?? .init(walletName: nil, walletIcon: nil, address: "", addressIcon: nil),
            transactionHash: model.txHash
        )
    }

    private func assetViewModel(
        chain: ChainModel,
        asset: AssetModel,
        amount: BigUInt,
        priceData: PriceData?,
        locale: Locale
    ) -> SwapAssetAmountViewModel {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chain)
        let assetIcon = assetIconViewModelFactory.createAssetIconViewModel(for: asset.icon, with: .white)
        let amountDecimal = Decimal.fromSubstrateAmount(
            amount,
            precision: asset.displayInfo.assetPrecision
        ) ?? 0
        let balanceViewModel = balanceViewModelFactoryFacade.balanceFromPrice(
            targetAssetInfo: asset.displayInfo,
            amount: amountDecimal,
            priceData: priceData
        ).value(for: locale)

        return .init(
            imageViewModel: assetIcon,
            hub: networkViewModel,
            amount: balanceViewModel.amount,
            price: balanceViewModel.price.map { $0.approximately() }
        )
    }

    func rateViewModel(from params: RateParams, locale: Locale) -> String {
        guard
            let amountOutDecimal = Decimal.fromSubstrateAmount(
                params.amountOut,
                precision: params.assetDisplayInfoOut.assetPrecision
            ),
            let amountInDecimal = Decimal.fromSubstrateAmount(
                params.amountIn,
                precision: params.assetDisplayInfoIn.assetPrecision
            ),
            amountInDecimal != 0 else {
            return ""
        }
        let difference = amountOutDecimal / amountInDecimal

        return balanceViewModelFactoryFacade.rateFromValue(
            mainSymbol: params.assetDisplayInfoIn.symbol,
            targetAssetInfo: params.assetDisplayInfoOut,
            value: difference
        ).value(for: locale)
    }

    private func createContentViewModel(
        from data: OperationDetailsModel.OperationData,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> OperationDetailsViewModel.ContentViewModel {
        switch data {
        case let .transfer(model):
            let feeAssetInfo: AssetBalanceDisplayInfo = model.feeAssetId == chainAsset.asset.assetId
                ? chainAsset.assetDisplayInfo
                : chainAsset.chain.utilityAssetDisplayInfo() ?? chainAsset.assetDisplayInfo

            let viewModel = createTransferViewModel(
                from: model,
                feeAssetInfo: feeAssetInfo,
                locale: locale
            )

            return .transfer(viewModel)
        case let .extrinsic(model):
            let viewModel = createExtrinsicViewModel(from: model)
            return .extrinsic(viewModel)
        case let .reward(model):
            let viewModel = createRewardOrSlashViewModel(
                from: model,
                locale: locale
            )

            return .reward(viewModel)
        case let .slash(model):
            let viewModel = createRewardOrSlashViewModel(
                from: model,
                locale: locale
            )

            return .slash(viewModel)
        case let .contract(model):
            let viewModel = createContractViewModel(from: model)
            return .contract(viewModel)
        case let .poolReward(model):
            let viewModel = createPoolRewardOrSlashViewModel(
                from: model,
                chainAsset: chainAsset,
                locale: locale
            )
            return .poolReward(viewModel)
        case let .poolSlash(model):
            let viewModel = createPoolRewardOrSlashViewModel(
                from: model,
                chainAsset: chainAsset,
                locale: locale
            )
            return .poolSlash(viewModel)
        case let .swap(model):
            let viewModel = createSwapViewModel(from: model, locale: locale)
            return .swap(viewModel)
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
            chainAsset: chainAsset,
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
