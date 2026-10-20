import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol SubtensorShieldExtrinsicFactoryProtocol {
    func createQuoteWrapper(
        for operation: SubtensorOperation,
        innerClosure: @escaping () throws -> ExtrinsicBuilderClosure
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?>

    func createSealedInnerWrapper(
        for innerClosure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
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
    let extrinsicServiceFactory: ExtrinsicTimingServiceFactoryProtocol
    let keyOperationFactory: MevShieldOperationFactoryProtocol
    let nonceOperationFactory: TransactionNonceOperationFactoryProtocol
    let sealer: MevShieldSealing
    let operationQueue: OperationQueue

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        extrinsicServiceFactory: ExtrinsicTimingServiceFactoryProtocol,
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

    func createOperationFactory(nonce: UInt32) -> ExtrinsicOperationFactoryProtocol {
        extrinsicServiceFactory.createOperationFactory(
            account: account,
            chain: chain,
            nonceOperationFactory: PresetNonceOperationFactory(nonce: nonce),
            eraOperationFactory: FixedMortalEraOperationFactory(period: SubtensorShieldConstants.eraPeriod)
        )
    }

    func createNonceWrapper() -> CompoundOperationWrapper<UInt32> {
        nonceOperationFactory.createWrapper(for: chain, connection: connection) { [account] in
            account.accountId
        }
    }
}

private extension SubtensorShieldExtrinsicFactory {
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

    func createSealOperation(
        nonceWrapper: CompoundOperationWrapper<UInt32>,
        innerWrapper: CompoundOperationWrapper<ExtrinsicBuiltModel>,
        keyWrapper: CompoundOperationWrapper<Data?>
    ) -> BaseOperation<SubtensorSealedInner> {
        ClosureOperation { [sealer] in
            let nonce = try nonceWrapper.targetOperation.extractNoCancellableResultData()
            let inner = try Data(hexString: innerWrapper.targetOperation.extractNoCancellableResultData().extrinsic)

            guard let key = try keyWrapper.targetOperation.extractNoCancellableResultData() else {
                throw SubtensorShieldError.keyUnavailable
            }

            // the plaintext is the whole signed inner with its compact length prefix, decoded as an UncheckedExtrinsic
            let ciphertext = try sealer.seal(plaintext: inner, publicKey: key)

            guard ciphertext.count <= MevShieldPallet.maxCiphertextLength else {
                throw SubtensorShieldError.ciphertextTooLong(ciphertext.count)
            }

            return SubtensorSealedInner(
                carrierNonce: nonce,
                extrinsic: inner,
                extrinsicHash: try inner.blake2b32().toHex(includePrefix: true),
                ciphertext: ciphertext
            )
        }
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

    func createSealedInnerWrapper(
        for innerClosure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<SubtensorSealedInner> {
        let nonceWrapper = createNonceWrapper()

        let innerWrapper = OperationCombiningService<ExtrinsicBuiltModel>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let nonce = try nonceWrapper.targetOperation.extractNoCancellableResultData()

            return self.createOperationFactory(nonce: nonce + 1).buildExtrinsic(
                Self.shieldedClosure(innerClosure),
                signer: signer,
                payingFeeIn: nil
            )
        }

        innerWrapper.addDependency(wrapper: nonceWrapper)

        let keyWrapper = keyOperationFactory.createNextKeyWrapper()

        keyWrapper.addDependency(wrapper: innerWrapper)

        let sealOperation = createSealOperation(
            nonceWrapper: nonceWrapper,
            innerWrapper: innerWrapper,
            keyWrapper: keyWrapper
        )

        sealOperation.addDependency(keyWrapper.targetOperation)

        return keyWrapper
            .insertingHead(operations: nonceWrapper.allOperations + innerWrapper.allOperations)
            .insertingTail(operation: sealOperation)
    }

    func createCarrierWrapper(
        for sealedInner: SubtensorSealedInner,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<ExtrinsicBuiltModel> {
        createOperationFactory(nonce: sealedInner.carrierNonce).buildExtrinsic(
            Self.carrierClosure(ciphertext: sealedInner.ciphertext),
            signer: signer,
            payingFeeIn: nil
        )
    }
}
