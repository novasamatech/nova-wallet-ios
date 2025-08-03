import Foundation

protocol DAppAssertionCallFactory {
    func createDAppResponse() throws -> DAppScriptResponse
}
