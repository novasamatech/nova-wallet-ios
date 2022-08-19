import Foundation
import RobinHood

protocol LedgerApplicationProtocol {
    func getAccountWrapper(
        for deviceId: UUID,
        chainId: ChainModel.Id,
        index: UInt32
    ) -> CompoundOperationWrapper<LedgerAccount>

    func getSignWrapper(
        for payload: Data,
        deviceId: UUID,
        chainId: ChainModel.Id,
        accountIndex: UInt32
    ) -> CompoundOperationWrapper<Data>
}

enum LedgerApplicationError: Error {
    case unsupportedApp(chainId: ChainModel.Id)
}

final class LedgerApplication {
    private enum Constants {
        static let publicKeyLength = 32
        static let responseCodeLength = 2
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
        index: UInt32,
        displayVerificationDialog: Bool = false,
        cryptoScheme: CryptoScheme = .ed25519
    ) -> BaseOperation<Data> {
        ClosureOperation {
            let path = LedgerPathBuilder()
                .appendingStandardJunctions(coin: application.coin, accountIndex: index)
                .build()

            var message = Data()
            message.append(application.cla)
            message.append(Instruction.getAddress.rawValue)
            message.append(UInt8(displayVerificationDialog ? 0x01 : 0x00))
            message.append(cryptoScheme.rawValue)
            message.append(UInt8(path.count))
            message.append(contentsOf: path)

            return message
        }
    }

    private func createAccountResponseOperation(
        dependingOn sendOperation: LedgerSendOperation
    ) -> BaseOperation<LedgerAccount> {
        ClosureOperation {
            let data = try sendOperation.extractNoCancellableResultData()

            let responseCodeData: Data = data.suffix(Constants.responseCodeLength)
            guard responseCodeData.count == Constants.responseCodeLength else {
                throw LedgerError.unexpectedData("No response code")
            }

            let response = LedgerResponse(responseCode: UInt16(bigEndianData: responseCodeData))

            guard response == .noError else {
                throw LedgerError.response(code: response)
            }

            let dataWithoutResponseCode = data.dropLast(Constants.responseCodeLength)

            let publicKey: Data = dataWithoutResponseCode.prefix(Constants.publicKeyLength)
            guard publicKey.count == Constants.publicKeyLength else {
                throw LedgerError.unexpectedData("No public key")
            }

            let accountAddressData = dataWithoutResponseCode.dropFirst(Constants.publicKeyLength)

            guard
                let accountAddress = AccountAddress(data: accountAddressData, encoding: .ascii),
                (try? accountAddress.toAccountId()) != nil else {
                throw LedgerError.unexpectedData("Invalid account address")
            }

            return LedgerAccount(address: accountAddress, publicKey: publicKey)
        }
    }
}

extension LedgerApplication: LedgerApplicationProtocol {
    /// https://github.com/Zondax/ledger-substrate-js/blob/main/src/substrate_app.ts#L143
    func getAccountWrapper(
        for deviceId: UUID,
        chainId: ChainModel.Id,
        index: UInt32
    ) -> CompoundOperationWrapper<LedgerAccount> {
        guard let application = supportedApps.first(where: { $0.chainId == chainId }) else {
            return CompoundOperationWrapper.createWithError(LedgerApplicationError.unsupportedApp(chainId: chainId))
        }

        let messageOperation = createAccountMessageOperation(for: application, index: index)

        let sendOperation = LedgerSendOperation(connection: connectionManager, deviceId: deviceId)
        sendOperation.configurationBlock = {
            do {
                sendOperation.message = try messageOperation.extractNoCancellableResultData()
            } catch {
                sendOperation.result = .failure(error)
            }
        }

        sendOperation.addDependency(messageOperation)

        let responseOperation = createAccountResponseOperation(dependingOn: sendOperation)

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
        accountIndex: UInt32
    ) -> CompoundOperationWrapper<Data> {
        guard let application = supportedApps.first(where: { $0.chainId == chainId }) else {
            return CompoundOperationWrapper.createWithError(LedgerApplicationError.unsupportedApp(chainId: chainId))
        }

        let path = LedgerPathBuilder()
            .appendingStandardJunctions(coin: application.coin, accountIndex: accountIndex)
            .build()

        let chunks: [Data] = [path] + payload.chunked(by: Constants.chunkSize)

        let operations: [LedgerSendOperation] = chunks.enumerated().map { indexedChunk in
            let type = PayloadType(chunkIndex: indexedChunk.offset, totalChunks: chunks.count)

            var message = Data()
            message.append(application.cla)
            message.append(Instruction.sign.rawValue)
            message.append(type.rawValue)
            message.append(CryptoScheme.ed25519.rawValue)

            if !indexedChunk.element.isEmpty {
                if indexedChunk.element.count < 256 {
                    message.append(UInt8(indexedChunk.element.count))
                } else {
                    message.append(0)
                    message.append(contentsOf: UInt16(indexedChunk.element.count).bigEndianBytes)
                }

                message.append(indexedChunk.element)
            }

            return LedgerSendOperation(connection: connectionManager, deviceId: deviceId, message: message)
        }

        for index in 0 ..< (operations.count - 1) {
            operations[index + 1].addDependency(operations[index])
        }

        guard let targetOperation = operations.last else {
            return CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
        }

        let dependencies = operations.dropLast()

        return CompoundOperationWrapper(targetOperation: targetOperation, dependencies: Array(dependencies))
    }
}
