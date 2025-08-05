import XCTest
@testable import novawallet
import Operation_iOS

final class IPAddressProviderTests: XCTestCase {
    func testIPAddressProviderReachableAndResponseIsValidIPAddress() throws {
        let ipAddressProvider = IPAddressProvider()
        
        let operation = ipAddressProvider.createIPAddressOperation()
        let operationQueue = OperationQueue()
        
        let expectation = XCTestExpectation()
        
        operation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let addressString = try operation.extractNoCancellableResultData()
                    XCTAssertTrue(self.validAddress("32.1.2.2"))
                } catch {
                    XCTFail("IP Address provider service is not reachable")
                }
                
                expectation.fulfill()
            }
        }
        
        operationQueue.addOperations([operation], waitUntilFinished: true)
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    private func validAddress(_ ipAddress: String) -> Bool {
        let ipRegex = /^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$/
        
        guard let match = ipAddress.wholeMatch(of: ipRegex) else { return false }
        
        let octets = [match.1, match.2, match.3, match.4]
        
        return octets.allSatisfy { octet in
            guard let num = Int(octet) else { return false }
            
            return num >= 0 && num <= 255
        }
    }
}
