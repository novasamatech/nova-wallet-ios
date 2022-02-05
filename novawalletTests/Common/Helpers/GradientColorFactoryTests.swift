import XCTest
@testable import novawallet

class GradientColorFactoryTests: XCTestCase {
    func testTwoColorsGradient() {
        // given

        let css = "linear-gradient(315deg, #D43079 0%, #F93C90 100%)"

        let expectedColor = GradientModel(
            startPoint: CGPoint(x: 1.0, y: 1.0),
            endPoint: CGPoint(x: 0.0, y: 0.0),
            colors: [
                UIColor(hex: "#D43079")!,
                UIColor(hex: "#F93C90")!
            ],
            locations: [ 0.0, 1.0]
        )

        // when

        let actualColor = CSSGradientFactory().createFromString(css)

        // then

        XCTAssertEqual(expectedColor, actualColor)
    }

    func testNoColorsGradient() {
        // given

        let css = "linear-gradient(315deg)"

        let expectedColor: GradientModel? = nil

        // when

        let actualColor = CSSGradientFactory().createFromString(css)

        // then

        XCTAssertEqual(expectedColor, actualColor)
    }

    func testFourColorsAndDecimalPercentagesGradient() {
        // given

        let css = "linear-gradient(135deg, #12D5D5 0%, #4584F5 40.32%, #AC57C0 60.21%, #E65659 80.19%, #FFBF12 100%)"

        let expectedColor = GradientModel(
            startPoint: CGPoint(x: 0.0, y: 0.0),
            endPoint: CGPoint(x: 1.0, y: 1.0),
            colors: [
                UIColor(hex: "#12D5D5")!,
                UIColor(hex: "#4584F5")!,
                UIColor(hex: "#AC57C0")!,
                UIColor(hex: "#E65659")!,
                UIColor(hex: "#FFBF12")!
            ],
            locations: [ 0.0, 0.4032, 0.6021, 0.8019, 1.0]
        )

        // when

        let actualColor = CSSGradientFactory().createFromString(css)

        // then

        XCTAssertEqual(expectedColor, actualColor)
    }

    func testDecimalDegreeGradient() {
        // given

        let css = "linear-gradient(97.21deg, #E40C5B 0%, #645AFD 100%)"

        let expectedColor = GradientModel(
            startPoint: CGPoint(x: 0.0, y: 0.5),
            endPoint: CGPoint(x: 1.0, y: 0.5),
            colors: [
                UIColor(hex: "#E40C5B")!,
                UIColor(hex: "#645AFD")!
            ],
            locations: [ 0.0, 1.0]
        )

        // when

        let actualColor = CSSGradientFactory().createFromString(css)

        // then

        XCTAssertEqual(expectedColor, actualColor)
    }
}
