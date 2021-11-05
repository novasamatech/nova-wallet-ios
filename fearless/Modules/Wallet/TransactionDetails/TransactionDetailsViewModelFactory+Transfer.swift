import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

extension TransactionDetailsViewModelFactory {
    func createTransferViewModels(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        guard let address = try? chainAccount.accountId.toAddress(using: chainAccount.chainFormat) else {
            return nil
        }

        var viewModels: [WalletFormViewBindingProtocol] = []

        guard let type = TransactionType(rawValue: data.type), let peerAddress = data.peerName else {
            return viewModels
        }

        populateTransactionId(
            in: &viewModels,
            data: data,
            commandFactory: commandFactory,
            locale: locale
        )

        let (sender, receiver) = type == .incoming ? (peerAddress, address) : (address, peerAddress)

        populateSender(
            in: &viewModels,
            address: sender,
            commandFactory: commandFactory,
            locale: locale
        )
        populateReceiver(
            in: &viewModels,
            address: receiver,
            commandFactory: commandFactory,
            locale: locale
        )

        populateStatus(into: &viewModels, data: data, locale: locale)
        populateTime(into: &viewModels, data: data, locale: locale)
        populateTransferAmount(into: &viewModels, data: data, locale: locale)
        if type != .incoming {
            populateFeeAmount(in: &viewModels, data: data, locale: locale)
        }

        return viewModels
    }

    func createTransferAccessoryViewModel(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        isIncoming: Bool,
        locale: Locale
    ) -> AccessoryViewModelProtocol? {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            return nil
        }

        let title = R.string.localizable.walletTransferTotalTitle(preferredLanguages: locale.rLanguages)

        let totalAmount = isIncoming ? data.amount.decimalValue :
            data.fees.reduce(data.amount.decimalValue) { $0 + $1.amount.decimalValue }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        guard let amount = formatter.value(for: locale).stringFromDecimal(totalAmount) else {
            return nil
        }

        let icon: UIImage?

        if let accountId = try? data.peerName?.toAccountId(using: chainAccount.chainFormat) {
            icon = try? iconGenerator.generateFromAccountId(accountId)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: CGSize(width: 32.0, height: 32.0),
                    contentScale: UIScreen.main.scale
                )
        } else {
            icon = nil
        }

        let receiverInfo = ReceiveInfo(
            accountId: data.peerId,
            assetId: asset.identifier,
            amount: nil,
            details: nil
        )

        let transferPayload = TransferPayload(
            receiveInfo: receiverInfo,
            receiverName: data.peerName ?? ""
        )
        let command = commandFactory.prepareTransfer(with: transferPayload)
        command.presentationStyle = .push(hidesBottomBar: true)

        return TransactionDetailsAccessoryViewModel(
            title: title,
            amount: amount,
            action: data.peerName ?? "",
            icon: icon,
            command: command,
            shouldAllowAction: true
        )
    }

    private func populateTransferAmount(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        populateAmount(
            into: &viewModelList,
            title: title,
            data: data,
            locale: locale
        )
    }

    private func populateSender(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        address: String,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(
            in: &viewModelList,
            title: title,
            address: address,
            commandFactory: commandFactory,
            locale: locale
        )
    }

    private func populateReceiver(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        address: String,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(
            in: &viewModelList,
            title: title,
            address: address,
            commandFactory: commandFactory,
            locale: locale
        )
    }
}
