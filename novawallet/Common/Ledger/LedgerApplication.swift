import Foundation

protocol LedgerApplicationProtocol {
    func getAccount(
        for deviceId: UUID,
        cla: UInt8,
        path: String,
        completion: @escaping (Result<LedgerAccount, Error>) -> Void
    )
}

class LedgerApplication {
    private enum Constants {
        static let publicKeyLength = 32
        static let responseCodeLength = 2
    }

    enum Instruction: UInt8 {
        case getAddress = 0x01
        case sign = 0x02
    }

    enum CryptoScheme: UInt8 {
        case ed25519 = 0x00
        case sr25519 = 0x01
    }

    let connectionManager: LedgerConnectionManagerProtocol

    init(connectionManager: LedgerConnectionManagerProtocol) {
        self.connectionManager = connectionManager
    }

    func getAccount(
        for deviceId: UUID,
        cla: UInt8,
        path: String,
        completion: @escaping (Result<LedgerAccount, Error>) -> Void
    ) {
        let command = getAddressCommand(cla: cla, path: path)

        connectionManager.send(message: command, deviceId: deviceId) { result in
            switch result {
            case let .success(data):
                let responseCodeData: Data = data.suffix(Constants.responseCodeLength)
                guard responseCodeData.count == Constants.responseCodeLength else {
                    completion(.failure(LedgerError.unexpectedData("No response code")))
                    return
                }

                let response = LedgerResponse(data: responseCodeData)

                guard response == .noError else {
                    completion(.failure(LedgerError.response(code: response)))
                    return
                }

                let dataWithoutResponseCode = data.dropLast(Constants.responseCodeLength)

                let publicKey: Data = dataWithoutResponseCode.prefix(Constants.publicKeyLength)
                guard publicKey.count == Constants.publicKeyLength else {
                    completion(.failure(LedgerError.unexpectedData("No public key")))
                    return
                }

                let accountAddressData = dataWithoutResponseCode.dropFirst(Constants.publicKeyLength)

                guard
                    let accountAddress = AccountAddress(data: accountAddressData, encoding: .ascii),
                    (try? accountAddress.toAccountId()) != nil else {
                    completion(.failure(LedgerError.unexpectedData("Invalid account address")))
                    return
                }

                let account = LedgerAccount(address: accountAddress, publicKey: publicKey)

                completion(.success(account))

            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private func getAddressCommand(
        cla: UInt8,
        path: String,
        displayVerificationDialog: Bool = false,
        cryptoScheme: CryptoScheme = .ed25519
    ) -> Data {
        let paths = splitPath(path: path)

        var command = Data()
        var pathsData = Data()
        paths.forEach { element in
            let array = withUnsafeBytes(of: element.bigEndian, Array.init)
            array.forEach { x in pathsData.append(x) }
        }

        command.append(cla)
        command.append(Instruction.getAddress.rawValue)
        command.append(UInt8(displayVerificationDialog ? 0x01 : 0x00))
        command.append(cryptoScheme.rawValue)
        command.append(pathsData)

        return command
    }

    private func splitPath(path: String) -> [UInt32] {
        var result: [UInt32] = []
        let components = path.components(separatedBy: "/")
        components.forEach { component in
            var number = UInt32(0)
            var numberText = component
            if component.count > 1, component.hasSuffix("\'") {
                number = 0x8000_0000
                numberText = String(component.dropLast(1))
            }

            if let index = UInt32(numberText) {
                number = number + index
                result.append(number)
            }
        }

        return result
    }
}
