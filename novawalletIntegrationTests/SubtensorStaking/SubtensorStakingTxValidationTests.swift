import BigInt
import Keystore_iOS
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorStakingTxValidationTests: XCTestCase {
    private let netuid: UInt16 = 64
    private let amount: Balance = 1_000_000_000
    private let limitPrice: Balance = 1_000_000_000
    private let hotkeys: [AccountId] = (UInt8(1) ... 3).map { Data(repeating: $0, count: 32) }

    private let unfundedSignerRejection = JSON.arrayValue([
        .stringValue("Err"),
        .arrayValue([.stringValue("Invalid"), .arrayValue([.stringValue("Payment"), .null])])
    ])

    func testSubnetBuySignaturePassesValidation() throws {
        let validity = try performValidation(
            of: .subnetBuy(hotkey: hotkeys[0], netuid: netuid, grossTao: amount, limitPrice: limitPrice)
        )

        XCTAssertEqual(validity, unfundedSignerRejection)
    }

    func testSubnetSellAllSignaturePassesValidation() throws {
        let validity = try performValidation(
            of: .subnetSellGroup(
                exits: hotkeys,
                partial: nil,
                netuid: netuid,
                limitPrice: limitPrice,
                quotedTaoOut: amount
            )
        )

        XCTAssertEqual(validity, unfundedSignerRejection)
    }

    private func performValidation(of operation: SubtensorStakingOperation) throws -> JSON {
        let chainId = KnowChainId.bittensor
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let operationQueue = OperationQueue()

        return try withExtendedLifetime(chainRegistry) {
            let chainWrapper = chainRegistry.asyncWaitChainWrapper(for: chainId)
            operationQueue.addOperations(chainWrapper.allOperations, waitUntilFinished: true)

            guard
                let chain = try chainWrapper.targetOperation.extractNoCancellableResultData(),
                let connection = chainRegistry.getConnection(for: chainId),
                let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
                throw ChainRegistryError.noChain(chainId)
            }

            let keychain = InMemoryKeychain()
            let userStorageFacade = UserDataStorageTestFacade()
            let settings = SelectedWalletSettings(storageFacade: userStorageFacade, operationQueue: operationQueue)

            try AccountCreationHelper.createMetaAccountFromMnemonic(
                cryptoType: .sr25519,
                keychain: keychain,
                settings: settings
            )

            guard let wallet = settings.value, let account = wallet.fetch(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let signer = SigningWrapper(
                keystore: keychain,
                metaId: wallet.metaId,
                accountResponse: account,
                settingsManager: InMemorySettingsManager()
            )

            let extrinsicOperationFactory = ExtrinsicServiceFactory(
                runtimeRegistry: runtimeProvider,
                engine: connection,
                operationQueue: operationQueue,
                userStorageFacade: userStorageFacade,
                substrateStorageFacade: storageFacade
            ).createOperationFactory(account: account, chain: chain)

            let extrinsicWrapper = try extrinsicOperationFactory.buildExtrinsic(
                operation.extrinsicBuilderClosure(feeCalculator: SubtensorNovaFeeCalculator()),
                signer: signer,
                payingFeeIn: nil
            )

            operationQueue.addOperations(extrinsicWrapper.allOperations, waitUntilFinished: true)

            let extrinsic = try Data(hexString: extrinsicWrapper.targetOperation.extractNoCancellableResultData().extrinsic)

            let blockHashWrapper = BlockHashOperationFactory().createBestBlockHashWrapper(connection: connection)
            operationQueue.addOperations(blockHashWrapper.allOperations, waitUntilFinished: true)

            let blockHash = try blockHashWrapper.targetOperation.extractNoCancellableResultData()

            let validationWrapper: CompoundOperationWrapper<JSON> = StateCallRequestFactory().createWrapper(
                path: StateCallPath(module: "TaggedTransactionQueue", method: "validate_transaction"),
                paramsClosure: { runtimeApi, encoder, _ in
                    try encoder.append(
                        json: .arrayValue([.stringValue("External"), .null]),
                        type: runtimeApi.method.inputs[0].paramType.asTypeId()
                    )
                    try encoder.appendRawData(extrinsic)
                    try encoder.appendRawData(blockHash)
                },
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue,
                at: blockHash.toHex(includePrefix: true)
            )

            operationQueue.addOperations(validationWrapper.allOperations, waitUntilFinished: true)

            return try validationWrapper.targetOperation.extractNoCancellableResultData()
        }
    }
}
