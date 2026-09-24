import Foundation
import Operation_iOS
import SubstrateSdk

enum AssetHubExchangePreparationError: Error, Equatable {
    case invalidCommission
    case invalidSlippage
    case unsupportedStorage
    case runtimeCallUnavailable(CallCodingPath)
    case recipientUnavailable
    case netOutputBelowMinimum
}

protocol AssetHubExchangeCommissionRecipientFactoryProtocol {
    func createMinimumBalanceWrapper(
        recipient: AccountId,
        storageInfo: AssetStorageInfo
    ) -> CompoundOperationWrapper<Balance>
}

enum AssetHubExchangeRecipientReadiness {
    static func nativeMinimumBalance(
        accountInfo: AccountInfo?,
        existentialDeposit: Balance
    ) throws -> Balance {
        guard
            let accountInfo,
            accountInfo.hasProviders,
            accountInfo.data.free >= existentialDeposit else {
            throw AssetHubExchangePreparationError.recipientUnavailable
        }

        return existentialDeposit
    }

    static func assetsMinimumBalance(
        details: PalletAssets.Details?,
        account: PalletAssets.Account?
    ) throws -> Balance {
        guard
            let details,
            !details.isFrozen,
            let account,
            account.canReceive,
            account.balance >= details.minBalance else {
            throw AssetHubExchangePreparationError.recipientUnavailable
        }

        return details.minBalance
    }
}

final class AssetHubExchangeCommissionRecipientFactory {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let requestFactory: StorageRequestFactoryProtocol

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider

        requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}

private extension AssetHubExchangeCommissionRecipientFactory {
    func createProviderCheckWrapper(for recipient: AccountId) -> CompoundOperationWrapper<Balance> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let accountWrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]>
        accountWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: recipient)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: SystemPallet.accountPath
        )

        accountWrapper.addDependency(operations: [codingFactoryOperation])

        let depositOperation = PrimitiveConstantOperation<Balance>(
            path: .existentialDeposit,
            fallbackValue: nil
        )

        depositOperation.configurationBlock = {
            do {
                depositOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                depositOperation.result = .failure(error)
            }
        }

        depositOperation.addDependency(codingFactoryOperation)

        let mappingOperation = ClosureOperation<Balance> {
            let existentialDeposit = try depositOperation.extractNoCancellableResultData()
            let accountInfo = try accountWrapper.targetOperation.extractNoCancellableResultData().first?.value

            return try AssetHubExchangeRecipientReadiness.nativeMinimumBalance(
                accountInfo: accountInfo,
                existentialDeposit: existentialDeposit
            )
        }

        mappingOperation.addDependency(accountWrapper.targetOperation)
        mappingOperation.addDependency(depositOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation, depositOperation] + accountWrapper.allOperations
        )
    }

    func createAssetsCheckWrapper(
        for recipient: AccountId,
        info: AssetsPalletStorageInfo
    ) -> CompoundOperationWrapper<Balance> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let detailsWrapper: CompoundOperationWrapper<[StorageResponse<PalletAssets.Details>]>
        detailsWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams: { [info.assetId] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: StorageCodingPath.assetsDetails(from: info.palletName)
        )

        detailsWrapper.addDependency(operations: [codingFactoryOperation])

        let accountWrapper: CompoundOperationWrapper<[StorageResponse<PalletAssets.Account>]>
        accountWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams1: { [info.assetId] },
            keyParams2: { [BytesCodable(wrappedValue: recipient)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: StorageCodingPath.assetsAccount(from: info.palletName)
        )

        accountWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<Balance> {
            let details = try detailsWrapper.targetOperation.extractNoCancellableResultData().first?.value
            let account = try accountWrapper.targetOperation.extractNoCancellableResultData().first?.value

            return try AssetHubExchangeRecipientReadiness.assetsMinimumBalance(
                details: details,
                account: account
            )
        }

        mappingOperation.addDependency(detailsWrapper.targetOperation)
        mappingOperation.addDependency(accountWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + detailsWrapper.allOperations + accountWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}

extension AssetHubExchangeCommissionRecipientFactory: AssetHubExchangeCommissionRecipientFactoryProtocol {
    func createMinimumBalanceWrapper(
        recipient: AccountId,
        storageInfo: AssetStorageInfo
    ) -> CompoundOperationWrapper<Balance> {
        switch storageInfo {
        case .native:
            return createProviderCheckWrapper(for: recipient)
        case let .statemine(info):
            let providerWrapper = createProviderCheckWrapper(for: recipient)
            let assetsWrapper = createAssetsCheckWrapper(for: recipient, info: info)

            let mappingOperation = ClosureOperation<Balance> {
                _ = try providerWrapper.targetOperation.extractNoCancellableResultData()

                return try assetsWrapper.targetOperation.extractNoCancellableResultData()
            }

            mappingOperation.addDependency(providerWrapper.targetOperation)
            mappingOperation.addDependency(assetsWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mappingOperation,
                dependencies: providerWrapper.allOperations + assetsWrapper.allOperations
            )
        case .orml, .ormlHydrationEvm, .erc20, .evmNative, .equilibrium:
            return .createWithError(AssetHubExchangePreparationError.unsupportedStorage)
        }
    }
}
