import Foundation
import Operation_iOS
import NovaCrypto

extension ValidatorOperationFactory: ValidatorOperationFactoryProtocol {
    // swiftlint:disable function_body_length
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let slashDeferOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .slashDeferDuration
            )

        let maxNominatorsWrapper: CompoundOperationWrapper<UInt32?> = PrimitiveConstantOperation.wrapperNilIfMissing(
            for: .maxNominatorRewardedPerValidator,
            runtimeService: runtimeService
        )

        slashDeferOperation.addDependency(runtimeOperation)

        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()

        let accountIdsClosure: () throws -> [AccountId] = {
            try eraValidatorsOperation.extractNoCancellableResultData().validators.map(\.accountId)
        }

        let identityWrapper = identityProxyFactory.createIdentityWrapper(for: accountIdsClosure)

        identityWrapper.allOperations.forEach { $0.addDependency(eraValidatorsOperation) }

        let slashingsWrapper = createUnappliedSlashesWrapper(
            dependingOn: { try eraValidatorsOperation.extractNoCancellableResultData().activeEra },
            runtime: runtimeOperation,
            slashDefer: slashDeferOperation
        )

        slashingsWrapper.allOperations.forEach {
            $0.addDependency(eraValidatorsOperation)
            $0.addDependency(runtimeOperation)
            $0.addDependency(slashDeferOperation)
        }

        let rewardOperation = rewardService.fetchCalculatorOperation()

        let mergeOperation = createElectedValidatorsMergeOperation(
            dependingOn: eraValidatorsOperation,
            rewardOperation: rewardOperation,
            maxNominatorsOperation: maxNominatorsWrapper.targetOperation,
            slashesOperation: slashingsWrapper.targetOperation,
            identitiesOperation: identityWrapper.targetOperation
        )

        mergeOperation.addDependency(slashingsWrapper.targetOperation)
        mergeOperation.addDependency(identityWrapper.targetOperation)
        mergeOperation.addDependency(maxNominatorsWrapper.targetOperation)
        mergeOperation.addDependency(rewardOperation)

        let baseOperations = [
            runtimeOperation,
            eraValidatorsOperation,
            slashDeferOperation,
            rewardOperation
        ] + maxNominatorsWrapper.allOperations

        let dependencies = baseOperations + identityWrapper.allOperations + slashingsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func allSelectedOperation(
        by nomination: Nomination,
        nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let targets = nomination.targets.distinct()

        let identityWrapper = identityProxyFactory.createIdentityWrapper(for: { targets })

        let electedValidatorsOperation = eraValidatorService.fetchInfoOperation()

        let statusesWrapper = createStatusesOperation(
            for: targets,
            electedValidatorsOperation: electedValidatorsOperation,
            nominatorAddress: nominatorAddress
        )

        statusesWrapper.allOperations.forEach { $0.addDependency(electedValidatorsOperation) }

        let slashesWrapper = createSlashesOperation(for: targets, nomination: nomination)

        slashesWrapper.allOperations.forEach { $0.addDependency(electedValidatorsOperation) }

        let validatorsStakingInfoWrapper = createValidatorsStakeInfoWrapper(
            for: targets,
            electedValidatorsOperation: electedValidatorsOperation
        )

        validatorsStakingInfoWrapper.allOperations.forEach { $0.addDependency(electedValidatorsOperation) }

        let chainFormat = chainInfo.chain

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let statuses = try statusesWrapper.targetOperation.extractNoCancellableResultData()
            let slashes = try slashesWrapper.targetOperation.extractNoCancellableResultData()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let validatorsStakingInfo = try validatorsStakingInfoWrapper.targetOperation
                .extractNoCancellableResultData()

            return try targets.enumerated().map { index, accountId in
                let address = try accountId.toAddress(using: chainFormat)

                return SelectedValidatorInfo(
                    address: address,
                    identity: identities[address],
                    stakeInfo: validatorsStakingInfo[index],
                    myNomination: statuses[index],
                    hasSlashes: slashes[index]
                )
            }
        }

        mergeOperation.addDependency(identityWrapper.targetOperation)
        mergeOperation.addDependency(statusesWrapper.targetOperation)
        mergeOperation.addDependency(slashesWrapper.targetOperation)
        mergeOperation.addDependency(validatorsStakingInfoWrapper.targetOperation)

        let dependecies = [electedValidatorsOperation] + identityWrapper.allOperations +
            statusesWrapper.allOperations + slashesWrapper.allOperations +
            validatorsStakingInfoWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependecies)
    }

    func activeValidatorsOperation(
        for nominatorAddress: AccountAddress
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()
        let activeValidatorsStakeInfoWrapper = createActiveValidatorsStakeInfo(
            for: nominatorAddress,
            electedValidatorsOperation: eraValidatorsOperation
        )

        activeValidatorsStakeInfoWrapper.allOperations.forEach { $0.addDependency(eraValidatorsOperation) }

        let validatorIds: () throws -> [AccountId] = {
            try activeValidatorsStakeInfoWrapper.targetOperation.extractNoCancellableResultData().map(\.key)
        }

        let identitiesWrapper = identityProxyFactory.createIdentityWrapper(for: validatorIds)

        identitiesWrapper.allOperations.forEach {
            $0.addDependency(activeValidatorsStakeInfoWrapper.targetOperation)
        }

        let chainFormat = chainInfo.chain

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let validatorStakeInfo = try activeValidatorsStakeInfoWrapper.targetOperation
                .extractNoCancellableResultData()
            let identities = try identitiesWrapper.targetOperation.extractNoCancellableResultData()

            return try validatorStakeInfo.compactMap { validatorAccountId, validatorStakeInfo in
                guard let nominatorIndex = validatorStakeInfo.nominators
                    .firstIndex(where: { $0.address == nominatorAddress }) else {
                    return nil
                }

                let validatorAddress = try validatorAccountId.toAddress(using: chainFormat)

                let nominatorInfo = validatorStakeInfo.nominators[nominatorIndex]
                let isRewarded = validatorStakeInfo.maxNominatorsRewarded.map { nominatorIndex < $0 } ?? true
                let allocation = ValidatorTokenAllocation(amount: nominatorInfo.stake, isRewarded: isRewarded)

                return SelectedValidatorInfo(
                    address: validatorAddress,
                    identity: identities[validatorAddress],
                    stakeInfo: validatorStakeInfo,
                    myNomination: .active(allocation: allocation)
                )
            }
        }

        mergeOperation.addDependency(identitiesWrapper.targetOperation)
        let dependencies = [eraValidatorsOperation] + activeValidatorsStakeInfoWrapper.allOperations +
            identitiesWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func pendingValidatorsOperation(
        for accountIds: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let chainFormat = chainInfo.chain

        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()
        let validatorsStakeInfoWrapper = createValidatorsStakeInfoWrapper(
            for: accountIds,
            electedValidatorsOperation: eraValidatorsOperation
        )

        validatorsStakeInfoWrapper.allOperations.forEach { $0.addDependency(eraValidatorsOperation) }

        let identitiesWrapper = identityProxyFactory.createIdentityWrapper(for: { accountIds })

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let validatorsStakeInfo = try validatorsStakeInfoWrapper.targetOperation
                .extractNoCancellableResultData()
            let identities = try identitiesWrapper.targetOperation.extractNoCancellableResultData()

            return try validatorsStakeInfo.enumerated().map { index, validatorStakeInfo in
                let validatorAddress = try accountIds[index].toAddress(using: chainFormat)

                return SelectedValidatorInfo(
                    address: validatorAddress,
                    identity: identities[validatorAddress],
                    stakeInfo: validatorStakeInfo,
                    myNomination: nil
                )
            }
        }

        mergeOperation.addDependency(identitiesWrapper.targetOperation)
        mergeOperation.addDependency(validatorsStakeInfoWrapper.targetOperation)

        let dependencies = [eraValidatorsOperation] + validatorsStakeInfoWrapper.allOperations +
            identitiesWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    // swiftlint:disable function_body_length
    func wannabeValidatorsOperation(
        for accountIdList: [AccountId]
    ) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let slashDeferOperation: BaseOperation<UInt32> =
            createConstOperation(
                dependingOn: runtimeOperation,
                path: .slashDeferDuration
            )

        slashDeferOperation.addDependency(runtimeOperation)

        let eraValidatorsOperation = eraValidatorService.fetchInfoOperation()

        let slashingsWrapper = createUnappliedSlashesWrapper(
            dependingOn: { try eraValidatorsOperation.extractNoCancellableResultData().activeEra },
            runtime: runtimeOperation,
            slashDefer: slashDeferOperation
        )

        slashingsWrapper.allOperations.forEach {
            $0.addDependency(eraValidatorsOperation)
            $0.addDependency(runtimeOperation)
            $0.addDependency(slashDeferOperation)
        }

        let chainFormat = chainInfo.chain
        let assetInfo = chainInfo.asset

        let identitiesWrapper = identityProxyFactory.createIdentityWrapper(for: { accountIdList })

        let validatorPrefsWrapper = createValidatorPrefsWrapper(for: accountIdList)

        let stakeInfoWrapper = createValidatorsStakeInfoWrapper(
            for: accountIdList,
            electedValidatorsOperation: eraValidatorsOperation
        )

        stakeInfoWrapper.addDependency(operations: [eraValidatorsOperation])

        let mergeOperation = ClosureOperation<[SelectedValidatorInfo]> {
            let identityList = try identitiesWrapper.targetOperation.extractNoCancellableResultData()
            let validatorPrefsList = try validatorPrefsWrapper.targetOperation.extractNoCancellableResultData()
            let slashings = try slashingsWrapper.targetOperation.extractNoCancellableResultData()
            let stakeInfoList = try stakeInfoWrapper.targetOperation.extractNoCancellableResultData()

            let slashed: Set<Data> = slashings.reduce(into: Set<Data>()) { result, slashInEra in
                slashInEra.value?.forEach { slash in
                    result.insert(slash.validator)
                }
            }

            return try accountIdList.enumerated().compactMap { index, accountId in
                let validatorAddress = try accountId.toAddress(using: chainFormat)

                guard let prefs = validatorPrefsList[validatorAddress] else { return nil }

                let stakeInfo = stakeInfoList[index]

                let commission = Decimal.fromSubstrateAmount(
                    prefs.commission,
                    precision: assetInfo.assetPrecision
                ) ?? 0.0

                return SelectedValidatorInfo(
                    address: validatorAddress,
                    identity: identityList[validatorAddress],
                    stakeInfo: stakeInfo,
                    myNomination: stakeInfo != nil ? .elected : .unelected,
                    commission: commission,
                    hasSlashes: slashed.contains(accountId),
                    blocked: prefs.isBlocked
                )
            }
        }

        mergeOperation.addDependency(identitiesWrapper.targetOperation)
        mergeOperation.addDependency(validatorPrefsWrapper.targetOperation)
        mergeOperation.addDependency(slashingsWrapper.targetOperation)
        mergeOperation.addDependency(stakeInfoWrapper.targetOperation)

        let dependencies = [runtimeOperation, slashDeferOperation, eraValidatorsOperation] +
            identitiesWrapper.allOperations + validatorPrefsWrapper.allOperations +
            slashingsWrapper.allOperations + stakeInfoWrapper.allOperations
        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func allPreferred(
        for preferrence: PreferredValidatorsProviderModel?
    ) -> CompoundOperationWrapper<ElectedAndPrefValidators> {
        let allElectedWrapper = allElectedOperation()

        let preferredAccountIds = preferrence?.preferred ?? []
        let wannabeWrapper = !preferredAccountIds.isEmpty ?
            wannabeValidatorsOperation(for: preferredAccountIds) : nil

        let mergeOperation = ClosureOperation<ElectedAndPrefValidators> {
            let electedValidators = try allElectedWrapper.targetOperation.extractNoCancellableResultData()
            let prefValidators = try wannabeWrapper?.targetOperation.extractNoCancellableResultData()

            let notExcludedElectedValidators: [ElectedValidatorInfo]

            if let excluded = preferrence?.excluded, !excluded.isEmpty {
                notExcludedElectedValidators = electedValidators.filter { validator in
                    guard let accountId = try? validator.address.toAccountId() else {
                        return false
                    }

                    return !excluded.contains(accountId)
                }
            } else {
                notExcludedElectedValidators = electedValidators
            }

            return ElectedAndPrefValidators(
                allElectedValidators: electedValidators,
                notExcludedElectedValidators: notExcludedElectedValidators,
                preferredValidators: prefValidators ?? []
            )
        }

        mergeOperation.addDependency(allElectedWrapper.targetOperation)

        if let wrapper = wannabeWrapper {
            mergeOperation.addDependency(wrapper.targetOperation)
        }

        let dependencies = allElectedWrapper.allOperations + (wannabeWrapper?.allOperations ?? [])

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
