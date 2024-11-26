import Foundation
import Operation_iOS

/**
 *  Protocol is designed for fetching and saving files representing runtime
 *  types.
 */

protocol RuntimeFilesOperationFactoryProtocol {
    /**
     *  Constructs an operations wrapper that fetches data of
     *  common runtime types from corresponding file.
     *
     *  - Returns: `CompoundOperationWrapper` which produces data
     *  in case file exists on device and `nil` otherwise.
     */
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>

    /**
     *  Constructs an operations wrapper that fetches data of the
     *  runtime types from a file which matches concrete chain's id.
     *
     *  - Parameters:
     *      - chainId: Idetifier of a chain for which runtime types data
     *  must be fetched.
     *
     *  - Returns: `CompoundOperationWrapper` which produces data
     *  in case file exists on device and `nil` otherwise.
     */
    func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?>

    /**
     *  Constructs an operations wrapper that saves data of the
     *  runtime types to the corresponding file.
     *
     *  - Parameters:
     *      - closure: A closure that returns file's data on call. It is guaranteed that
     *       the closure will be called as part of the wrapper execution and not earlier.
     *       This allows to make save wrapper to depend on another operation which fetches
     *       the file from another source asynchroniously.
     *
     *  - Returns: `CompoundOperationWrapper` which produces nothing if completes successfully.
     */
    func saveCommonTypesOperation(
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>

    /**
     *  Constructs an operations wrapper that saves data of the
     *  chain's specific runtime types to the corresponding file.
     *
     *  - Parameters:
     *      - chainId: Identifier of the chain for which runtime types must be stored
     *      - closure: A closure that returns file's data on call. It is guaranteed that
     *       the closure will be called as part of the wrapper execution and not earlier.
     *       This allows to make save wrapper to depend on another operation which fetches
     *       the file from another source asynchroniously.
     *
     *  - Returns: `CompoundOperationWrapper` which produces nothing if completes successfully.
     */
    func saveChainTypesOperation(
        for chainId: ChainModel.Id,
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>
}

/**
 *  Common types file has `common-types` name. Chain type file hash $(chainId)-types name.
 */

final class RuntimeFilesOperationFactory: FilesOperationFactory {}

extension RuntimeFilesOperationFactory: RuntimeFilesOperationFactoryProtocol {
    func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
        fetchFileOperation(for: "common-types")
    }

    func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?> {
        fetchFileOperation(for: "\(chainId)-types")
    }

    func saveCommonTypesOperation(
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        saveFileOperation(for: "common-types", data: closure)
    }

    func saveChainTypesOperation(
        for chainId: ChainModel.Id, data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void> {
        saveFileOperation(for: "\(chainId)-types", data: closure)
    }
}
