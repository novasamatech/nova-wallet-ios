import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol SubtensorShieldExtrinsicFactoryProtocol {
    func createQuoteWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping () throws -> ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?>

    func createUnkeyedQuoteWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?>

    func createKeyWrapper(
        keyRetry: SubtensorShieldKeyRetry,
        retryCondition: BaseOperation<Bool>
    ) -> CompoundOperationWrapper<Data?>

    func createSealedInnerWrapper(
        for innerClosure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        authorization: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<SubtensorSealedInner>

    func createCarrierWrapper(
        for sealedInner: SubtensorSealedInner,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<ExtrinsicBuiltModel>

    func createNonceWrapper() -> CompoundOperationWrapper<UInt32>
}

final class SubtensorShieldExtrinsicFactory {
    let account: ChainAccountResponse
    let chain: ChainModel
    let connection: JSONRPCEngine
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let keyOperationFactory: MevShieldOperationFactoryProtocol
    let nonceOperationFactory: TransactionNonceOperationFactoryProtocol
    let sealer: MevShieldSealing
    let operationQueue: OperationQueue

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        keyOperationFactory: MevShieldOperationFactoryProtocol,
        sealer: MevShieldSealing,
        operationQueue: OperationQueue,
        nonceOperationFactory: TransactionNonceOperationFactoryProtocol = TransactionNonceOperationFactory()
    ) {
        self.account = account
        self.chain = chain
        self.connection = connection
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.keyOperationFactory = keyOperationFactory
        self.sealer = sealer
        self.operationQueue = operationQueue
        self.nonceOperationFactory = nonceOperationFactory
    }
}

extension SubtensorShieldExtrinsicFactory {
    static func shieldedClosure(_ closure: @escaping ExtrinsicBuilderClosure) -> ExtrinsicBuilderClosure {
        { builder in
            try closure(builder.with(tip: 0))
        }
    }

    static func carrierClosure(ciphertext: Data) -> ExtrinsicBuilderClosure {
        shieldedClosure { builder in
            // the carrier must stay a top-level MevShield.submit_encrypted: a proxied or batched one is never decrypted
            try builder.adding(call: MevShieldPallet.SubmitEncryptedCall(ciphertext: ciphertext).runtimeCall())
        }
    }

    func createOperationFactory(
        nonce: UInt32,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol = FixedMortalEraOperationFactory(
            period: SubtensorShieldConstants.eraPeriod
        )
    ) -> ExtrinsicOperationFactoryProtocol {
        extrinsicServiceFactory.createOperationFactory(
            account: account,
            chain: chain,
            extensions: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId).createExtensions(),
            nonceOperationFactory: PresetNonceOperationFactory(nonce: nonce),
            eraOperationFactory: eraOperationFactory
        )
    }

    func createEraWrapper() -> CompoundOperationWrapper<ExtrinsicEraParameters> {
        FixedMortalEraOperationFactory(period: SubtensorShieldConstants.eraPeriod).createParametersWrapper(
            from: connection
        )
    }

    func createNonceWrapper() -> CompoundOperationWrapper<UInt32> {
        nonceOperationFactory.createWrapper(for: chain, connection: connection) { [account] in
            account.accountId
        }
    }
}

private extension SubtensorShieldExtrinsicFactory {
    enum Constants {
        static let keyReadRetries = 2
    }

    static func createDelayOperation(for interval: TimeInterval) -> BaseOperation<Void> {
        AsyncClosureOperation { completion in
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + interval) {
                completion(.success(()))
            }
        }
    }

    func createKeyWrapper(
        retries: Int,
        keyRetry: SubtensorShieldKeyRetry,
        retryCondition: BaseOperation<Bool>
    ) -> CompoundOperationWrapper<Data?> {
        let keyWrapper = keyOperationFactory.createNextKeyWrapper()

        guard retries > 0 else {
            return keyWrapper
        }

        let retryWrapper = OperationCombiningService<Data>.compoundOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            if let key = try keyWrapper.targetOperation.extractNoCancellableResultData() {
                return .createWithResult(key)
            }

            guard try retryCondition.extractNoCancellableResultData() else {
                return nil
            }

            let delayOperation = Self.createDelayOperation(for: keyRetry.interval)
            let nextWrapper = self.createKeyWrapper(
                retries: retries - 1,
                keyRetry: keyRetry,
                retryCondition: retryCondition
            )

            nextWrapper.addDependency(operations: [delayOperation])

            return nextWrapper.insertingHead(operations: [delayOperation])
        }

        retryWrapper.addDependency(wrapper: keyWrapper)
        retryWrapper.addDependency(operations: [retryCondition])

        return retryWrapper.insertingHead(operations: keyWrapper.allOperations)
    }

    func createQuoteWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping ExtrinsicBuilderClosure,
        nonce: UInt32
    ) throws -> CompoundOperationWrapper<SubtensorShieldQuote?> {
        let innerOperationFactory = createOperationFactory(nonce: nonce + 1)
        let shieldedInnerClosure = Self.shieldedClosure(innerClosure)

        let innerWrapper = innerOperationFactory.buildExtrinsic(
            shieldedInnerClosure,
            signer: try DummySigner(cryptoType: account.cryptoType),
            payingFeeIn: nil
        )

        let innerFeeWrapper = innerOperationFactory.estimateFeeOperation(shieldedInnerClosure)

        let carrierFeeWrapper = OperationCombiningService<ExtrinsicFeeProtocol>.compoundWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let inner = try Data(hexString: innerWrapper.targetOperation.extractNoCancellableResultData().extrinsic)
            let ciphertextLength = MevShieldPallet.ciphertextLength(forPlaintextLength: inner.count)

            guard ciphertextLength <= MevShieldPallet.maxCiphertextLength else {
                return nil
            }

            return self.createOperationFactory(nonce: nonce).estimateFeeOperation(
                Self.carrierClosure(ciphertext: Data(count: ciphertextLength))
            )
        }

        carrierFeeWrapper.addDependency(wrapper: innerWrapper)

        let quoteOperation = ClosureOperation<SubtensorShieldQuote?> {
            let innerFee = try innerFeeWrapper.targetOperation.extractNoCancellableResultData()

            guard let carrierFee = try carrierFeeWrapper.targetOperation.extractNoCancellableResultData() else {
                return nil
            }

            return SubtensorShieldQuote(operation: operation, innerFee: innerFee, carrierFee: carrierFee)
        }

        quoteOperation.addDependency(innerFeeWrapper.targetOperation)
        quoteOperation.addDependency(carrierFeeWrapper.targetOperation)

        return carrierFeeWrapper
            .insertingHead(operations: innerWrapper.allOperations + innerFeeWrapper.allOperations)
            .insertingTail(operation: quoteOperation)
    }

    struct Timing {
        let nonce: UInt32
        let era: ExtrinsicEraParameters
    }

    func createTimingWrapper(
        after authorizationOperation: BaseOperation<Void>
    ) -> CompoundOperationWrapper<Timing> {
        let timingWrapper = OperationCombiningService<Timing>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            try authorizationOperation.extractNoCancellableResultData()

            let nonceWrapper = self.createNonceWrapper()
            let eraWrapper = self.createEraWrapper()

            let timingOperation = ClosureOperation<Timing> {
                Timing(
                    nonce: try nonceWrapper.targetOperation.extractNoCancellableResultData(),
                    era: try eraWrapper.targetOperation.extractNoCancellableResultData()
                )
            }

            timingOperation.addDependency(nonceWrapper.targetOperation)
            timingOperation.addDependency(eraWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: timingOperation,
                dependencies: nonceWrapper.allOperations + eraWrapper.allOperations
            )
        }

        timingWrapper.addDependency(operations: [authorizationOperation])

        return timingWrapper
    }

    func createSealWrapper(
        timing: Timing,
        inner: Data
    ) -> CompoundOperationWrapper<SubtensorSealedInner> {
        let keyWrapper = keyOperationFactory.createNextKeyWrapper()

        let sealOperation = ClosureOperation<SubtensorSealedInner> { [sealer] in
            guard let key = try keyWrapper.targetOperation.extractNoCancellableResultData() else {
                throw SubtensorShieldError.keyUnavailable
            }

            // the plaintext is the whole signed inner with its compact length prefix, decoded as an UncheckedExtrinsic
            let ciphertext = try sealer.seal(plaintext: inner, publicKey: key)

            return SubtensorSealedInner(
                carrierNonce: timing.nonce,
                era: timing.era,
                extrinsic: inner,
                extrinsicHash: try inner.blake2b32().toHex(includePrefix: true),
                ciphertext: ciphertext
            )
        }

        sealOperation.addDependency(keyWrapper.targetOperation)

        return keyWrapper.insertingTail(operation: sealOperation)
    }
}

extension SubtensorShieldExtrinsicFactory: SubtensorShieldExtrinsicFactoryProtocol {
    func createQuoteWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping () throws -> ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?> {
        let keyWrapper = keyOperationFactory.createNextKeyWrapper()
        let nonceWrapper = createNonceWrapper()

        let quoteWrapper = OperationCombiningService<SubtensorShieldQuote>.compoundOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            guard try keyWrapper.targetOperation.extractNoCancellableResultData() != nil else {
                return nil
            }

            let nonce = try nonceWrapper.targetOperation.extractNoCancellableResultData()

            return try self.createQuoteWrapper(for: operation, innerClosure: innerClosure(), nonce: nonce)
        }

        quoteWrapper.addDependency(wrapper: keyWrapper)
        quoteWrapper.addDependency(wrapper: nonceWrapper)

        return quoteWrapper.insertingHead(operations: keyWrapper.allOperations + nonceWrapper.allOperations)
    }

    func createUnkeyedQuoteWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?> {
        let nonceWrapper = createNonceWrapper()

        let quoteWrapper = OperationCombiningService<SubtensorShieldQuote>.compoundOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let nonce = try nonceWrapper.targetOperation.extractNoCancellableResultData()

            return try self.createQuoteWrapper(for: operation, innerClosure: innerClosure, nonce: nonce)
        }

        quoteWrapper.addDependency(wrapper: nonceWrapper)

        return quoteWrapper.insertingHead(operations: nonceWrapper.allOperations)
    }

    func createKeyWrapper(
        keyRetry: SubtensorShieldKeyRetry,
        retryCondition: BaseOperation<Bool>
    ) -> CompoundOperationWrapper<Data?> {
        createKeyWrapper(retries: Constants.keyReadRetries, keyRetry: keyRetry, retryCondition: retryCondition)
    }

    func createSealedInnerWrapper(
        for innerClosure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        authorization: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<SubtensorSealedInner> {
        let authorizationOperation = ClosureOperation { try authorization() }
        let timingWrapper = createTimingWrapper(after: authorizationOperation)

        let innerWrapper = OperationCombiningService<ExtrinsicBuiltModel>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let timing = try timingWrapper.targetOperation.extractNoCancellableResultData()

            return self.createOperationFactory(
                nonce: timing.nonce + 1,
                eraOperationFactory: PresetEraOperationFactory(parameters: timing.era)
            ).buildExtrinsic(
                Self.shieldedClosure(innerClosure),
                signer: signer,
                payingFeeIn: nil
            )
        }

        innerWrapper.addDependency(wrapper: timingWrapper)

        let sealWrapper = OperationCombiningService<SubtensorSealedInner>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let timing = try timingWrapper.targetOperation.extractNoCancellableResultData()
            let inner = try Data(hexString: innerWrapper.targetOperation.extractNoCancellableResultData().extrinsic)

            return self.createSealWrapper(timing: timing, inner: inner)
        }

        sealWrapper.addDependency(wrapper: innerWrapper)

        return sealWrapper.insertingHead(
            operations: [authorizationOperation] + timingWrapper.allOperations + innerWrapper.allOperations
        )
    }

    func createCarrierWrapper(
        for sealedInner: SubtensorSealedInner,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<ExtrinsicBuiltModel> {
        createOperationFactory(
            nonce: sealedInner.carrierNonce,
            eraOperationFactory: PresetEraOperationFactory(parameters: sealedInner.era)
        ).buildExtrinsic(
            Self.carrierClosure(ciphertext: sealedInner.ciphertext),
            signer: signer,
            payingFeeIn: nil
        )
    }
}
