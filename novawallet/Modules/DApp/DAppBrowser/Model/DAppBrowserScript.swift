import Foundation
import WebKit

struct DAppBrowserScript {
    enum InsertionPoint {
        case atDocStart
        case atDocEnd
    }

    let content: String
    let insertionPoint: InsertionPoint
}

extension DAppBrowserScript.InsertionPoint {
    var wkInsertionPoint: WKUserScriptInjectionTime {
        switch self {
        case .atDocStart:
            return .atDocumentStart
        case .atDocEnd:
            return .atDocumentEnd
        }
    }
}
