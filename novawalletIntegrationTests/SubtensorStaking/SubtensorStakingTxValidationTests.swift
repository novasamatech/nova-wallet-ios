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

    func testSubnetBuySignaturePassesValidation() {
        do {
            let validity = try performValidation(
                of: .subnetBuy(hotkey: hotkeys[0], netuid: netuid, grossTao: amount, limitPrice: limitPrice)
            )

            Logger.shared.info("Subnet buy validity: \(validity)")

            XCTAssertEqual(validity, unfundedSignerRejection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSubnetSellSignaturePassesValidation() {
        do {
            let validity = try performValidation(
                of: .subnetSell(
                    hotkey: hotkeys[0],
                    netuid: netuid,
                    alpha: amount,
                    limitPrice: limitPrice,
                    quotedTaoOut: amount
                )
            )

            Logger.shared.info("Subnet sell validity: \(validity)")

            XCTAssertEqual(validity, unfundedSignerRejection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSubnetSellAllOverThreeHotkeysSignaturePassesValidation() {
        do {
            let validity = try performValidation(
                of: .subnetSellAll(hotkeys: hotkeys, netuid: netuid, limitPrice: limitPrice, quotedTaoOut: amount)
            )

            Logger.shared.info("Subnet sell all validity: \(validity)")

            XCTAssertEqual(validity, unfundedSignerRejection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRootStakeSignaturePassesValidation() {
        do {
            let validity = try performValidation(of: .rootStake(hotkey: hotkeys[0], amount: amount))

            Logger.shared.info("Root stake validity: \(validity)")

            XCTAssertEqual(validity, unfundedSignerRejection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRootUnstakeSignaturePassesValidation() {
        do {
            let validity = try performValidation(of: .rootUnstake(hotkey: hotkeys[0], amount: amount))

            Logger.shared.info("Root unstake validity: \(validity)")

            XCTAssertEqual(validity, unfundedSignerRejection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRootUnstakeAllOverTwoHotkeysSignaturePassesValidation() {
        do {
            let validity = try performValidation(of: .rootUnstakeAll(hotkeys: Array(hotkeys.prefix(2))))

            Logger.shared.info("Root unstake all validity: \(validity)")

            XCTAssertEqual(validity, unfundedSignerRejection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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
