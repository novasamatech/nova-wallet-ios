import Foundation
import SubstrateSdk
import RobinHood

protocol PrettyPrintedJSONOperationFactoryProtocol {
    func createProcessingOperation(
        for json: JSON
    ) -> BaseOperation<String>
}

final class PrettyPrintedJSONOperationFactory: PrettyPrintedJSONOperationFactoryProtocol {
    let preprocessor: JSONPrettyPrinting

    init(preprocessor: JSONPrettyPrinting) {
        self.preprocessor = preprocessor
    }

    func createProcessingOperation(
        for json: JSON
    ) -> BaseOperation<String> {
        ClosureOperation<String> { [weak self] in
            guard let self = self else {
                return ""
            }
            let prettyPrintedJson = self.preprocessor.prettyPrinted(from: json)

            if case let .stringValue(value) = prettyPrintedJson {
                return value
            } else {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted

                let data = try encoder.encode(prettyPrintedJson)

                if let displayString = String(data: data, encoding: .utf8) {
                    return displayString
                } else {
                    throw CommonError.undefined
                }
            }
        }
    }
}
