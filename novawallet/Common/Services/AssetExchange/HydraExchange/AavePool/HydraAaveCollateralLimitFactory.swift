import Foundation
import BigInt
import Operation_iOS
import SubstrateSdk

protocol HydraAaveCollateralLimitFactoryProtocol {
    func createLimitWrapper(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> CompoundOperationWrapper<HydraAave.CollateralLimit>
}

final class HydraAaveCollateralLimitFactory {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

private extension HydraAaveCollateralLimitFactory {
    struct UserState {
        let accountData: HydraAave.UserAccountData
        let configuration: HydraAave.UserConfiguration
        let eModeCategoryId: BigUInt
    }

    struct PayAsset {
        let assetId: HydraDx.AssetId
        let registeredAddress: AccountId?

        func matches(aTokenAddress: AccountId) -> Bool {
            let registeredAssets = registeredAddress.map { [$0: assetId] } ?? [:]

            return HydraAave.Contract.assetId(for: aTokenAddress, registeredAssets: registeredAssets) == assetId
        }
    }

    func createCallWrapper<T>(
        connection: JSONRPCEngine,
        contract: String = HydraAave.Contract.poolAddress,
        callDataClosure: () throws -> String,
        decoder: @escaping (String) throws -> T
    ) -> CompoundOperationWrapper<T> {
        do {
            let callOperation = HydraAave.Contract.createCallOperation(
                connection: connection,
                contract: contract,
                data: try callDataClosure()
            )

            let decodingOperation = ClosureOperation<T> {
                try decoder(try callOperation.extractNoCancellableResultData())
            }

            decodingOperation.addDependency(callOperation)

            return CompoundOperationWrapper(targetOperation: decodingOperation, dependencies: [callOperation])
        } catch {
            return .createWithError(error)
        }
    }

    func createUserStateWrapper(
        connection: JSONRPCEngine,
        user: AccountId
    ) -> CompoundOperationWrapper<UserState> {
        let accountDataWrapper = createCallWrapper(
            connection: connection,
            callDataClosure: { try HydraAave.Contract.getUserAccountDataCall(user: user) },
            decoder: HydraAave.Contract.decodeUserAccountData
        )

        let configurationWrapper = createCallWrapper(
            connection: connection,
            callDataClosure: { try HydraAave.Contract.getUserConfigurationCall(user: user) },
            decoder: HydraAave.Contract.decodeUserConfiguration
        )

        let eModeWrapper = createCallWrapper(
            connection: connection,
            callDataClosure: { try HydraAave.Contract.getUserEModeCall(user: user) },
            decoder: HydraAave.Contract.decodeUserEMode
        )

        let mappingOperation = ClosureOperation<UserState> {
            UserState(
                accountData: try accountDataWrapper.targetOperation.extractNoCancellableResultData(),
                configuration: try configurationWrapper.targetOperation.extractNoCancellableResultData(),
                eModeCategoryId: try eModeWrapper.targetOperation.extractNoCancellableResultData()
            )
        }

        mappingOperation.addDependency(accountDataWrapper.targetOperation)
        mappingOperation.addDependency(configurationWrapper.targetOperation)
        mappingOperation.addDependency(eModeWrapper.targetOperation)

        let dependencies = accountDataWrapper.allOperations + configurationWrapper.allOperations +
            eModeWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func createPayAssetWrapper(
        for chainAsset: ChainAsset,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<PayAsset> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let assetIdOperation = ClosureOperation<HydraDx.AssetId> {
            try HydraDxTokenConverter.convertToRemote(
                chainAsset: chainAsset,
                codingFactory: try codingFactoryOperation.extractNoCancellableResultData()
            ).remoteAssetId
        }

        assetIdOperation.addDependency(codingFactoryOperation)

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let locationWrapper: CompoundOperationWrapper<[StorageResponse<HydraAssetRegistry.AssetLocationValue>]>
        locationWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams: { [StringScaleMapper(value: try assetIdOperation.extractNoCancellableResultData())] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: HydraAssetRegistry.assetLocationsPath
        )

        locationWrapper.addDependency(operations: [assetIdOperation])

        let mappingOperation = ClosureOperation<PayAsset> {
            let location = try locationWrapper.targetOperation.extractNoCancellableResultData().first?.value

            return PayAsset(
                assetId: try assetIdOperation.extractNoCancellableResultData(),
                registeredAddress: location?.evmAddress
            )
        }

        mappingOperation.addDependency(locationWrapper.targetOperation)

        return locationWrapper
            .insertingHead(operations: [codingFactoryOperation, assetIdOperation])
            .insertingTail(operation: mappingOperation)
    }

    func createReserveWrapper(
        connection: JSONRPCEngine,
        reserveIndex: Int
    ) -> CompoundOperationWrapper<HydraAave.Reserve> {
        let addressWrapper = createCallWrapper(
            connection: connection,
            callDataClosure: { try HydraAave.Contract.getReserveAddressByIdCall(reserveIndex: reserveIndex) },
            decoder: HydraAave.Contract.decodeReserveAddress
        )

        let reserveWrapper = OperationCombiningService<HydraAave.Reserve>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let address = try addressWrapper.targetOperation.extractNoCancellableResultData()

            return self.createCallWrapper(
                connection: connection,
                callDataClosure: { try HydraAave.Contract.getReserveDataCall(reserve: address) },
                decoder: { response in
                    HydraAave.Reserve(
                        address: address,
                        data: try HydraAave.Contract.decodeReserveData(response: response)
                    )
                }
            )
        }

        reserveWrapper.addDependency(wrapper: addressWrapper)

        return reserveWrapper.insertingHead(operations: addressWrapper.allOperations)
    }

    func createCollateralReservesWrapper(
        connection: JSONRPCEngine,
        configuration: HydraAave.UserConfiguration
    ) -> CompoundOperationWrapper<[HydraAave.Reserve]> {
        let reservesOperation = OperationCombiningService<HydraAave.Reserve>(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            configuration.collateralReserveIndices.map { reserveIndex in
                self.createReserveWrapper(connection: connection, reserveIndex: reserveIndex)
            }
        }.longrunOperation()

        return CompoundOperationWrapper(targetOperation: reservesOperation)
    }

    func createPriceOracleWrapper(connection: JSONRPCEngine) -> CompoundOperationWrapper<AccountId> {
        let providerWrapper = createCallWrapper(
            connection: connection,
            callDataClosure: { try HydraAave.Contract.addressesProviderCall() },
            decoder: HydraAave.Contract.decodeAddressesProvider
        )

        let oracleWrapper = OperationCombiningService<AccountId>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let provider = try providerWrapper.targetOperation.extractNoCancellableResultData()

            return self.createCallWrapper(
                connection: connection,
                contract: provider.toHex(includePrefix: true),
                callDataClosure: { try HydraAave.Contract.getPriceOracleCall() },
                decoder: HydraAave.Contract.decodePriceOracle
            )
        }

        oracleWrapper.addDependency(wrapper: providerWrapper)

        return oracleWrapper.insertingHead(operations: providerWrapper.allOperations)
    }

    func createEModeCategoryWrapper(
        connection: JSONRPCEngine,
        reserve: HydraAave.Reserve,
        userEModeCategoryId: BigUInt
    ) -> CompoundOperationWrapper<HydraAave.EModeCategory?> {
        guard userEModeCategoryId > 0, reserve.data.configuration.eModeCategory == userEModeCategoryId else {
            return .createWithResult(nil)
        }

        return createCallWrapper(
            connection: connection,
            callDataClosure: { try HydraAave.Contract.getEModeCategoryDataCall(categoryId: userEModeCategoryId) },
            decoder: { try HydraAave.Contract.decodeEModeCategory(response: $0) }
        )
    }

    func createReserveLimitWrapper(
        for reserve: HydraAave.Reserve,
        collateralReserves: [HydraAave.Reserve],
        userState: UserState,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<HydraAave.CollateralLimit> {
        let eModeCategoryWrapper = createEModeCategoryWrapper(
            connection: connection,
            reserve: reserve,
            userEModeCategoryId: userState.eModeCategoryId
        )

        let oracleWrapper = createPriceOracleWrapper(connection: connection)

        let limitWrapper = OperationCombiningService<HydraAave.CollateralLimit>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let eModeCategory = try eModeCategoryWrapper.targetOperation.extractNoCancellableResultData()
            let oracle = try oracleWrapper.targetOperation.extractNoCancellableResultData()

            let priceWrapper = self.createCallWrapper(
                connection: connection,
                contract: oracle.toHex(includePrefix: true),
                callDataClosure: {
                    try HydraAave.Contract.getAssetPriceCall(
                        asset: HydraAave.CollateralPosition.priceAsset(for: reserve, eModeCategory: eModeCategory)
                    )
                },
                decoder: HydraAave.Contract.decodeAssetPrice
            )

            let calculationOperation = ClosureOperation<HydraAave.CollateralLimit> {
                HydraAave.CollateralPosition.calculateLimit(
                    accountData: userState.accountData,
                    reserve: reserve.data,
                    collateralReserves: collateralReserves.map(\.data),
                    eModeCategory: eModeCategory,
                    price: try priceWrapper.targetOperation.extractNoCancellableResultData()
                )
            }

            calculationOperation.addDependency(priceWrapper.targetOperation)

            return priceWrapper.insertingTail(operation: calculationOperation)
        }

        limitWrapper.addDependency(wrapper: eModeCategoryWrapper)
        limitWrapper.addDependency(wrapper: oracleWrapper)

        return limitWrapper.insertingHead(operations: eModeCategoryWrapper.allOperations + oracleWrapper.allOperations)
    }

    func createBorrowerLimitWrapper(
        for chainAsset: ChainAsset,
        userState: UserState,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<HydraAave.CollateralLimit> {
        let payAssetWrapper = createPayAssetWrapper(
            for: chainAsset,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        let reservesWrapper = createCollateralReservesWrapper(
            connection: connection,
            configuration: userState.configuration
        )

        let limitWrapper = OperationCombiningService<HydraAave.CollateralLimit>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let payAsset = try payAssetWrapper.targetOperation.extractNoCancellableResultData()
            let reserves = try reservesWrapper.targetOperation.extractNoCancellableResultData()

            guard let reserve = reserves.first(where: { payAsset.matches(aTokenAddress: $0.data.aTokenAddress) }) else {
                return .createWithResult(.unrestricted)
            }

            return self.createReserveLimitWrapper(
                for: reserve,
                collateralReserves: reserves,
                userState: userState,
                connection: connection
            )
        }

        limitWrapper.addDependency(wrapper: payAssetWrapper)
        limitWrapper.addDependency(wrapper: reservesWrapper)

        return limitWrapper.insertingHead(operations: payAssetWrapper.allOperations + reservesWrapper.allOperations)
    }
}

extension HydraAaveCollateralLimitFactory: HydraAaveCollateralLimitFactoryProtocol {
    func createLimitWrapper(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> CompoundOperationWrapper<HydraAave.CollateralLimit> {
        do {
            let chainId = chainAsset.chain.chainId
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let userStateWrapper = createUserStateWrapper(
                connection: connection,
                user: HydraAave.evmAddress(for: accountId)
            )

            let limitWrapper = OperationCombiningService<HydraAave.CollateralLimit>.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let userState = try userStateWrapper.targetOperation.extractNoCancellableResultData()

                guard
                    userState.accountData.totalDebtBase > 0,
                    !userState.configuration.collateralReserveIndices.isEmpty else {
                    return .createWithResult(.unrestricted)
                }

                return self.createBorrowerLimitWrapper(
                    for: chainAsset,
                    userState: userState,
                    connection: connection,
                    runtimeProvider: runtimeProvider
                )
            }

            limitWrapper.addDependency(wrapper: userStateWrapper)

            return limitWrapper.insertingHead(operations: userStateWrapper.allOperations)
        } catch {
            return .createWithError(error)
        }
    }
}
