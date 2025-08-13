import Foundation
import Operation_iOS

typealias LedgerPayloadClosure = () throws -> Data

enum LedgerCryptoScheme: UInt8 {
    case ed25519 = 0x00
    case sr25519 = 0x01
    case ecdsa = 0x02
}

enum LedgerConstants {
    static let chunkSize = 250
    static let defaultSubstrateCryptoScheme: LedgerCryptoScheme = .ed25519
    static let defaultEvmCryptoScheme: LedgerCryptoScheme = .ecdsa
}

class PolkadotLedgerCommonApplication {
    enum Instruction: UInt8 {
        case getAddress = 0x01
        case sign = 0x02
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

    init(connectionManager: LedgerConnectionManagerProtocol) {
        self.connectionManager = connectionManager
    }

    func createAccountMessageOperation(
        for cla: UInt8,
        payloadClosure: @escaping LedgerPayloadClosure,
        displayVerificationDialog: Bool,
        cryptoScheme: LedgerCryptoScheme
    ) -> BaseOperation<Data> {
        ClosureOperation {
            let payload = try payloadClosure()

            let message = LedgerApplicationRequest(
                cla: cla,
                instruction: Instruction.getAddress.rawValue,
                param1: UInt8(displayVerificationDialog ? 0x01 : 0x00),
                param2: cryptoScheme.rawValue,
                payload: payload
            ).toBytes()

            return message
        }
    }

    func createAccountResponseOperation<A: LedgerAccountProtocol>(
        dependingOn sendOperation: LedgerSendOperation,
        path: Data
    ) -> BaseOperation<LedgerAccountResponse<A>> {
        ClosureOperation {
            let data = try sendOperation.extractNoCancellableResultData()

            let account = try LedgerResponse<A>(ledgerData: data).value

            return LedgerAccountResponse(account: account, derivationPath: path)
        }
    }

    func prepareAccountWrapper<A: LedgerAccountProtocol>(
        for deviceId: UUID,
        cla: UInt8,
        derivationPath: Data,
        payloadClosure: @escaping LedgerPayloadClosure,
        cryptoScheme: LedgerCryptoScheme,
        displayVerificationDialog: Bool = false
    ) -> CompoundOperationWrapper<LedgerAccountResponse<A>> {
        let messageOperation = createAccountMessageOperation(
            for: cla,
            payloadClosure: payloadClosure,
            displayVerificationDialog: displayVerificationDialog,
            cryptoScheme: cryptoScheme
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

        let responseOperation: BaseOperation<LedgerAccountResponse<A>> = createAccountResponseOperation(
            dependingOn: sendOperation,
            path: derivationPath
        )

        responseOperation.addDependency(sendOperation)

        return CompoundOperationWrapper(
            targetOperation: responseOperation,
            dependencies: [messageOperation, sendOperation]
        )
    }

    func prepareSignatureWrapper(
        for deviceId: UUID,
        cla: UInt8,
        cryptoScheme: LedgerCryptoScheme,
        chunks: [LedgerPayloadClosure]
    ) -> CompoundOperationWrapper<Data> {
        let requestOperations: [LedgerSendOperation] = chunks.enumerated().map { indexedChunk in
            let type = PayloadType(chunkIndex: indexedChunk.offset, totalChunks: chunks.count)

            let operation = LedgerSendOperation(connection: connectionManager, deviceId: deviceId)
            operation.configurationBlock = {
                do {
                    let chunk = try indexedChunk.element()

                    let message = LedgerApplicationRequest(
                        cla: cla,
                        instruction: Instruction.sign.rawValue,
                        param1: type.rawValue,
                        param2: cryptoScheme.rawValue,
                        payload: chunk
                    ).toBytes()

                    operation.message = message
                } catch {
                    operation.result = .failure(error)
                }
            }

            return operation
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
