import Foundation
import Foundation_iOS
import Operation_iOS
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
        wallets: [MetaAccountModel],
        cancellerAddress: AccountAddress,
        chain: ChainModel
    ) -> MultisigEndedMessageModel

    func createRejectedMessageModel(
        for chain: ChainModel,
        wallets: [MetaAccountModel],
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
            let delegatedNameOrAddress = delegatedAccount.name
            ?? (try? delegatedAccount.accountId.toAddress(using: chain.chainFormat))?.mediumTruncated
        else {
            return createBody(using: commonPart, adding: operationSpecificPart)
        }

        let delegatedCommonPart = createDelegatedCommonPart(
            using: commonPart,
            delegatedAccount: delegatedNameOrAddress
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
        canceller: String
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            [
                R.string.localizable.multisigOperationCancelledNoFormat(
                    chain.name.capitalized,
                    preferredLanguages: locale.rLanguages
                ),
                R.string.localizable.multisigOperationFormatCancelledText(
                    canceller,
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

    func createRejectedBodySpecificPart(canceller: String) -> LocalizableResource<String> {
        LocalizableResource { locale in
            [
                R.string.localizable.multisigOperationFormatCancelledText(
                    canceller,
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
        delegatedAccount: String
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            let delegatedAccountPart = [
                R.string.localizable.delegatedAccountOnBehalfOf(preferredLanguages: locale.rLanguages),
                delegatedAccount
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

            let nameOrAddress = transfer.account.name
                ?? (try? transfer.account.accountId.toAddress(using: transfer.asset.chain.chainFormat).mediumTruncated)

            guard
                let amount = balance?.amount,
                let nameOrAddress
            else { return "" }

            return R.string.localizable.multisigOperationFormatTransferText(
                amount,
                nameOrAddress,
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

    func targetWalletName(
        for address: AccountAddress,
        wallets: [MetaAccountModel],
        chain: ChainModel
    ) -> String {
        guard
            let accountId = try? address.toAccountId(),
            let convertedAddress = try? accountId.toAddress(using: chain.chainFormat)
        else {
            return address
        }

        let chainRequest = chain.accountRequest()

        let name = wallets
            .filter { $0.fetchByAccountId(accountId, request: chainRequest) != nil }
            .sorted { $0.type.signingDelegateOrder < $1.type.signingDelegateOrder }
            .first?.name

        return name ?? convertedAddress.mediumTruncated
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
        wallets: [MetaAccountModel],
        cancellerAddress: AccountAddress,
        chain: ChainModel
    ) -> MultisigEndedMessageModel {
        let title = createRejectedTitle()
        let cancellesNameOrAddress = targetWalletName(
            for: cancellerAddress,
            wallets: wallets,
            chain: chain
        )
        let body = createFormattedCommonBody(
            from: formattedCall,
            adding: createRejectedBodySpecificPart(canceller: cancellesNameOrAddress),
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
        wallets: [MetaAccountModel],
        cancellerAddress: AccountAddress
    ) -> MultisigEndedMessageModel {
        let title = createExecutedTitle()
        let cancellesNameOrAddress = targetWalletName(
            for: cancellerAddress,
            wallets: wallets,
            chain: chain
        )
        let body = createUnformattedRejectedBody(for: chain, canceller: cancellesNameOrAddress)

        return MultisigEndedMessageModel { locale in
            .init(
                title: title.value(for: locale),
                description: body.value(for: locale)
            )
        }
    }
}
