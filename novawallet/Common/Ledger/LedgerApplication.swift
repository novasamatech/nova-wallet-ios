import Foundation
import RobinHood

protocol LedgerApplicationProtocol {
    func getAccountWrapper(
        for deviceId: UUID,
        chainId: ChainModel.Id,
        index: UInt32,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse>

    func getSignWrapper(
        for payload: Data,
        deviceId: UUID,
        chainId: ChainModel.Id,
        derivationPath: Data
    ) -> CompoundOperationWrapper<Data>
}

extension LedgerApplicationProtocol {
    func getAccountWrapper(
        for deviceId: UUID,
        chainId: ChainModel.Id,
        index: UInt32
    ) -> CompoundOperationWrapper<LedgerAccountResponse> {
        getAccountWrapper(for: deviceId, chainId: chainId, index: index, displayVerificationDialog: false)
    }
}

enum LedgerApplicationError: Error {
    case unsupportedApp(chainId: ChainModel.Id)
}

final class LedgerApplication {
    static let defaultCryptoScheme: CryptoScheme = .ed25519

    private enum Constants {
        static let chunkSize = 250
    }

    enum Instruction: UInt8 {
        case getAddress = 0x01
        case sign = 0x02
    }

    enum CryptoScheme: UInt8 {
        case ed25519 = 0x00
        case sr25519 = 0x01
    }

    enum PayloadType: UInt8 {
        case initialize
        case add
        case last

        init(chunkIndex: Int, totalChunks: Int) {
            if chunkIndex == 0 {
                self = .initialize
            } else if chunkIndex < totalChunks - 1 {
                self = .add
            } else {
                self = .last
            }
        }
    }

    let connectionManager: LedgerConnectionManagerProtocol
    let supportedApps: [SupportedLedgerApp]

    init(connectionManager: LedgerConnectionManagerProtocol, supportedApps: [SupportedLedgerApp]) {
        self.connectionManager = connectionManager
        self.supportedApps = supportedApps
    }

    private func createAccountMessageOperation(
        for application: SupportedLedgerApp,
        path: Data,
        displayVerificationDialog: Bool = false,
        cryptoScheme: CryptoScheme = LedgerApplication.defaultCryptoScheme
    ) -> BaseOperation<Data> {
        ClosureOperation {
            let message = LedgerApplicationRequest(
                cla: application.cla,
                instruction: Instruction.getAddress.rawValue,
                param1: UInt8(displayVerificationDialog ? 0x01 : 0x00),
                param2: cryptoScheme.rawValue,
                payload: path
            ).toBytes()

            return message
        }
    }

    private func createAccountResponseOperation(
        dependingOn sendOperation: LedgerSendOperation,
        path: Data
    ) -> BaseOperation<LedgerAccountResponse> {
        ClosureOperation {
            let data = try sendOperation.extractNoCancellableResultData()

            let account = try LedgerResponse<LedgerAccount>(ledgerData: data).value

            return LedgerAccountResponse(account: account, derivationPath: path)
        }
    }
}

extension LedgerApplication: LedgerApplicationProtocol {
    /// https://github.com/Zondax/ledger-substrate-js/blob/main/src/substrate_app.ts#L143
    func getAccountWrapper(
        for deviceId: UUID,
        chainId: ChainModel.Id,
        index: UInt32,
        displayVerificationDialog: Bool
    ) -> CompoundOperationWrapper<LedgerAccountResponse> {
        guard let application = supportedApps.first(where: { $0.chainId == chainId }) else {
            return CompoundOperationWrapper.createWithError(LedgerApplicationError.unsupportedApp(chainId: chainId))
        }

        let path = LedgerPathBuilder()
            .appendingStandardJunctions(coin: application.coin, accountIndex: index)
            .build()

        let messageOperation = createAccountMessageOperation(
            for: application,
            path: path,
            displayVerificationDialog: displayVerificationDialog
        )

        let sendOperation = LedgerSendOperation(connection: connectionManager, deviceId: deviceId)
        sendOperation.configurationBlock = {
            do {
                sendOperation.message = try messageOperation.extractNoCancellableResultData()
            } catch {
                sendOperation.result = .failure(error)
            }
        }

        sendOperation.addDependency(messageOperation)

        let responseOperation = createAccountResponseOperation(dependingOn: sendOperation, path: path)

        responseOperation.addDependency(sendOperation)

        return CompoundOperationWrapper(
            targetOperation: responseOperation,
            dependencies: [messageOperation, sendOperation]
        )
    }

    /// https://github.com/Zondax/ledger-substrate-js/blob/main/src/substrate_app.ts#L203
    func getSignWrapper(
        for payload: Data,
        deviceId: UUID,
        chainId: ChainModel.Id,
        derivationPath: Data
    ) -> CompoundOperationWrapper<Data> {
        guard let application = supportedApps.first(where: { $0.chainId == chainId }) else {
            return CompoundOperationWrapper.createWithError(LedgerApplicationError.unsupportedApp(chainId: chainId))
        }

        let chunks: [Data] = [derivationPath] + payload.chunked(by: Constants.chunkSize)

        let requestOperations: [LedgerSendOperation] = chunks.enumerated().map { indexedChunk in
            let type = PayloadType(chunkIndex: indexedChunk.offset, totalChunks: chunks.count)

            let message = LedgerApplicationRequest(
                cla: application.cla,
                instruction: Instruction.sign.rawValue,
                param1: type.rawValue,
                param2: CryptoScheme.ed25519.rawValue,
                payload: indexedChunk.element
            ).toBytes()

            return LedgerSendOperation(connection: connectionManager, deviceId: deviceId, message: message)
        }

        for index in 0 ..< (requestOperations.count - 1) {
            requestOperations[index + 1].addDependency(requestOperations[index])
        }

        guard let targetOperation = requestOperations.last else {
            return CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
        }

        let responseOperation = ClosureOperation<LedgerSignature> {
            let data = try targetOperation.extractNoCancellableResultData()

            return try LedgerResponse<LedgerSignature>(ledgerData: data).value
        }

        responseOperation.addDependency(targetOperation)

        return CompoundOperationWrapper(targetOperation: responseOperation, dependencies: requestOperations)
    }
}
