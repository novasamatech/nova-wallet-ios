import Foundation
import Operation_iOS

/**
 *  Class is designed to provide file management functions. Instance of the class
 *  contains instance of the `FileRepositoryProtocol` which performs file reading and
 *  writing and directory where files should be stored.
 */

class FilesOperationFactory {
    /// Engine that reads and writes files from filesystem
    let repository: FileRepositoryProtocol

    /// Path to the directory where files are stored
    let directoryPath: String

    /**
     *  Creates instance a new instance for files management.
     *
     *  - Parameters:
     *      - repository: Engine that reads and writes files from filesystem;
     *      - directoryPath: Path to the directory where files are stored.
     */

    init(repository: FileRepositoryProtocol, directoryPath: String) {
        self.repository = repository
        self.directoryPath = directoryPath
    }

    func fetchFileOperation(for fileName: String) -> CompoundOperationWrapper<Data?> {
        let createDirOperation = repository.createDirectoryIfNeededOperation(at: directoryPath)

        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)

        let readOperation = repository.readOperation(at: filePath)
        readOperation.addDependency(createDirOperation)

        return CompoundOperationWrapper(
            targetOperation: readOperation,
            dependencies: [createDirOperation]
        )
    }

    func saveFileOperation(
        for fileName: String,
        data: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        let createDirOperation = repository.createDirectoryIfNeededOperation(at: directoryPath)

        let filePath = (directoryPath as NSString).appendingPathComponent(fileName)

        let writeOperation = repository.writeOperation(dataClosure: data, at: filePath)
        writeOperation.addDependency(createDirOperation)

        return CompoundOperationWrapper(
            targetOperation: writeOperation,
            dependencies: [createDirOperation]
        )
    }
}
