import Foundation
import BigInt
import RobinHood
import SubstrateSdk

enum XcmTransferServiceError: Error {
    case reserveFeeNotAvailable
    case noXcmPalletFound
}

final class XcmTransferService {
    static let weightPerSecond = BigUInt(1_000_000_000_000)

    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private(set) lazy var xcmFactory = XcmTransferFactory()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    func createModuleResolutionWrapper(
        for transferType: XcmAssetTransfer.TransferType,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<String> {
        switch transferType {
        case .xtokens:
            return CompoundOperationWrapper.createWithResult("XTokens")
        case .xcmpallet, .teleport:
            let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let moduleResolutionOperation = ClosureOperation<String> {
                let metadata = try coderFactoryOperation.extractNoCancellableResultData().metadata
                guard let moduleName = Xcm.ExecuteCall.possibleModuleNames.first(
                    where: { metadata.getModuleIndex($0) != nil }
                ) else {
                    throw XcmTransferServiceError.noXcmPalletFound
                }

                return moduleName
            }

            moduleResolutionOperation.addDependency(coderFactoryOperation)

            return CompoundOperationWrapper(
                targetOperation: moduleResolutionOperation,
                dependencies: [coderFactoryOperation]
            )
        case .unknown:
            return CompoundOperationWrapper.createWithError(XcmAssetTransfer.TransferTypeError.unknownType)
        }
    }

    func createOperationFactory(
        for chain: ChainModel,
        chainAccount: ChainAccountResponse?
    ) throws -> ExtrinsicOperationFactoryProtocol {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let accountId: AccountId
        let cryptoType: MultiassetCryptoType
        let signaturePayloadFormat: ExtrinsicSignaturePayloadFormat

        if let chainAccount = chainAccount {
            accountId = chainAccount.accountId
            cryptoType = chainAccount.cryptoType
            signaturePayloadFormat = chainAccount.type.signaturePayloadFormat
        } else {
            // account doesn't exists but we still might want to calculate fee
            accountId = AccountId.zeroAccountId(of: chain.accountIdSize)
            cryptoType = chain.isEthereumBased ? .ethereumEcdsa : .sr25519
            signaturePayloadFormat = .regular
        }

        return ExtrinsicOperationFactory(
            accountId: accountId,
            chain: chain,
            cryptoType: cryptoType,
            signaturePayloadFormat: signaturePayloadFormat,
            runtimeRegistry: runtimeProvider,
            customExtensions: DefaultExtrinsicExtension.extensions,
            engine: connection
        )
    }

    func createStardardFeeEstimationWrapper(
        chain: ChainModel,
        message: Xcm.Message,
        maxWeight: BigUInt
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        do {
            let moduleWrapper = createModuleResolutionWrapper(for: .xcmpallet, runtimeProvider: runtimeProvider)

            let optChainAccount = wallet.fetch(for: chain.accountRequest())
            let operationFactory = try createOperationFactory(for: chain, chainAccount: optChainAccount)

            let wrapper = operationFactory.estimateFeeOperation { builder in
                let moduleName = try moduleWrapper.targetOperation.extractNoCancellableResultData()
                let call = Xcm.ExecuteCall(message: message, maxWeight: maxWeight)
                return try builder.adding(call: call.runtimeCall(for: moduleName))
            }

            wrapper.addDependency(wrapper: moduleWrapper)

            let mapperOperation = ClosureOperation<FeeWithWeight> {
                let response = try wrapper.targetOperation.extractNoCancellableResultData()

                guard let fee = BigUInt(response.fee) else {
                    throw CommonError.dataCorruption
                }

                return FeeWithWeight(fee: fee, weight: BigUInt(response.weight))
            }

            mapperOperation.addDependency(wrapper.targetOperation)

            let dependencies = moduleWrapper.allOperations + wrapper.allOperations

            return CompoundOperationWrapper(targetOperation: mapperOperation, dependencies: dependencies)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createFeeEstimationWrapper(
        for chain: ChainModel,
        message: Xcm.Message,
        info: XcmAssetTransferFee,
        baseWeight: BigUInt
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        let maxWeight = baseWeight * BigUInt(message.instructionsCount)

        switch info.mode.type {
        case .proportional:
            let coefficient: BigUInt = info.mode.value.flatMap { BigUInt($0) } ?? 0
            let fee = coefficient * maxWeight / Self.weightPerSecond
            let model = FeeWithWeight(fee: fee, weight: maxWeight)
            return CompoundOperationWrapper.createWithResult(model)
        case .standard:
            return createStardardFeeEstimationWrapper(chain: chain, message: message, maxWeight: maxWeight)
        }
    }

    func createDestinationFeeWrapper(
        for message: Xcm.Message,
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        guard let feeInfo = xcmTransfers.destinationFee(
            from: request.origin.chainAssetId,
            to: request.destination.chain.chainId
        ) else {
            let error = XcmTransferFactoryError.noDestinationFee(
                origin: request.origin.chainAssetId,
                destination: request.destination.chain.chainId
            )

            return CompoundOperationWrapper.createWithError(error)
        }

        guard let baseWeight = xcmTransfers.baseWeight(for: request.destination.chain.chainId) else {
            let error = XcmTransferFactoryError.noBaseWeight(request.destination.chain.chainId)
            return CompoundOperationWrapper.createWithError(error)
        }

        return createFeeEstimationWrapper(
            for: request.destination.chain,
            message: message,
            info: feeInfo,
            baseWeight: baseWeight
        )
    }

    func createReserveFeeWrapper(
        for message: Xcm.Message,
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<FeeWithWeight> {
        guard let feeInfo = xcmTransfers.reserveFee(from: request.origin.chainAssetId) else {
            let error = XcmTransferFactoryError.noReserveFee(request.origin.chainAssetId)
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let baseWeight = xcmTransfers.baseWeight(for: request.reserve.chain.chainId) else {
            let error = XcmTransferFactoryError.noBaseWeight(request.reserve.chain.chainId)
            return CompoundOperationWrapper.createWithError(error)
        }

        return createFeeEstimationWrapper(
            for: request.reserve.chain,
            message: message,
            info: feeInfo,
            baseWeight: baseWeight
        )
    }

    func createTransferWrapper(
        request: XcmUnweightedTransferRequest,
        xcmTransfers: XcmTransfers,
        maxWeight: BigUInt
    ) -> CompoundOperationWrapper<(ExtrinsicBuilderClosure, CallCodingPath)> {
        let destChainId = request.destination.chain.chainId
        let originChainAssetId = request.origin.chainAssetId
        guard let xcmTransfer = xcmTransfers.transfer(from: originChainAssetId, destinationChainId: destChainId) else {
            let error = XcmTransferFactoryError.noDestinationAssetFound(originChainAssetId)
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: request.origin.chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        do {
            let destinationAsset = try xcmFactory.createMultilocationAsset(
                from: request.origin,
                reserve: request.reserve.chain,
                destination: request.destination,
                amount: request.amount,
                xcmTransfers: xcmTransfers
            )

            let moduleResolutionWrapper = createModuleResolutionWrapper(
                for: xcmTransfer.type,
                runtimeProvider: runtimeProvider
            )

            let mapOperation = ClosureOperation<(ExtrinsicBuilderClosure, CallCodingPath)> {
                let module = try moduleResolutionWrapper.targetOperation.extractNoCancellableResultData()

                switch xcmTransfer.type {
                case .xtokens:
                    let asset = destinationAsset.asset
                    let location = destinationAsset.location

                    let call = Xcm.OrmlTransferCall(asset: asset, destination: location, destinationWeight: maxWeight)

                    return ({ try $0.adding(call: call.runtimeCall(for: module)) }, call.codingPath(for: module))
                case .xcmpallet:
                    let (destination, beneficiary) = destinationAsset.location.separatingDestinationBenifiary()
                    let assets = Xcm.VersionedMultiassets(versionedMultiasset: destinationAsset.asset)
                    let call = Xcm.PalletTransferCall(
                        destination: destination,
                        beneficiary: beneficiary,
                        assets: assets,
                        feeAssetItem: 0,
                        weightLimit: .limited(weight: UInt64(maxWeight))
                    )

                    return ({ try $0.adding(call: call.runtimeCall(for: module)) }, call.codingPath(for: module))
                case .teleport:
                    let (destination, beneficiary) = destinationAsset.location.separatingDestinationBenifiary()
                    let assets = Xcm.VersionedMultiassets(versionedMultiasset: destinationAsset.asset)
                    let call = Xcm.TeleportCall(
                        destination: destination,
                        beneficiary: beneficiary,
                        assets: assets,
                        feeAssetItem: 0,
                        weightLimit: .limited(weight: UInt64(maxWeight))
                    )

                    return ({ try $0.adding(call: call.runtimeCall(for: module)) }, call.codingPath(for: module))
                case .unknown:
                    throw XcmAssetTransfer.TransferTypeError.unknownType
                }
            }

            mapOperation.addDependency(moduleResolutionWrapper.targetOperation)

            let dependencies = moduleResolutionWrapper.allOperations
            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)

        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
