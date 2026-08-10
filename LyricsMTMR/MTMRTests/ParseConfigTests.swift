import XCTest
@testable import LyricsMTMR

class ParseConfig: XCTestCase {
    func testButtonNoAction() {
        let buttonNoActionFixture = """
            [  { "type": "staticButton",  "title": "Pew" } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: buttonNoActionFixture)
        guard case .staticButton("Pew")? = result?.first?.type else {
            XCTFail()
            return
        }
        guard result?.first?.actions.count == 0 else {
            XCTFail()
            return
        }
    }

    func testButtonKeyCodeAction() {
        let buttonKeycodeFixture = """
            [  { "type": "staticButton",  "title": "Pew", "actions": [ { "trigger": "singleTap", "action": "hidKey", "keycode": 123 } ] } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: buttonKeycodeFixture)
        guard case .staticButton("Pew")? = result?.first?.type else {
            XCTFail()
            return
        }
        guard case .hidKey(keycode: 123)? = result?.first?.actions.filter({ $0.trigger == .singleTap }).first?.value else {
            XCTFail()
            return
        }
    }
    
    func testButtonKeyCodeLegacyAction() {
        let buttonKeycodeFixture = """
            [  { "type": "staticButton",  "title": "Pew", "action": "hidKey", "keycode": 123 } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: buttonKeycodeFixture)
        guard case .staticButton("Pew")? = result?.first?.type else {
            XCTFail()
            return
        }
        guard case .hidKey(keycode: 123)? = result?.first?.legacyAction else {
            XCTFail()
            return
        }
    }

    func testPredefinedItem() {
        let buttonKeycodeFixture = """
            [  { "type": "escape" } ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: buttonKeycodeFixture)
        guard case .staticButton("esc")? = result?.first?.type else {
            XCTFail()
            return
        }
        guard case .keyPress(keycode: 53)? = result?.first?.actions.filter({ $0.trigger == .singleTap }).first?.value else {
            XCTFail()
            return
        }
    }

    func testExtendedWidthForPredefinedItem() {
        let buttonKeycodeFixture = """
            [  { "type": "escape", "width": 110}, ]
        """.data(using: .utf8)!
        let result = try? JSONDecoder().decode([BarItemDefinition].self, from: buttonKeycodeFixture)
        guard case .staticButton("esc")? = result?.first?.type else {
            XCTFail()
            return
        }
        guard case .keyPress(keycode: 53)? = result?.first?.actions.filter({ $0.trigger == .singleTap }).first?.value else {
            XCTFail()
            return
        }
        guard case .width(110)? = result?.first?.additionalParameters[.width] else {
            XCTFail()
            return
        }
    }

    // P0-3 回归：非法 JSON 必须返回 nil（回退默认布局）而不是崩溃。
    func testInvalidJSONReturnsNilInsteadOfCrash() {
        let brokenFixtures: [Data?] = [
            "{ this is not json".data(using: .utf8),
            "[ 1, 2, 3 ]".data(using: .utf8),
            #"[ { "type": "staticButton", "title": } ]"#.data(using: .utf8),
            "".data(using: .utf8),
        ]
        for fixture in brokenFixtures {
            guard let fixture = fixture else { continue }
            let result = fixture.barItemDefinitions()
            XCTAssertNil(result, "非法 JSON 应返回 nil 而不是崩溃: \(fixture)")
        }
    }

    // P0-3 回归：合法 JSON 仍应正常解析（行为不回归）。
    func testValidJSONStillParses() {
        let fixture = """
            [  { "type": "staticButton",  "title": "Pew" } ]
        """.data(using: .utf8)!
        let result = fixture.barItemDefinitions()
        guard case .staticButton("Pew")? = result?.first?.type else {
            XCTFail("合法 JSON 应正常解析")
            return
        }
    }
}
