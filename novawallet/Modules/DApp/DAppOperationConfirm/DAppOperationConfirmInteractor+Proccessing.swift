import Foundation
import Operation_iOS
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

    func createFeeAssetIdOperation(
        dependingOn extrinsicOperation: BaseOperation<PolkadotExtensionExtrinsic>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        chain: ChainModel
    ) -> BaseOperation<DAppParsedAsset?> {
        ClosureOperation {
            let extrinsic = try extrinsicOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            guard let remoteAssetId = extrinsic.assetId else {
                return nil
            }

            guard
                let remoteAsset = try? ChargeAssetTxSerializer.decodeFeeAssetId(
                    remoteAssetId,
                    codingFactory: codingFactory
                ) else {
                return nil
            }

            let localAsset: ChainAsset? = if chain.hasAssetHubFees {
                AssetHubTokensConverter.convertToLocalAsset(
                    for: remoteAsset,
                    on: chain,
                    using: codingFactory
                )
            } else {
                nil
            }

            return DAppParsedAsset(remoteAsset: remoteAsset, localAsset: localAsset)
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

        let feeAssetOperation = createFeeAssetIdOperation(
            dependingOn: extrinsicOperation,
            codingFactoryOperation: codingFactoryOperation,
            chain: chain
        )

        let resultOperation = ClosureOperation<DAppOperationProcessedResult> {
            let extrinsic = try extrinsicOperation.extractNoCancellableResultData()

            guard
                let extrinsicAccountId = try? extrinsic.address.toChainAccountIdOrSubstrateGeneric(
                    using: chain.chainFormat
                ) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "address: \(extrinsic.address)")
            }

            guard let accountResponse = wallet.fetchByAccountId(
                extrinsicAccountId,
                request: chain.accountRequest()
            ) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            guard
                let specVersion = BigUInt.fromHexString(extrinsic.specVersion) else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "specVersion")
            }

            guard
                let transactionVersion = BigUInt.fromHexString(extrinsic.transactionVersion) else {
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

            guard let method = try? callOperation.extractNoCancellableResultData() else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "method")
            }

            guard let era = try? eraOperation.extractNoCancellableResultData() else {
                throw DAppOperationConfirmInteractorError.extrinsicBadField(name: "era")
            }

            let parsedAsset = try feeAssetOperation.extractNoCancellableResultData()

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
                metadataHash: extrinsic.metadataHash,
                assetId: parsedAsset?.remoteAsset,
                withSignedTransaction: extrinsic.withSignedTransaction ?? false,
                signedExtensions: extrinsic.signedExtensions,
                version: extrinsic.version
            )

            return DAppOperationProcessedResult(
                account: accountResponse,
                extrinsic: parsedExtrinsic,
                feeAsset: parsedAsset?.localAsset
            )
        }

        let dependencies = [eraOperation, callOperation, feeAssetOperation]

        dependencies.forEach { resultOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: resultOperation, dependencies: dependencies)
    }
}
