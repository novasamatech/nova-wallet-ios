import Foundation
import Operation_iOS

protocol GenericLedgerAccountFetchFactoryProtocol {
    func createAccountModel(
        for schemes: Set<HardwareWalletAddressScheme>,
        index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<GenericLedgerAccountModel>

    func createConfirmModel(
        for schemes: [HardwareWalletAddressScheme],
        index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<PolkadotLedgerWalletModel>

    func createEvmModel(
        index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<LedgerEvmAccountResponse>

    func cancelConfirmationRequests()
}

final class GenericLedgerAccountFetchFactory {
    let deviceId: UUID
    let ledgerApplication: GenericLedgerPolkadotApplicationProtocol

    init(deviceId: UUID, ledgerApplication: GenericLedgerPolkadotApplicationProtocol) {
        self.deviceId = deviceId
        self.ledgerApplication = ledgerApplication
    }
}

private extension GenericLedgerAccountFetchFactory {
    func createSubstrateWrapper(
        at index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<LedgerSubstrateAccountResponse> {
        ledgerApplication.getGenericSubstrateAccountWrapperBy(
            deviceId: deviceId,
            index: index,
            displayVerificationDialog: shouldConfirm
        )
    }

    func createSubstrateAccountIdWrapper(
        at index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<AccountId?> {
        let accountWrapper = createSubstrateWrapper(at: index, shouldConfirm: shouldConfirm)

        let mappingOperation = ClosureOperation<AccountId?> {
            try accountWrapper.targetOperation.extractNoCancellableResultData().account.address.toAccountId()
        }

        mappingOperation.addDependency(accountWrapper.targetOperation)

        return accountWrapper.insertingTail(operation: mappingOperation)
    }

    func createEvmWrapper(
        at index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<LedgerEvmAccountResponse?> {
        let wrapper = ledgerApplication.getGenericEvmAccountWrapperBy(
            deviceId: deviceId,
            index: index,
            displayVerificationDialog: shouldConfirm
        )

        let mappingOperation = ClosureOperation<LedgerEvmAccountResponse?> {
            do {
                return try wrapper.targetOperation.extractNoCancellableResultData()
            } catch LedgerError.response {
                // evm might not be supported
                return nil
            }
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: mappingOperation)
    }

    func createEvmAccountIdWrapper(
        at index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<AccountId?> {
        let accountWrapper = createEvmWrapper(at: index, shouldConfirm: shouldConfirm)

        let mappingOperation = ClosureOperation<AccountId?> {
            try accountWrapper.targetOperation.extractNoCancellableResultData()?.account.address.toAccountId()
        }

        mappingOperation.addDependency(accountWrapper.targetOperation)

        return accountWrapper.insertingTail(operation: mappingOperation)
    }

    func createAccountIdWrapper(
        for scheme: HardwareWalletAddressScheme,
        index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<AccountId?> {
        switch scheme {
        case .substrate:
            createSubstrateAccountIdWrapper(at: index, shouldConfirm: shouldConfirm)
        case .evm:
            createEvmAccountIdWrapper(at: index, shouldConfirm: shouldConfirm)
        }
    }
}

extension GenericLedgerAccountFetchFactory: GenericLedgerAccountFetchFactoryProtocol {
    func createAccountModel(
        for schemes: Set<HardwareWalletAddressScheme>,
        index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<GenericLedgerAccountModel> {
        let wrappers = schemes.map { scheme in
            createAccountIdWrapper(for: scheme, index: index, shouldConfirm: shouldConfirm)
        }

        for (wrapperIndex, wrapper) in wrappers.enumerated() where wrapperIndex > 0 {
            wrapper.addDependency(wrapper: wrappers[wrapperIndex - 1])
        }

        let mappingOperation = ClosureOperation<GenericLedgerAccountModel> {
            let addresses = try zip(schemes, wrappers).map { scheme, wrapper in
                let accountId = try wrapper.targetOperation.extractNoCancellableResultData()

                return HardwareWalletAddressModel(accountId: accountId, scheme: scheme)
            }

            return GenericLedgerAccountModel(index: index, addresses: addresses.sortedBySchemeOrder())
        }

        let dependencies = wrappers.flatMap(\.allOperations)

        wrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func createConfirmModel(
        for schemes: [HardwareWalletAddressScheme],
        index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<PolkadotLedgerWalletModel> {
        let substrateWrapper = createSubstrateWrapper(at: index, shouldConfirm: shouldConfirm)

        let evmWrapper = schemes.contains(.evm) ?
            createEvmWrapper(at: index, shouldConfirm: shouldConfirm) :
            .createWithResult(nil)

        evmWrapper.addDependency(wrapper: substrateWrapper)

        let mappingOperation = ClosureOperation<PolkadotLedgerWalletModel> {
            let substrateResponse = try substrateWrapper.targetOperation.extractNoCancellableResultData()
            let evmModel = try evmWrapper.targetOperation.extractNoCancellableResultData()

            let substrate = try PolkadotLedgerWalletModel.Substrate(
                substrateResponse: substrateResponse
            )

            let evm = try evmModel.map { model in
                try PolkadotLedgerWalletModel.EVM(evmResponse: model)
            }

            return PolkadotLedgerWalletModel(substrate: substrate, evm: evm)
        }

        mappingOperation.addDependency(evmWrapper.targetOperation)

        return evmWrapper
            .insertingHead(operations: substrateWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }

    func createEvmModel(
        index: UInt32,
        shouldConfirm: Bool
    ) -> CompoundOperationWrapper<LedgerEvmAccountResponse> {
        ledgerApplication.getGenericEvmAccountWrapperBy(
            deviceId: deviceId,
            index: index,
            displayVerificationDialog: shouldConfirm
        )
    }

    func cancelConfirmationRequests() {
        ledgerApplication.connectionManager.cancelRequest(for: deviceId)
    }
}
