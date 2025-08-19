import Foundation
import Operation_iOS
import Keystore_iOS
import Foundation_iOS
import BigInt

class CommonMultisigHandler: CommonHandler {
    let chainId: ChainModel.Id
    let operationQueue: OperationQueue

    lazy var callFormattingFactory: CallFormattingOperationFactoryProtocol = {
        createCallFormattingOperationFactory(
            chainsRepository: chainsRepository,
            operationQueue: operationQueue
        )
    }()

    init(
        chainId: ChainModel.Id,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.operationQueue = operationQueue

        super.init()
    }

    private func createCallFormattingOperationFactory(
        chainsRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) -> CallFormattingOperationFactoryProtocol {
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem>
        metadataRepository = substrateStorageFacade.createRepository()

        let snapshotFactory = RuntimeDefaultTypesSnapshotFactory(
            repository: AnyDataProviderRepository(metadataRepository),
            runtimeTypeRegistryFactory: RuntimeTypeRegistryFactory(logger: Logger.shared)
        )

        let codingServiceProvider = OfflineRuntimeCodingServiceProvider(
            snapshotFactory: snapshotFactory,
            repository: chainsRepository,
            operationQueue: operationQueue
        )

        return CallFormattingOperationFactory(
            chainProvider: OfflineChainProvider(repository: chainsRepository),
            runtimeCodingServiceProvider: codingServiceProvider,
            walletRepository: walletsRepository(),
            operationQueue: operationQueue
        )
    }

    func createSubtitle(with walletName: String?) -> String {
        if let walletName {
            R.string.localizable.pushNotificationCommonMultisigSubtitle(
                walletName,
                preferredLanguages: locale.rLanguages
            )
        } else {
            ""
        }
    }

    func createBody(
        for formattedCall: FormattedCall,
        adding operationSpecificPart: String
    ) -> String {
        let commonBodyPart: String

        switch formattedCall.definition {
        case let .transfer(transfer):
            let balance = balanceViewModel(
                asset: transfer.asset.asset,
                amount: String(transfer.amount),
                priceData: nil,
                workingQueue: operationQueue
            )

            let destinationAddress = try? transfer.account.accountId.toAddress(using: transfer.asset.chain.chainFormat)

            guard
                let amount = balance?.amount,
                let destinationAddress
            else { return "" }

            commonBodyPart = R.string.localizable.pushNotificationMultisigTransferBody(
                amount,
                destinationAddress.mediumTruncated,
                transfer.asset.chain.name.capitalized,
                preferredLanguages: locale.rLanguages
            )
        case let .general(general):
            commonBodyPart = "\(general.callPath.moduleName): \(general.callPath.callName)."
        }

        let body = [commonBodyPart, operationSpecificPart].joined(with: .space)

        return body
    }
}
