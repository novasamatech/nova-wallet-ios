import Foundation
import UIKit
import Operation_iOS

protocol DAppBrowserTabRendererProtocol {
    func renderDataWrapper(using operationQueue: OperationQueue) -> CompoundOperationWrapper<Data?>
}

struct DAppBrowserTabRenderer {
    private let layer: CALayer

    init(for layer: CALayer) {
        self.layer = layer
    }
}

// MARK: Private

private extension DAppBrowserTabRenderer {
    func fetchViewPropertiesOperation() -> AsyncClosureOperation<(layer: CALayer, bounds: CGRect)> {
        AsyncClosureOperation { resultClosure in
            DispatchQueue.main.async {
                let bounds = layer.bounds

                resultClosure(.success((layer, bounds)))
            }
        }
    }

    func createRenderDataOperation(
        layer: CALayer,
        bounds: CGRect
    ) -> CompoundOperationWrapper<Data?> {
        let operation = ClosureOperation {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)

            let image = renderer.image { rendererContext in
                layer.render(in: rendererContext.cgContext)
            }

            let imageData = image.pngData()

            return imageData
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

// MARK: DAppBrowserTabStateRendererProtocol

extension DAppBrowserTabRenderer: DAppBrowserTabRendererProtocol {
    func renderDataWrapper(using operationQueue: OperationQueue) -> CompoundOperationWrapper<Data?> {
        let propertiesFetchOperation = fetchViewPropertiesOperation()

        let resultWrapper = OperationCombiningService.compoundOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let (layer, bounds) = try propertiesFetchOperation.extractNoCancellableResultData()

            return createRenderDataOperation(layer: layer, bounds: bounds)
        }

        resultWrapper.addDependency(operations: [propertiesFetchOperation])

        return resultWrapper.insertingHead(operations: [propertiesFetchOperation])
    }
}
