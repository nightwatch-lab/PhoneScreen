import XCTest
@testable import PhoneScreenCore

final class PresetTests: XCTestCase {
    func testIPhone17eUsesAppleLongSideFirstListing() {
        let portrait = PhonePresets.iPhone17ePortrait
        let landscape = PhonePresets.iPhone17eLandscape
        XCTAssertEqual(portrait.width, 1170)
        XCTAssertEqual(portrait.height, 2532)
        XCTAssertEqual(portrait.ppi, 460)
        XCTAssertEqual(landscape.width, 2532)
        XCTAssertEqual(landscape.height, 1170)
        XCTAssertEqual(landscape.ppi, 460)
        XCTAssertEqual(portrait.swapped.width, landscape.width)
        XCTAssertEqual(portrait.swapped.height, landscape.height)
    }

    func testOtherOfficialPanels() {
        XCTAssertEqual(PhonePresets.iPhone17And17ProPortrait.width, 1206)
        XCTAssertEqual(PhonePresets.iPhone17And17ProPortrait.height, 2622)
        XCTAssertEqual(PhonePresets.iPhone17ProMaxPortrait.width, 1320)
        XCTAssertEqual(PhonePresets.iPhone17ProMaxPortrait.height, 2868)
        XCTAssertEqual(PhonePresets.iPhoneAirPortrait.width, 1260)
        XCTAssertEqual(PhonePresets.iPhoneAirPortrait.height, 2736)
        XCTAssertEqual(PhonePresets.galaxyS25Portrait.width, 1080)
        XCTAssertEqual(PhonePresets.galaxyS25Portrait.height, 2340)
        XCTAssertEqual(PhonePresets.galaxyZFold7Cover.width, 1080)
        XCTAssertEqual(PhonePresets.galaxyZFold7Cover.height, 2520)
        XCTAssertEqual(PhonePresets.galaxyZFold7Cover.ppi, 422)
        XCTAssertEqual(PhonePresets.galaxyZFold7Inner.width, 1968)
        XCTAssertEqual(PhonePresets.galaxyZFold7Inner.height, 2184)
        XCTAssertEqual(PhonePresets.galaxyZFold7Inner.ppi, 368)
        XCTAssertEqual(PhonePresets.iPhone16And15Portrait.width, 1179)
        XCTAssertEqual(PhonePresets.iPhone16And15Portrait.height, 2556)
        XCTAssertEqual(PhonePresets.iPhone16PlusPortrait.width, 1290)
        XCTAssertEqual(PhonePresets.iPhone16PlusPortrait.height, 2796)
        XCTAssertEqual(PhonePresets.huaweiMate70Portrait.width, 1216)
        XCTAssertEqual(PhonePresets.huaweiMate70Portrait.height, 2688)
        XCTAssertEqual(PhonePresets.huaweiPura80Portrait.width, 1256)
        XCTAssertEqual(PhonePresets.huaweiPura80Portrait.height, 2760)
        XCTAssertEqual(PhonePresets.xiaomi15Portrait.width, 1200)
        XCTAssertEqual(PhonePresets.xiaomi15Portrait.height, 2670)
        XCTAssertEqual(PhonePresets.vivoX200Portrait.width, 1260)
        XCTAssertEqual(PhonePresets.vivoX200Portrait.height, 2800)
        XCTAssertEqual(PhonePresets.onePlusAce6TPortrait.width, 1272)
        XCTAssertEqual(PhonePresets.iPhone17eUUSafe.height, 2000)
    }

    func testDefaultSettingsAreIPhone17ePortraitHiDPI() {
        let settings = AppSettings.iPhone17eDefault
        XCTAssertEqual(settings.width, 1170)
        XCTAssertEqual(settings.height, 2532)
        XCTAssertTrue(settings.hiDPI)
        XCTAssertEqual(settings.refreshHz, 60)
        XCTAssertEqual(settings.ppi, 460)
    }

    func testSwapOrientationTwiceRestoresSize() {
        var settings = AppSettings.iPhone17eDefault
        settings.swapOrientation()
        XCTAssertEqual(settings.width, 2532)
        XCTAssertEqual(settings.height, 1170)
        settings.swapOrientation()
        XCTAssertEqual(settings.width, 1170)
        XCTAssertEqual(settings.height, 2532)
    }
}

final class VirtualModePlanTests: XCTestCase {
    func testHiDPIHalvesLogicalSizeAndKeepsPhonePixels() throws {
        let plan = try VirtualModePlan.make(width: 1170, height: 2532, hiDPI: true, refreshHz: 60, ppi: 460)
        XCTAssertEqual(plan.pixelWidth, 1170)
        XCTAssertEqual(plan.pixelHeight, 2532)
        XCTAssertEqual(plan.logicalWidth, 585)
        XCTAssertEqual(plan.logicalHeight, 1266)
        XCTAssertEqual(plan.spiHiDPI, 1)
        XCTAssertFalse(plan.roundedToEven)
        XCTAssertEqual(plan.millimetersWide, 25.4 * 1170.0 / 460.0, accuracy: 0.0001)
        XCTAssertEqual(plan.millimetersHigh, 25.4 * 2532.0 / 460.0, accuracy: 0.0001)
        let diagonalInches = (
            (plan.millimetersWide * plan.millimetersWide) + (plan.millimetersHigh * plan.millimetersHigh)
        ).squareRoot() / 25.4
        XCTAssertEqual(diagonalInches, 6.06, accuracy: 0.02)
    }

    func testOneXUsesTheSameLogicalAndPixelSize() throws {
        let plan = try VirtualModePlan.make(width: 2532, height: 1170, hiDPI: false, refreshHz: 120, ppi: 460)
        XCTAssertEqual(plan.logicalWidth, 2532)
        XCTAssertEqual(plan.logicalHeight, 1170)
        XCTAssertEqual(plan.spiHiDPI, 0)
        XCTAssertEqual(plan.refreshHz, 120)
    }

    func testOddHiDPIDimensionsRoundUpToEvenPixels() throws {
        let plan = try VirtualModePlan.make(width: 1171, height: 2533, hiDPI: true, refreshHz: 30, ppi: 460)
        XCTAssertTrue(plan.roundedToEven)
        XCTAssertEqual(plan.pixelWidth, 1172)
        XCTAssertEqual(plan.pixelHeight, 2534)
        XCTAssertEqual(plan.logicalWidth, 586)
        XCTAssertEqual(plan.logicalHeight, 1267)
    }

    func testRejectsUnsupportedRefreshAndTinySize() {
        XCTAssertThrowsError(try VirtualModePlan.make(width: 1170, height: 2532, hiDPI: true, refreshHz: 90, ppi: 460)) { error in
            XCTAssertEqual(error as? PlanError, .refreshUnsupported(90))
        }
        XCTAssertThrowsError(try VirtualModePlan.make(width: 10, height: 2532, hiDPI: true, refreshHz: 60, ppi: 460))
    }

    func testSettingsPlanFollowsTheSameRules() throws {
        var settings = AppSettings.iPhone17eDefault
        settings.refreshHz = 120
        let plan = try settings.plan()
        XCTAssertEqual(plan.refreshHz, 120)
        XCTAssertEqual(plan.logicalWidth, 585)
    }
}

final class DisplayGeometryTests: XCTestCase {
    func testTranslatingVirtualDisplayToOriginKeepsRelativeLayout() {
        let main = DisplayFrame(id: 1, x: 0, y: 0, width: 1440, height: 900)
        let virtual = DisplayFrame(id: 2, x: 1440, y: 0, width: 1170, height: 2532)
        let shifted = DisplayGeometry.translatedSoDisplayIsAtOrigin(2, frames: [main, virtual])
        XCTAssertEqual(shifted?[1].x, 0)
        XCTAssertEqual(shifted?[1].y, 0)
        XCTAssertEqual(shifted?[0].x, -1440)
        XCTAssertEqual(shifted?[0].y, 0)
        XCTAssertNil(DisplayGeometry.translatedSoDisplayIsAtOrigin(9, frames: [main]))
    }

    func testRestoreParksVirtualDisplayWhenItCoversTheSnapshot() {
        let main = DisplayFrame(id: 1, x: 0, y: 0, width: 1440, height: 900)
        let virtual = DisplayFrame(id: 2, x: 0, y: 0, width: 1170, height: 2532)
        XCTAssertTrue(DisplayGeometry.overlaps(main, virtual))
        let plan = DisplayGeometry.restorePlan(snapshot: [main], virtual: virtual)
        XCTAssertEqual(plan[0], main)
        XCTAssertFalse(DisplayGeometry.overlaps(plan[0], plan[1]))
        XCTAssertEqual(plan[1].id, 2)
    }

    func testAdjacentDisplaysDoNotCountAsOverlap() {
        let left = DisplayFrame(id: 1, x: 0, y: 0, width: 100, height: 100)
        let right = DisplayFrame(id: 2, x: 100, y: 0, width: 50, height: 50)
        XCTAssertFalse(DisplayGeometry.overlaps(left, right))
        let plan = DisplayGeometry.restorePlan(snapshot: [left], virtual: right)
        XCTAssertEqual(plan[1].x, 100)
    }
}

final class CommandParserTests: XCTestCase {
    func testConnectURL() throws {
        let url = try XCTUnwrap(URL(string: "phonescreen://connect?w=1170&h=2532&hidpi=1&hz=60"))
        let command = try XCTUnwrap(try CommandParser.parseURL(url).get())
        XCTAssertEqual(command.action, .connect)
        XCTAssertEqual(command.width, 1170)
        XCTAssertEqual(command.height, 2532)
        XCTAssertEqual(command.hiDPI, true)
        XCTAssertEqual(command.hz, 60)
    }

    func testURLVerbsAndHiDPIOff() throws {
        let disconnect = try XCTUnwrap(URL(string: "phonescreen://disconnect"))
        XCTAssertEqual(try CommandParser.parseURL(disconnect).get().action, .disconnect)
        let swap = try XCTUnwrap(URL(string: "phonescreen://swap"))
        XCTAssertEqual(try CommandParser.parseURL(swap).get().action, .swap)
        let main = try XCTUnwrap(URL(string: "phonescreen://main"))
        XCTAssertEqual(try CommandParser.parseURL(main).get().action, .main)
        let mirror = try XCTUnwrap(URL(string: "phonescreen://mirror"))
        XCTAssertEqual(try CommandParser.parseURL(mirror).get().action, .mirror)
        let restore = try XCTUnwrap(URL(string: "phonescreen://restore"))
        XCTAssertEqual(try CommandParser.parseURL(restore).get().action, .restore)
        let off = try XCTUnwrap(URL(string: "phonescreen://connect?w=1080&h=2340&hidpi=0&hz=30&ppi=416"))
        let command = try CommandParser.parseURL(off).get()
        XCTAssertEqual(command.hiDPI, false)
        XCTAssertEqual(command.ppi, 416)
        XCTAssertEqual(command.hz, 30)
    }

    func testConnectURLCanOmitSizeButNotOneSide() throws {
        let bare = try XCTUnwrap(URL(string: "phonescreen://connect"))
        let command = try CommandParser.parseURL(bare).get()
        XCTAssertNil(command.width)
        XCTAssertNil(command.height)
        let half = try XCTUnwrap(URL(string: "phonescreen://connect?w=1170"))
        XCTAssertEqual(try? CommandParser.parseURL(half).get(), nil)
    }

    func testArgumentParser() throws {
        let command = try CommandParser.parseArguments([
            "connect", "--width", "1170", "--height", "2532", "--hidpi", "--hz", "120", "--ppi", "460",
        ]).get()
        XCTAssertEqual(command.width, 1170)
        XCTAssertEqual(command.height, 2532)
        XCTAssertEqual(command.hiDPI, true)
        XCTAssertEqual(command.hz, 120)
        XCTAssertEqual(command.ppi, 460)

        let off = try CommandParser.parseArguments([
            "connect", "-w", "1080", "-h", "2340", "--no-hidpi",
        ]).get()
        XCTAssertEqual(off.hiDPI, false)
        XCTAssertEqual(try CommandParser.parseArguments(["swap"]).get().action, .swap)
        XCTAssertEqual(try CommandParser.parseArguments(["status"]).get().action, .status)
    }

    func testConnectCommandMergesIntoCurrentSettings() throws {
        let command = try CommandParser.parseArguments(["connect", "--hz", "30", "--no-hidpi"]).get()
        let settings = try command.settings(applyingTo: .iPhone17eDefault)
        XCTAssertEqual(settings.width, 1170)
        XCTAssertEqual(settings.height, 2532)
        XCTAssertFalse(settings.hiDPI)
        XCTAssertEqual(settings.refreshHz, 30)
        XCTAssertThrowsError(try command.settings(applyingTo: {
            var broken = AppSettings.iPhone17eDefault
            broken.refreshHz = 30
            broken.width = 10
            return broken
        }()))
    }

    func testUsageMentionsURLScheme() {
        XCTAssertTrue(CommandParser.usageText.contains("phonescreen://connect?w=1170&h=2532&hidpi=1&hz=60"))
        XCTAssertTrue(CommandParser.usageText.contains("phonescreen://disconnect"))
        XCTAssertEqual(CommandParser.parseHiDPI("on"), true)
        XCTAssertEqual(CommandParser.parseHiDPI("off"), false)
        XCTAssertNil(CommandParser.parseHiDPI("maybe"))
    }
}

final class StateStoreTests: XCTestCase {
    func testRoundTripAndCorruptFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = StateStore(fileURL: directory.appendingPathComponent("state.json"))
        var settings = AppSettings.iPhone17eDefault
        settings.swapOrientation()
        try store.save(PhoneScreenState(settings: settings))

        let loaded = store.load()
        XCTAssertNil(loaded.warning)
        XCTAssertEqual(loaded.state.settings, settings)

        try Data("not-json".utf8).write(to: store.fileURL)
        let broken = store.load()
        XCTAssertNotNil(broken.warning)
        XCTAssertEqual(broken.state.settings, .iPhone17eDefault)
    }

    func testMissingFileUsesIPhone17eDefault() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("state.json")
        let loaded = StateStore(fileURL: url).load()
        XCTAssertNil(loaded.warning)
        XCTAssertEqual(loaded.state, .fresh)
    }

    func testClampsRefresh() {
        var state = PhoneScreenState.fresh
        state.settings.refreshHz = 90
        state.clamp()
        XCTAssertEqual(state.settings.refreshHz, 60)
    }

    func testLoadsOldStateFileWithRemovedFields() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = StateStore(fileURL: directory.appendingPathComponent("state.json"))
        let old = """
        {"profiles":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"x","width":1,"height":1,"hiDPI":true,"refreshHz":60,"ppi":460}],
         "settings":{"width":1272,"height":2800,"hiDPI":true,"refreshHz":60,"ppi":450,
         "autoDisconnectMinutes":10,"hotkey":"ctrl-opt-cmd-d","connectOnLaunch":true}}
        """
        try Data(old.utf8).write(to: store.fileURL)
        let loaded = store.load()
        XCTAssertNil(loaded.warning)
        XCTAssertEqual(loaded.state.settings.width, 1272)
        XCTAssertEqual(loaded.state.settings.height, 2800)
    }

    func testSocketPathStaysInsideSunPathLimit() {
        let path = PhoneScreenPaths.socketPath(uid: 501)
        XCTAssertEqual(path, "/tmp/phonescreen-501.sock")
        XCTAssertLessThan(path.utf8.count, 104)
    }
}

final class PresetListTests: XCTestCase {
    func testAllPresetsUniqueAndPortraitWhereExpected() {
        let all = PhonePresets.all
        XCTAssertEqual(all.count, 16)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        XCTAssertEqual(Set(all.map { "\($0.width)x\($0.height)" }).count, all.count)
        for p in all where p.id != PhonePresets.iPhone17eLandscape.id {
            XCTAssertLessThan(p.width, p.height, p.name)
        }
    }
}

final class PlacementTests: XCTestCase {
    let dells = [
        DisplayFrame(id: 1, x: 0, y: 0, width: 1920, height: 1200),
        DisplayFrame(id: 2, x: 1920, y: -100, width: 1920, height: 1200),
    ]

    func testDefaultIsRightOfRightmostTopAligned() {
        let f = DisplayGeometry.rightmostPlacement(id: 9, width: 585, height: 1000, others: dells)
        XCTAssertEqual(f.x, 3840)
        XCTAssertEqual(f.y, -100)
        XCTAssertTrue(DisplayGeometry.isValidPlacement(f, others: dells))
    }

    func testSavedOriginReusedOnlyWhenValid() {
        let left = DisplayGeometry.placement(id: 9, width: 585, height: 1000, others: dells, saved: (-585, 0))
        XCTAssertEqual(left.x, -585)
        let middle = DisplayGeometry.placement(id: 9, width: 585, height: 1000, others: dells, saved: (1920, 0))
        XCTAssertEqual(middle.x, 3840)
        let floating = DisplayGeometry.placement(id: 9, width: 585, height: 1000, others: dells, saved: (9000, 0))
        XCTAssertEqual(floating.x, 3840)
    }
}

final class SafeMarginTests: XCTestCase {
    func testPortraitShrinksHeightToEven() {
        XCTAssertTrue(SafeMargin.apply(width: 1272, height: 2800, enabled: true) == (1272, 2240))
        XCTAssertTrue(SafeMargin.apply(width: 1170, height: 2532, enabled: true) == (1170, 2026))
        XCTAssertTrue(SafeMargin.apply(width: 1080, height: 2340, enabled: true) == (1080, 1872))
    }

    func testLandscapeShrinksWidth() {
        XCTAssertTrue(SafeMargin.apply(width: 2532, height: 1170, enabled: true) == (2026, 1170))
    }

    func testOffAndAlreadyMarginedUnchanged() {
        XCTAssertTrue(SafeMargin.apply(width: 1272, height: 2800, enabled: false) == (1272, 2800))
        XCTAssertTrue(SafeMargin.apply(width: 1170, height: 2000, enabled: true) == (1170, 2000))
        XCTAssertTrue(SafeMargin.apply(width: 2000, height: 1170, enabled: true) == (2000, 1170))
    }

    func testRoundToEven() {
        XCTAssertEqual(SafeMargin.roundToEven(2025.6), 2026)
        XCTAssertEqual(SafeMargin.roundToEven(2239.0), 2240)
        XCTAssertEqual(SafeMargin.roundToEven(1000.0), 1000)
    }
}

final class FloatingButtonGeometryTests: XCTestCase {
    let vf = CGRect(x: 2000, y: 100, width: 636, height: 1100)
    func testDefaultTopRight() {
        let o = FloatingButtonGeometry.defaultOrigin(in: vf)
        XCTAssertEqual(o, CGPoint(x: 2636 - 44 - 12, y: 1200 - 44 - 12))
    }
    func testSavedOffsetRoundTripAndClamp() {
        let off = FloatingButtonGeometry.offset(of: CGPoint(x: 2100, y: 300), in: vf)
        XCTAssertEqual(off, CGPoint(x: 100, y: 200))
        XCTAssertEqual(FloatingButtonGeometry.origin(savedOffset: off, in: vf), CGPoint(x: 2100, y: 300))
        let small = CGRect(x: 0, y: 0, width: 300, height: 300)
        XCTAssertEqual(FloatingButtonGeometry.origin(savedOffset: CGPoint(x: 900, y: 900), in: small), CGPoint(x: 256, y: 256))
        XCTAssertEqual(FloatingButtonGeometry.clamp(CGPoint(x: -50, y: -50), in: vf), CGPoint(x: 2000, y: 100))
    }
    func testClickVsDrag() {
        XCTAssertTrue(FloatingButtonGeometry.isClick(from: .zero, to: CGPoint(x: 2, y: 2)))
        XCTAssertFalse(FloatingButtonGeometry.isClick(from: .zero, to: CGPoint(x: 5, y: 0)))
    }
}

final class VirtualModeSetTests: XCTestCase {
    func testModeListCoversFullAndMarginInBothScales() throws {
        let set = try VirtualModeSet.make(width: 1272, height: 2800, refreshHz: 60, ppi: 450)
        let m = SafeMargin.apply(width: 1272, height: 2800, enabled: true)
        XCTAssertEqual(m.width, 1272)
        XCTAssertEqual(m.height, 2240)
        let expected: [VirtualModeSet.Size] = [
            .init(width: 1272, height: 2800), .init(width: 636, height: 1400),
            .init(width: 1272, height: 2240), .init(width: 636, height: 1120),
        ]
        XCTAssertEqual(Set(set.modes), Set(expected))
        XCTAssertEqual(set.modes.count, 4)
        XCTAssertEqual(set.maxPixelsWide, 1272)
        XCTAssertEqual(set.maxPixelsHigh, 2800)
        for plan in set.plans { XCTAssertTrue(set.supports(plan)) }
    }

    func testOddSizesRoundedForHiDPIAndDeduplicated() throws {
        let set = try VirtualModeSet.make(width: 1179, height: 2556, refreshHz: 60, ppi: 460)
        XCTAssertTrue(set.modes.contains(.init(width: 1179, height: 2556)))
        XCTAssertTrue(set.modes.contains(.init(width: 590, height: 1278)))
        XCTAssertEqual(set.maxPixelsWide, 1180)
        XCTAssertEqual(Set(set.modes).count, set.modes.count)
    }

    func testSupportsRejectsOtherRefreshOrSize() throws {
        let set = try VirtualModeSet.make(width: 1170, height: 2532, refreshHz: 60, ppi: 460)
        XCTAssertFalse(set.supports(try VirtualModePlan.make(width: 1170, height: 2532, hiDPI: true, refreshHz: 120, ppi: 460)))
        XCTAssertFalse(set.supports(try VirtualModePlan.make(width: 1080, height: 2340, hiDPI: false, refreshHz: 60, ppi: 460)))
        XCTAssertTrue(set.supports(try VirtualModePlan.make(width: 1170, height: 2532, hiDPI: true, refreshHz: 60, ppi: 460)))
    }

    func testPresetWithBuiltInMarginHasOnlyTwoModes() throws {
        let p = PhonePresets.iPhone17eUUSafe
        let set = try VirtualModeSet.make(width: p.width, height: p.height, refreshHz: 60, ppi: p.ppi)
        XCTAssertEqual(set.modes.count, 2)
    }
}
