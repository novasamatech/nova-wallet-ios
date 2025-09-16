import Foundation
@testable import novawallet
import Operation_iOS
import NovaCrypto

enum CloudBackupFetchHelper {
    static func fetchBackup(
        using serviceFactory: CloudBackupServiceFactoryProtocol,
        password: String
    ) throws -> CloudBackup.DecryptedFileModel? {
        let fileManager = serviceFactory.createFileManager()

        let operationFactory = serviceFactory.createOperationFactory()

        let readOperation = operationFactory.createReadingOperation(for: fileManager.getFileUrl()!)

        let operationQueue = OperationQueue()

        operationQueue.addOperations([readOperation], waitUntilFinished: true)

        guard let data = try readOperation.extractNoCancellableResultData() else {
            return nil
        }

        let encryptedModel = try serviceFactory.createCodingManager().decode(data: data)

        let encryptedData = try Data(hexString: encryptedModel.privateData)
        let decryptedData = try serviceFactory.createCryptoManager().decrypt(
            data: encryptedData,
            password: password
        )

        let privateModel = try JSONDecoder().decode(
            CloudBackup.DecryptedFileModel.PrivateData.self,
            from: decryptedData
        )

        return .init(
            publicData: encryptedModel.publicData,
            privateDate: privateModel
        )
    }
}
