import Foundation
import Operation_iOS

protocol GenericLedgerPolkadotAccountProtocol {
    var connectionManager: LedgerConnectionManagerProtocol { get }

    func getGenericSubstrateAccountWrapper(
        for deviceId: UUID,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerSubstrateAccountResponse>

    func getGenericEvmAccountWrapper(
        for deviceId: UUID,
        index: UInt32,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerEvmAccountResponse>
}

extension GenericLedgerPolkadotAccountProtocol {
    func getGenericSubstrateAccountWrapperBy(
        deviceId: UUID,
        index: UInt32 = 0,
        displayVerificationDialog: Bool = false
    ) -> CompoundOperationWrapper<LedgerSubstrateAccountResponse> {
        getGenericSubstrateAccountWrapper(
            for: deviceId,
            index: index,
            addressPrefix: 42,
            displayVerificationDialog: displayVerificationDialog
        )
    }

    func getGenericEvmAccountWrapperBy(
        deviceId: UUID,
        index: UInt32 = 0,
        displayVerificationDialog: Bool = false
    ) -> CompoundOperationWrapper<LedgerEvmAccountResponse> {
        getGenericEvmAccountWrapper(
            for: deviceId,
            index: index,
            displayVerificationDialog: displayVerificationDialog
        )
    }
}

typealias GenericLedgerPolkadotApplicationProtocol = GenericLedgerPolkadotAccountProtocol &
    NewLedgerPolkadotSigningProtocol

final class GenericLedgerPolkadotApplication: NewLedgerPolkadotApplication {}

extension GenericLedgerPolkadotApplication: GenericLedgerPolkadotApplicationProtocol {
    static let coin: UInt32 = 354

    func getGenericSubstrateAccountWrapper(
        for deviceId: UUID,
        index: UInt32,
        addressPrefix: UInt16,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerSubstrateAccountResponse> {
        getSubstrateAccountWrapper(
            for: deviceId,
            coin: Self.coin,
            index: index,
            addressPrefix: addressPrefix,
            displayVerificationDialog: displayVerificationDialog
        )
    }

    func getGenericEvmAccountWrapper(
        for deviceId: UUID,
        index: UInt32,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerEvmAccountResponse> {
        getEvmAccountWrapper(
            for: deviceId,
            coin: Self.coin,
            index: index,
            displayVerificationDialog: displayVerificationDialog
        )
    }
}
