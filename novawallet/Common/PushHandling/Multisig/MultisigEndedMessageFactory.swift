import Foundation
import Foundation_iOS
import BigInt

protocol MultisigEndedMessageFactoryProtocol {
    func createExecutedMessageModel(
        for formattedCall: FormattedCall,
        chain: ChainModel
    ) -> MultisigEndedMessageModel

    func createExecutedMessageModel(
        for chain: ChainModel
    ) -> MultisigEndedMessageModel

    func createRejectedMessageModel(
        for formattedCall: FormattedCall,
        cancellerAddress: AccountAddress,
        chain: ChainModel
    ) -> MultisigEndedMessageModel

    func createRejectedMessageModel(
        for chain: ChainModel,
        cancellerAddress: AccountAddress
    ) -> MultisigEndedMessageModel
}

final class MultisigEndedMessageFactory {}

// MARK: - Private

private extension MultisigEndedMessageFactory {
    func createFormattedCommonBody(
        from formattedCall: FormattedCall,
        adding operationSpecificPart: LocalizableResource<String>,
        chain: ChainModel
    ) -> LocalizableResource<String> {
        let commonPart: LocalizableResource<String>

        switch formattedCall.definition {
        case let .transfer(transfer):
            commonPart = createTransferBodyContent(for: transfer)
        case let .batch(batch):
            commonPart = createBatchBodyContent(for: batch, chain: chain)
        case let .general(general):
            commonPart = createGeneralBodyContent(for: general, chain: chain)
        }

        guard
            let delegatedAccount = formattedCall.delegatedAccount,
            let delegatedAddress = try? delegatedAccount.accountId.toAddress(using: chain.chainFormat)
        else {
            return createBody(using: commonPart, adding: operationSpecificPart)
        }

        let delegatedCommonPart = createDelegatedCommonPart(
            using: commonPart,
            delegatedAddress: delegatedAddress
        )

        return createBody(using: delegatedCommonPart, adding: operationSpecificPart)
    }

    func createUnformattedExecutedBody(for chain: ChainModel) -> LocalizableResource<String> {
        LocalizableResource { locale in
            [
                R.string.localizable.multisigOperationExecutedNoFormat(
                    chain.name.capitalized,
                    preferredLanguages: locale.rLanguages
                ),
                R.string.localizable.multisigOperationNoActionsRequired(
                    preferredLanguages: locale.rLanguages
                )
            ].joined(with: .newLine)
        }
    }

    func createUnformattedRejectedBody(
        for chain: ChainModel,
        cancellerAddress: AccountAddress
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            [
                R.string.localizable.multisigOperationCancelledNoFormat(
                    chain.name.capitalized,
                    preferredLanguages: locale.rLanguages
                ),
                R.string.localizable.multisigOperationFormatCancelledText(
                    cancellerAddress.mediumTruncated,
                    preferredLanguages: locale.rLanguages
                ),
                R.string.localizable.multisigOperationNoActionsRequired(
                    preferredLanguages: locale.rLanguages
                )
            ].joined(with: .newLine)
        }
    }

    func createExecutedBodySpecificPart() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.multisigOperationNoActionsRequired(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createRejectedBodySpecificPart(cancellerAddress: AccountAddress) -> LocalizableResource<String> {
        LocalizableResource { locale in
            [
                R.string.localizable.multisigOperationFormatCancelledText(
                    cancellerAddress.mediumTruncated,
                    preferredLanguages: locale.rLanguages
                ),
                R.string.localizable.multisigOperationNoActionsRequired(
                    preferredLanguages: locale.rLanguages
                )
            ].joined(with: .newLine)
        }
    }

    func createBody(
        using commonBodyPart: LocalizableResource<String>,
        adding operationSpecificPart: LocalizableResource<String>
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            [
                commonBodyPart.value(for: locale),
                operationSpecificPart.value(for: locale)
            ].joined(with: .newLine)
        }
    }

    func createDelegatedCommonPart(
        using commonPart: LocalizableResource<String>,
        delegatedAddress: String
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            let delegatedAccountPart = [
                R.string.localizable.delegatedAccountOnBehalfOf(preferredLanguages: locale.rLanguages),
                delegatedAddress.mediumTruncated
            ].joined(with: .space)

            let delegatedCommonPart = [
                commonPart.value(for: locale),
                delegatedAccountPart
            ].joined(with: .newLine)

            return delegatedCommonPart
        }
    }

    func createTransferBodyContent(for transfer: FormattedCall.Transfer) -> LocalizableResource<String> {
        LocalizableResource { locale in
            let balance = self.balanceViewModel(
                asset: transfer.asset.asset,
                amount: String(transfer.amount),
                priceData: nil
            )?.value(for: locale)

            let destinationAddress = try? transfer.account.accountId.toAddress(using: transfer.asset.chain.chainFormat)

            guard
                let amount = balance?.amount,
                let destinationAddress
            else { return "" }

            return R.string.localizable.multisigOperationFormatTransferText(
                amount,
                destinationAddress.mediumTruncated,
                transfer.asset.chain.name.capitalized,
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createBatchBodyContent(
        for batch: FormattedCall.Batch,
        chain: ChainModel
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.multisigOperationFormatGeneralText(
                batch.type.fullModuleCallDescription.value(for: locale),
                chain.name.capitalized,
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createGeneralBodyContent(
        for generalDefinition: FormattedCall.General,
        chain: ChainModel
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.multisigOperationFormatGeneralText(
                self.createModuleCallInfo(for: generalDefinition.callPath),
                chain.name.capitalized,
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createModuleCallInfo(for callPath: CallCodingPath) -> String {
        [
            callPath.moduleName.displayModule,
            callPath.callName.displayCall
        ].joined(with: .colonSpace)
    }

    func createExecutedTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.commonMultisigExecuted(preferredLanguages: locale.rLanguages).capitalized
        }
    }

    func createRejectedTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.commonMultisigRejected(preferredLanguages: locale.rLanguages).capitalized
        }
    }

    func balanceViewModel(
        asset: AssetModel,
        amount: String,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        guard
            let currencyManager = CurrencyManager.shared,
            let amountInPlank = BigUInt(amount) else {
            return nil
        }
        let decimalAmount = amountInPlank.decimal(precision: asset.precision)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let factory = PrimitiveBalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formatterFactory: AssetBalanceFormatterFactory()
        )

        return factory.balanceFromPrice(
            decimalAmount,
            priceData: priceData
        )
    }
}

// MARK: - MultisigEndedMessageFactoryProtocol

extension MultisigEndedMessageFactory: MultisigEndedMessageFactoryProtocol {
    func createExecutedMessageModel(
        for formattedCall: FormattedCall,
        chain: ChainModel
    ) -> MultisigEndedMessageModel {
        let title = createExecutedTitle()
        let body = createFormattedCommonBody(
            from: formattedCall,
            adding: createExecutedBodySpecificPart(),
            chain: chain
        )

        return MultisigEndedMessageModel { locale in
            .init(
                title: title.value(for: locale),
                description: body.value(for: locale)
            )
        }
    }

    func createExecutedMessageModel(
        for chain: ChainModel
    ) -> MultisigEndedMessageModel {
        let title = createExecutedTitle()
        let body = createUnformattedExecutedBody(for: chain)

        return MultisigEndedMessageModel { locale in
            .init(
                title: title.value(for: locale),
                description: body.value(for: locale)
            )
        }
    }

    func createRejectedMessageModel(
        for formattedCall: FormattedCall,
        cancellerAddress: AccountAddress,
        chain: ChainModel
    ) -> MultisigEndedMessageModel {
        let title = createRejectedTitle()
        let body = createFormattedCommonBody(
            from: formattedCall,
            adding: createRejectedBodySpecificPart(cancellerAddress: cancellerAddress),
            chain: chain
        )

        return MultisigEndedMessageModel { locale in
            .init(
                title: title.value(for: locale),
                description: body.value(for: locale)
            )
        }
    }

    func createRejectedMessageModel(
        for chain: ChainModel,
        cancellerAddress: AccountAddress
    ) -> MultisigEndedMessageModel {
        let title = createExecutedTitle()
        let body = createUnformattedRejectedBody(for: chain, cancellerAddress: cancellerAddress)

        return MultisigEndedMessageModel { locale in
            .init(
                title: title.value(for: locale),
                description: body.value(for: locale)
            )
        }
    }
}
