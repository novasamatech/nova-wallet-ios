import XCTest
import Keystore_iOS
import BigInt
import NovaCrypto
@testable import novawallet
import Operation_iOS

class ExtrinsicServiceTests: XCTestCase {
    private func createExtrinsicBuilderClosure(amount: BigUInt) -> ExtrinsicBuilderClosure {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            let call = callFactory.bondExtra(amount: amount)
            _ = try builder.adding(call: call)
            return builder
        }

        return closure
    }

    private func createExtrinsicBuilderClosure(for batch: [Staking.PayoutInfo]) -> ExtrinsicBuilderClosure {
        let closure: ExtrinsicBuilderClosure = { builder in
            try batch.forEach { payout in
                let payoutCall = Staking.PayoutCall.V1(
                    validatorStash: payout.validator,
                    era: payout.era
                ).runtimeCall()

                _ = try builder.adding(call: payoutCall)
            }

            return builder
        }

        return closure
    }

    func testEstimateFeeForBondExtraCall() throws {
        let wallet = AccountGenerator.generateMetaAccount()

        let chainId = KnowChainId.kusama
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let chain = chainRegistry.getChain(for: chainId),
            let account = wallet.fetch(for: chain.accountRequest()),
            let selectedAddress = account.toAddress()
        else {
            throw ChainRegistryError.noChain(chainId)
        }

        let assetPrecision: Int16 = 12

        let senderResolutionFactory = try ExtrinsicSenderResolutionFactoryStub(address: selectedAddress, chain: chain)

        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: chainId)

        let operationQueue = OperationQueue()

        let metadataHashOperationFactory = MetadataHashOperationFactory(
            metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(storageFacade: storageFacade),
            operationQueue: operationQueue
        )

        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeService,
            userStorageFacade: UserDataStorageTestFacade(),
            substrateStorageFacade: storageFacade,
            operationQueue: operationQueue
        )

        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )

        let extrinsicService = ExtrinsicService(
            chain: chain,
            runtimeRegistry: runtimeService,
            senderResolvingFactory: senderResolutionFactory,
            metadataHashOperationFactory: metadataHashOperationFactory,
            nonceOperationFactory: TransactionNonceOperationFactory(),
            feeEstimationRegistry: feeEstimationRegistry,
            extensions: signedExtensionFactory.createExtensions(),
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let feeExpectation = XCTestExpectation()
        let closure = createExtrinsicBuilderClosure(amount: 10)
        extrinsicService.estimateFee(closure, runningIn: .main) { result in
            switch result {
            case let .success(paymentInfo):
                if
                    let fee = Decimal.fromSubstrateAmount(paymentInfo.amount, precision: assetPrecision),
                    fee > 0 {
                    feeExpectation.fulfill()
                } else {
                    XCTFail("Cant parse fee")
                }
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
        }

        wait(for: [feeExpectation], timeout: 10)
    }

    func testEstimateFeeForPayoutRewardsCall() throws {
        let wallet = AccountGenerator.generateMetaAccount()

        let chainId = KnowChainId.kusama
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let chain = chainRegistry.getChain(for: chainId),
            let account = wallet.fetch(for: chain.accountRequest()),
            let selectedAddress = account.toAddress()
        else {
            throw ChainRegistryError.noChain(chainId)
        }

        let selectedAccountId = try selectedAddress.toAccountId()
        let assetPrecision: Int16 = 12

        let senderResolutionFactory = try ExtrinsicSenderResolutionFactoryStub(address: selectedAddress, chain: chain)

        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: chainId)

        let operationQueue = OperationQueue()

        let metadataHashOperationFactory = MetadataHashOperationFactory(
            metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(storageFacade: storageFacade),
            operationQueue: operationQueue
        )

        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeService,
            userStorageFacade: UserDataStorageTestFacade(),
            substrateStorageFacade: storageFacade,
            operationQueue: operationQueue
        )

        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )

        let extrinsicService = ExtrinsicService(
            chain: chain,
            runtimeRegistry: runtimeService,
            senderResolvingFactory: senderResolutionFactory,
            metadataHashOperationFactory: metadataHashOperationFactory,
            nonceOperationFactory: TransactionNonceOperationFactory(),
            feeEstimationRegistry: feeEstimationRegistry,
            extensions: signedExtensionFactory.createExtensions(),
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let feeExpectation = XCTestExpectation()
        let payouts = [
            Staking.PayoutInfo(validator: selectedAccountId, era: 1000, pages: [0], reward: 100.0, identity: nil),
            Staking.PayoutInfo(validator: selectedAccountId, era: 1001, pages: [0], reward: 100.0, identity: nil),
            Staking.PayoutInfo(validator: selectedAccountId, era: 1002, pages: [0], reward: 100.0, identity: nil)
        ]
        let closure = createExtrinsicBuilderClosure(for: payouts)
        extrinsicService.estimateFee(closure, runningIn: .main) { result in
            switch result {
            case let .success(paymentInfo):
                if
                    let fee = Decimal.fromSubstrateAmount(paymentInfo.amount, precision: assetPrecision),
                    fee > 0 {
                    feeExpectation.fulfill()
                } else {
                    XCTFail("Cant parse fee")
                }
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
        }

        wait(for: [feeExpectation], timeout: 20)
    }
}
