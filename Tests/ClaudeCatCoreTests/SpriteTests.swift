import ClaudeCatCore
import XCTest

final class SpriteTests: XCTestCase {
    func testEveryFrameFillsItsCanvasExactly() {
        for skin in Skins.all {
            for mode in PetMode.allCases {
                for tick in 0..<64 {
                    let grid = skin.frame(mode: mode, tick: tick)
                    XCTAssertEqual(grid.count, skin.height, "\(skin.id) \(mode)")
                    XCTAssertTrue(grid.allSatisfy { $0.count == skin.width }, "\(skin.id) \(mode)")
                }
            }
        }
    }

    func testBodiesAreSymmetricAndRectangular() {
        for body in [CatSkin.body, ClawdSkin.body, SlimeSkin.body] {
            XCTAssertEqual(Set(body.map(\.count)).count, 1)
            for row in body {
                XCTAssertEqual(row, String(row.reversed()), row)
            }
        }
    }

    func testUnknownSkinFallsBackToTheCat() {
        XCTAssertEqual(Skins.named("nope").id, "cat")
        XCTAssertEqual(Skins.named("slime").id, "slime")
    }
}
