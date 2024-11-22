import Foundation
import Operation_iOS

/**
 *  Protocol is designed for fetching and saving files representing webview's renders
 */

protocol WebViewRenderFilesOperationFactoryProtocol {
    /**
     *  Constructs an operations wrapper that fetches data of
     *  webview render from a file which matches concrete webview tab id.
     *
     *  - Parameters:
     *      - id: Idetifier of a webview for which render data
     *  must be fetched.
     *
     *  - Returns: `CompoundOperationWrapper` which produces data
     *  in case file exists on device and `nil` otherwise.
     */
    func fetchRender(for id: UUID) -> CompoundOperationWrapper<Data?>

    /**
     *  Constructs an operations wrapper that saves data of the
     *  webview render to the corresponding file.
     *
     *  - Parameters:
     *      - id: Identifier of the webview tab for which render must be stored
     *      - closure: A closure that returns file's data on call. It is guaranteed that
     *       the closure will be called as part of the wrapper execution and not earlier.
     *       This allows to make save wrapper to depend on another operation which fetches
     *       the file from another source asynchroniously.
     *
     *  - Returns: `CompoundOperationWrapper` which produces nothing if completes successfully.
     */
    func saveRenderOperation(
        for id: UUID,
        data closure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<Void>

    /**
     *  Constructs an operations wrapper that removes data of
     *  webview render by removing a file which matches concrete webview tab id.
     *
     *  - Parameters:
     *      - id: Idetifier of a webview for which render data
     *  must be removed.
     *
     *  - Returns: `BaseOperation` which produces void
     *  in case file removed succesfully.
     */
    func removeRender(for id: UUID) -> CompoundOperationWrapper<Void>

    /**
     *  Constructs an operations wrapper that removes data of
     *  webview renders by removing a files which matches concrete webview tab ids.
     *
     *  - Parameters:
     *      - ids: Idetifier of a webviews for which render data
     *  must be removed.
     *
     *  - Returns: `BaseOperation` which produces void
     *  in case files removed succesfully.
     */
    func removeRenders(for ids: [UUID]) -> CompoundOperationWrapper<Void>
}

extension RuntimeFilesOperationFactory: WebViewRenderFilesOperationFactoryProtocol {
    func fetchRender(for id: UUID) -> Operation_iOS.CompoundOperationWrapper<Data?> {
        fetchFileOperation(for: id.uuidString)
    }

    func saveRenderOperation(
        for id: UUID,
        data closure: @escaping () throws -> Data
    ) -> Operation_iOS.CompoundOperationWrapper<Void> {
        saveFileOperation(
            for: id.uuidString,
            data: closure
        )
    }

    func removeRender(for id: UUID) -> Operation_iOS.CompoundOperationWrapper<Void> {
        let filePath = (directoryPath as NSString).appendingPathComponent(id.uuidString)

        return CompoundOperationWrapper(
            targetOperation: repository.removeOperation(at: filePath)
        )
    }

    func removeRenders(for ids: [UUID]) -> Operation_iOS.CompoundOperationWrapper<Void> {
        let filePaths = ids.map { id in
            (directoryPath as NSString).appendingPathComponent(id.uuidString)
        }

        return CompoundOperationWrapper(
            targetOperation: repository.removeOperation(at: filePaths)
        )
    }
}
