import Foundation
import RobinHood
import SubstrateSdk
import BigInt

extension DAppOperationConfirmInteractor {
    func createEraParsingOperation(
        dependingOn extrinsicOperation: BaseOperation<PolkadotExtensionExtrinsic>
    ) -> BaseOperation<Era> {
        ClosureOperation {
            let extrinsic = try extrinsicOperation.extractNoCancellableResultData()

            let eraData = try Data(hexString: extrinsic.era)

            let eraDecoder = try ScaleDecoder(data: eraData)

            return try Era(scaleDecoder: eraDecoder)
        }
    }

    func createCallParsingOperation(
        dependingOn extrinsicOperation: BaseOperation<PolkadotExtensionExtrinsic>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<DAppParsedCall> {
        ClosureOperation {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let extrinsic = try extrinsicOperation.extractNoCancellableResultData()

            let methodData = try Data(hexString: extrinsic.method)

            let methodDecoder = try codingFactory.createDecoder(from: methodData)

            if let callableMethod: RuntimeCall<JSON> = try? methodDecoder.read(
                of: KnownType.call.name,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            ) {
                return .callable(value: callableMethod)
            } else {
                return .raw(bytes: methodData)
            }
        }
    }

    // swiftlint:disable:next function_body_length
    func createParsedExtrinsicOperation(
        wallet: MetaAccountModel,
        chain: ChainModel,
        dependingOn extrinsicOperation: BaseOperation<PolkadotExtensionExtrinsic>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<DAppOperationProcessedResult> {
        let callOperation = createCallParsingOperation(
            dependingOn: extrinsicOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        let eraOperation = createEraParsingOperation(dependingOn: extrinsicOperation)

        let resultOperation = ClosureOperation<DAppOperationProcessedResult> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let extrinsic = try extrinsicOperation.extractNoCancellableResultData()

            guard
                let accountResponse = wallet.fetch(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let accountAddress = try accountResponse.accountId.toAddress(using: accountResponse.chainFormat)

            guard accountAddress == extrinsic.address else {
                throw DAppOperationConfirmInteractorError.addressMismatch(
                    actual: extrinsic.address,
                    expected: accountAddress
                )
            }

            guard
                let specVersion = BigUInt.fromHexString(extrinsic.specVersion),
                codingFactory.specVersion == specVersion else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "specVersion")
            }

            guard
                let transactionVersion = BigUInt.fromHexString(extrinsic.transactionVersion),
                codingFactory.txVersion == transactionVersion else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "transactionVersion")
            }

            guard let tip = BigUInt.fromHexString(extrinsic.tip) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "tip")
            }

            guard let nonce = BigUInt.fromHexString(extrinsic.nonce) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "nonce")
            }

            guard let blockNumber = BigUInt.fromHexString(extrinsic.blockNumber) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "blockNumber")
            }

            let expectedSignedExtensions = codingFactory.metadata.getSignedExtensions()

            guard expectedSignedExtensions == extrinsic.signedExtensions else {
                throw DAppOperationConfirmInteractorError.signedExtensionsMismatch(
                    actual: extrinsic.signedExtensions,
                    expected: expectedSignedExtensions
                )
            }

            guard let method = try? callOperation.extractNoCancellableResultData() else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "method")
            }

            guard let era = try? eraOperation.extractNoCancellableResultData() else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "era")
            }

            let parsedExtrinsic = DAppParsedExtrinsic(
                address: extrinsic.address,
                blockHash: extrinsic.blockHash,
                blockNumber: blockNumber,
                era: era,
                genesisHash: extrinsic.genesisHash,
                method: method,
                nonce: nonce,
                specVersion: UInt32(specVersion),
                tip: tip,
                transactionVersion: UInt32(transactionVersion),
                signedExtensions: expectedSignedExtensions,
                version: extrinsic.version
            )

            return DAppOperationProcessedResult(account: accountResponse, extrinsic: parsedExtrinsic)
        }

        let dependencies = [eraOperation, callOperation]

        dependencies.forEach { resultOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: resultOperation, dependencies: dependencies)
    }
}
