import XCTest

// 紹介動画の振り付け。XCUITestでアプリを操作し、各イベントの壁時計を timeline.json に書く
@MainActor
final class DemoFlow: XCTestCase {
    private var events: [[String: Any]] = []
    private let out = ProcessInfo.processInfo.environment["PROMO_TIMELINE"] ?? "/tmp/tododo-timeline.json"
    private let app = XCUIApplication()

    func testDemo() {
        continueAfterFailure = true
        mark("launching")
        app.launch()
        mark("launched")
        pause(1.6)

        // 1) 今日に3件を連続入力（キーボードは起動時に開いている）
        for text in ["牛乳を買う", "メールに返信する", "銀行に振込に行く"] {
            typeSlowly(text)
            app.typeText("\n")
            mark("added:\(text)")
            pause(0.5)
        }
        pause(0.4)

        // 2) 明日・いつかにも1件ずつ（見出しの＋）
        app.buttons["add.tomorrow"].tap()
        mark("tapAddTomorrow")
        pause(0.5)
        typeSlowly("請求書の支払い")
        app.typeText("\n")
        mark("added:請求書の支払い")
        pause(0.5)
        app.buttons["add.someday"].tap()
        mark("tapAddSomeday")
        pause(0.5)
        typeSlowly("本棚の整理")
        app.typeText("\n")
        mark("added:本棚の整理")
        pause(0.6)

        // 3) 空き領域タップでキーボードを閉じる
        app.staticTexts["いつか"].tap()
        mark("keyboardDismissed")
        pause(1.0)

        // 4) 右スワイプで完了
        let done = app.staticTexts["メールに返信する"]
        let s = done.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        s.press(forDuration: 0.05, thenDragTo: s.withOffset(CGVector(dx: 170, dy: 0)))
        mark("swipedDone")
        pause(1.2)

        // 5) グリップで「銀行に振込に行く」を明日へドラッグ（見出しを跨ぐ）
        let row = app.staticTexts["銀行に振込に行く"]
        let header = app.staticTexts["明日"]
        let grip = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.frame.maxX - 28, dy: row.frame.midY))
        let target = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.frame.maxX - 28, dy: header.frame.maxY + 52))
        mark("dragStart")
        grip.press(forDuration: 0.4, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.3)
        mark("dragEnd")
        pause(1.2)

        // 6) 今日に2件足してから ✨ で実行順にソート（Apple Intelligence）
        app.buttons["add.today"].tap()
        pause(0.5)
        typeSlowly("夕食の買い物")
        app.typeText("\n")
        mark("added:夕食の買い物")
        pause(0.3)
        typeSlowly("朝のストレッチ")
        app.typeText("\n")
        mark("added:朝のストレッチ")
        pause(0.4)
        app.staticTexts["いつか"].tap()
        pause(0.8)
        let sort = app.buttons["sort"]
        if sort.waitForExistence(timeout: 3) {
            sort.tap()
            mark("sortTapped")
            pause(0.5)
            _ = sort.waitForExistence(timeout: 30)  // ソート中はスピナーに置き換わる。戻るまで待つ
            mark("sortDone")
            pause(2.5)
        }
        pause(1.5)
        mark("end")
    }

    private func typeSlowly(_ text: String) {
        app.typeText(text)  // 1文字ずつだと1文字0.6秒かかるので一括入力
        mark("typed:\(text)")
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func mark(_ name: String) {
        events.append(["name": name, "t": Date().timeIntervalSince1970])
        let data = try? JSONSerialization.data(withJSONObject: ["events": events], options: [.prettyPrinted])
        try? data?.write(to: URL(fileURLWithPath: out))
    }
}
