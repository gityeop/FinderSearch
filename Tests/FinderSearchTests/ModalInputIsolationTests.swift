import AppKit
import XCTest
@testable import FinderSearch

final class ModalInputIsolationTests: XCTestCase {
    @MainActor private func event(_ type: NSEvent.EventType, at point: CGPoint, in view: NSView)
        throws -> NSEvent
    {
        try XCTUnwrap(
            NSEvent.mouseEvent(
                with: type, location: view.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                windowNumber: try XCTUnwrap(view.window).windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 0))
    }

    @MainActor func testDisabledMarqueeEndsSelectionAndLeavesModalClicksAlone() throws {
        _ = NSApplication.shared
        let model = SearchModel()
        let view = MarqueeSelectionView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        let window = NSWindow(
            contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        defer { view.stop(); window.contentView = nil }
        view.configure(model: model, identity: "modal")
        view.itemFrames = ["file": CGRect(x: 20, y: 20, width: 80, height: 80)]
        _ = view.handle(try event(.leftMouseDown, at: .zero, in: view))
        _ = view.handle(try event(.leftMouseDragged, at: CGPoint(x: 110, y: 110), in: view))
        XCTAssertTrue(model.marqueeSelecting)
        XCTAssertEqual(model.selection, ["file"])

        view.inputEnabled = false
        XCTAssertFalse(model.marqueeSelecting)
        XCTAssertNotNil(view.handle(try event(.leftMouseDown, at: .zero, in: view)))
        XCTAssertNotNil(view.handle(try event(.leftMouseUp, at: .zero, in: view)))
        XCTAssertEqual(model.selection, ["file"])

        view.inputEnabled = true
        _ = view.handle(try event(.leftMouseDown, at: .zero, in: view))
        _ = view.handle(try event(.leftMouseUp, at: .zero, in: view))
        XCTAssertTrue(model.selection.isEmpty)
    }

    @MainActor func testDisabledFavoriteDragCancelsMoveAndCanResumeAfterDismissal() throws {
        _ = NSApplication.shared
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let source = FavoriteDragView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
        let target = FavoriteDragView(frame: NSRect(x: 0, y: 50, width: 200, height: 30))
        let window = NSWindow(
            contentRect: container.frame, styleMask: [.titled], backing: .buffered, defer: false)
        source.path = "/source"; target.path = "/target"
        container.addSubview(source); container.addSubview(target); window.contentView = container
        defer { window.contentView = nil }
        var moves = 0
        source.move = { _, _ in moves += 1 }
        let start = CGPoint(x: 20, y: 15), end = CGPoint(x: 20, y: 65)
        _ = source.handle(try event(.leftMouseDown, at: start, in: container))
        XCTAssertTrue(source.handle(try event(.leftMouseDragged, at: end, in: container)))
        XCTAssertNotNil(source.dragPreview)

        source.inputEnabled = false
        XCTAssertNil(source.dragPreview)
        XCTAssertNil(source.insertionMarker)
        XCTAssertFalse(source.handle(try event(.leftMouseUp, at: end, in: container)))
        _ = source.handle(try event(.leftMouseDown, at: start, in: container))
        XCTAssertFalse(source.handle(try event(.leftMouseDragged, at: end, in: container)))
        XCTAssertEqual(moves, 0)

        source.inputEnabled = true
        _ = source.handle(try event(.leftMouseDown, at: start, in: container))
        _ = source.handle(try event(.leftMouseDragged, at: end, in: container))
        XCTAssertTrue(source.handle(try event(.leftMouseUp, at: end, in: container)))
        XCTAssertEqual(moves, 1)
    }
}
