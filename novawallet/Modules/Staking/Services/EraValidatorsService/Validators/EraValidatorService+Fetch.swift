import Foundation
import Operation_iOS
import SubstrateSdk

extension EraValidatorService {
    private func updateValidators(
        activeEra: UInt32,
        exposures: [EraValidatorResultItem],
        prefs: [StorageResponse<Staking.ValidatorPrefs>]
    ) {
        guard activeEra == self.activeEra else {
            logger.warning("Validators fetched but parameters changed. Cancelled.")
            return
        }

        validatorUpdater = nil

        let keyedPrefs = prefs.reduce(into: [Data: Staking.ValidatorPrefs]()) { result, item in
            let accountId = item.key.getAccountIdFromKey()
            result[accountId] = item.value
        }

        let validators: [EraValidatorInfo] = exposures.compactMap { item in
            guard let pref = keyedPrefs[item.validator] else {
                return nil
            }

            let exposure = Staking.ValidatorExposure(
                total: item.exposure.total,
                own: item.exposure.own,
                others: item.exposure.others.sorted { $0.value > $1.value }
            )

            return EraValidatorInfo(
                accountId: item.validator,
                exposure: exposure,
                prefs: pref
            )
        }

        let snapshot = EraStakersInfo(
            activeEra: activeEra,
            validators: validators
        )

        didReceiveSnapshot(snapshot)
    }

    private func createPrefsWrapper(
        identifiersClosure: @escaping () throws -> [Data]
    ) -> CompoundOperationWrapper<[StorageResponse<Staking.ValidatorPrefs>]> {
        let keys: () throws -> [Data] = {
            try identifiersClosure()
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let wrapper: CompoundOperationWrapper<[StorageResponse<Staking.ValidatorPrefs>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: keys,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Staking.validatorPrefs
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        return CompoundOperationWrapper(
            targetOperation: wrapper.targetOperation,
            dependencies: [codingFactoryOperation] + wrapper.dependencies
        )
    }

    private func updateFromValidators(_ validators: [EraValidatorResultItem], activeEra: UInt32) {
        guard activeEra == self.activeEra else {
            logger.warning("Wanted to fetch exposures but parameters changed. Cancelled.")
            return
        }

        let prefs = createPrefsWrapper { validators.map(\.validator) }

        prefs.targetOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                do {
                    let prefs = try prefs.targetOperation.extractNoCancellableResultData()
                    self?.updateValidators(
                        activeEra: activeEra,
                        exposures: validators,
                        prefs: prefs
                    )
                } catch {
                    self?.logger.error("Did receive error: \(error)")
                }
            }
        }

        operationQueue.addOperations(prefs.allOperations, waitUntilFinished: false)
    }

    private func fetchValidators(for activeEra: UInt32) {
        validatorUpdater = EraValidatorsUpdater(
            chainId: chainId,
            connection: connection,
            runtimeService: runtimeCodingService,
            substrateRepositoryFactory: SubstrateRepositoryFactory(storageFacade: storageFacade),
            operationQueue: operationQueue,
            logger: logger
        )

        validatorUpdater?.fetchValidators(for: activeEra, runningIn: syncQueue) { [weak self] validators in
            self?.validatorUpdater = nil
            self?.updateFromValidators(validators, activeEra: activeEra)
        }
    }

    func didUpdateActiveEraItem(_ eraItem: DecodedActiveEra?) {
        guard let eraIndex = eraItem?.item?.index else {
            return
        }

        didReceiveActiveEra(eraIndex)
        fetchValidators(for: eraIndex)
    }
}
