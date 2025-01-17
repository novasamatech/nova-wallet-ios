import Foundation
import UIKit
import Operation_iOS

protocol DAppBrowserTabRenderProtocol {
    func serializationOperation() -> BaseOperation<Data?>
}

struct DAppBrowserTabRender {
    private let snapshot: UIImage?

    init(for snapshot: UIImage?) {
        self.snapshot = snapshot
    }
}

// MARK: DAppBrowserTabStateRenderProtocol

extension DAppBrowserTabRender: DAppBrowserTabRenderProtocol {
    func serializationOperation() -> BaseOperation<Data?> {
        ClosureOperation { snapshot?.pngData() }
    }
}
