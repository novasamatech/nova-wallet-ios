import XCTest
@testable import novawallet

final class MoneyPresentableTests: XCTestCase {
    let moneyPresentable = MoneyPresentableMock()
    
    override func setUpWithError() throws {
        moneyPresentable.amount = ""
    }
    
    func testWhenAddNumberToEmptyInput_ThanResultCorrectPercent() {
        let addingSymbol = "3"
        let expectation = "3 %"
        
        let result = moneyPresentable.add(addingSymbol)
        XCTAssertEqual(result, expectation)
    }
    
    func testWhenAddNumberToNonEmptyInput_ThanResultCorrectPercent() {
        let text = "1 %"
        let addingSymbol = "2"
        let expectation = "12 %"
        moneyPresentable.amount = text
        let result = moneyPresentable.add(addingSymbol)
        
        XCTAssertEqual(result, expectation)
    }
    
    func testWhenSetNumberWithPercent_ThanResultCorrectPercent() {
        let setAmount = "5%"
        let expectation = "5 %"
        
        let result = moneyPresentable.set(setAmount)
        
        XCTAssertEqual(result, expectation)
    }
    
    func testWhenSetNumber_ThanResultCorrectPercent() {
        let setAmount = "2.5"
        let expectation = "2.5 %"
        
        let result = moneyPresentable.set(setAmount)
        
        XCTAssertEqual(result, expectation)
    }
    
    func testWhenSetInvalidNumber_ThanResultNotChanged() {
        let setAmount = "0.1 %%"
        let expectation = "1 %"
        moneyPresentable.amount = "1 %"
        
        let result = moneyPresentable.set(setAmount)
        
        XCTAssertEqual(result, expectation)
    }
    
}
