//
//  WeatherLocationSessionTests.swift
//  LyricsMTMRTests
//
//  Round 23: verifies the WeatherTabView "add my location" session
//  (WeatherLocationSession) lifecycle governance — the original
//  locateAndAddCity() created a CLLocationManager, called
//  requestLocation() + startUpdatingLocation() and polled with a 0.5 s
//  Timer, but never stopped location updates on resolve / timeout, and
//  the view had no disappear hook either (GPS stayed on forever).
//
//  The session is tested through its LocationProviding / GeocodingProviding
//  seams — fake source and fake geocoder (MKPlacemark constructed with an
//  address dictionary, no network) — so no real CoreLocation hardware,
//  location services or reverse geocoding is touched.
//
//  Hosted tests run on the main thread, so the helpers pump the main
//  runloop (runloop timers and main-queue blocks only run while pumping),
//  same as PausableTimerTests.
//

import XCTest
import CoreLocation
import MapKit
@testable import LyricsMTMR

class WeatherLocationSessionTests: XCTestCase {

    // MARK: - Helpers

    /// Thread-safe counter for location-source lifecycle calls.
    private final class LocationCounts {
        private let lock = NSLock()
        private var _request = 0
        private var _start = 0
        private var _stop = 0

        var requestCount: Int { lock.lock(); defer { lock.unlock() }; return _request }
        var startCount: Int { lock.lock(); defer { lock.unlock() }; return _start }
        var stopCount: Int { lock.lock(); defer { lock.unlock() }; return _stop }

        func request() { lock.lock(); _request += 1; lock.unlock() }
        func start() { lock.lock(); _start += 1; lock.unlock() }
        func stop() { lock.lock(); _stop += 1; lock.unlock() }
    }

    /// Fake location source: settable fix, counts start/stop/request.
    /// No real CLLocationManager is created.
    private final class FakeLocationSource: WeatherLocationSession.LocationProviding {
        let counts = LocationCounts()
        var location: CLLocation?

        func requestLocation() { counts.request() }
        func startUpdatingLocation() { counts.start() }
        func stopUpdatingLocation() { counts.stop() }
    }

    /// Fake geocoder: captures the completion handler so the test can fire
    /// it with a controlled placemark list (or nil). Counts cancelGeocode.
    private final class FakeGeocoder: WeatherLocationSession.GeocodingProviding {
        var placemarks: [CLPlacemark]? = nil
        private var pending: (([CLPlacemark]?, Error?) -> Void)?
        private(set) var geocodeCount = 0
        private(set) var cancelCount = 0

        func reverseGeocodeLocation(_ location: CLLocation,
                                    completionHandler: @escaping ([CLPlacemark]?, Error?) -> Void) {
            geocodeCount += 1
            pending = completionHandler
        }

        func cancelGeocode() {
            cancelCount += 1
            pending = nil
        }

        var isPending: Bool { pending != nil }

        /// Fire the pending completion with the configured placemarks.
        func complete() {
            let handler = pending
            pending = nil
            handler?(placemarks, nil)
        }
    }

    /// Captures session outcomes (main thread, so no locking needed).
    private final class OutcomeBox {
        private(set) var outcomes: [WeatherLocationSession.Outcome] = []
        func append(_ outcome: WeatherLocationSession.Outcome) { outcomes.append(outcome) }
    }

    /// Builds an MKPlacemark (a CLPlacemark subclass) with a locality /
    /// administrativeArea derived from an address dictionary — no network.
    private func placemark(city: String? = nil, state: String? = nil) -> CLPlacemark {
        var dict: [String: Any] = [:]
        if let city { dict["City"] = city }
        if let state { dict["State"] = state }
        return MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 30.67, longitude: 104.06),
                           addressDictionary: dict)
    }

    private let fix = CLLocation(latitude: 30.67, longitude: 104.06)

    /// Pumps the main runloop so runloop timers and main-queue blocks run.
    private func pumpRunLoop(for duration: TimeInterval) {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return condition()
    }

    /// Fast session factory: 20 ms interval, 3 attempts — same semantics
    /// as production (attempts >= 2 acceptance, attempts > maxAttempts
    /// timeout) with a ~60 ms timeout instead of ~6.5 s.
    private func makeSession(source: FakeLocationSource, geocoder: FakeGeocoder,
                             box: OutcomeBox) -> WeatherLocationSession {
        WeatherLocationSession(locationSource: source, geocoder: geocoder,
                               pollInterval: 0.02, maxAttempts: 3) { box.append($0) }
    }

    // MARK: - Resolve path

    func testResolvePathDeliversCityAndStopsLocationUpdates() {
        let source = FakeLocationSource()
        let geocoder = FakeGeocoder()
        geocoder.placemarks = [placemark(city: "成都市")]
        let box = OutcomeBox()
        let session = makeSession(source: source, geocoder: geocoder, box: box)

        session.start()
        XCTAssertEqual(source.counts.requestCount, 1, "start must request one-shot fix once")
        XCTAssertEqual(source.counts.startCount, 1, "start must begin continuous updates once")

        // First tick without a fix: nothing resolved yet (attempts >= 2 gate).
        pumpRunLoop(for: 0.05)
        XCTAssertFalse(geocoder.isPending, "no geocode before a fix is accepted")
        XCTAssertEqual(source.counts.stopCount, 0, "location updates must keep running while polling")

        // Fix arrives; the second tick accepts it and stops updates immediately.
        source.location = fix
        XCTAssertTrue(waitUntil(timeout: 2.0) { geocoder.isPending },
                      "fix + attempts >= 2 must trigger reverse geocoding")
        XCTAssertEqual(source.counts.stopCount, 1,
                       "resolve must stop location updates (GPS off) before geocoding")
        XCTAssertFalse(session.isActive, "timer must be invalidated at resolve")

        // Geocode completion delivers the city with the 市 suffix stripped.
        geocoder.complete()
        XCTAssertTrue(waitUntil(timeout: 2.0) { !box.outcomes.isEmpty },
                      "geocode completion must deliver an outcome")
        guard case .city(let name) = box.outcomes.first else {
            XCTFail("expected .city outcome, got \(String(describing: box.outcomes.first))")
            return
        }
        XCTAssertEqual(name, "成都", "市 suffix must be stripped (成都市 → 成都)")

        // Timer stays dead: no further ticks, no extra geocode, no extra stops.
        pumpRunLoop(for: 0.1)
        XCTAssertEqual(geocoder.geocodeCount, 1, "no further geocoding after resolve")
        XCTAssertEqual(source.counts.stopCount, 1, "no further stop calls after resolve")
    }

    func testResolveFallsBackToAdministrativeAreaAndStops() {
        let source = FakeLocationSource()
        let geocoder = FakeGeocoder()
        geocoder.placemarks = [placemark(state: "四川省")]
        let box = OutcomeBox()
        let session = makeSession(source: source, geocoder: geocoder, box: box)

        session.start()
        source.location = fix
        XCTAssertTrue(waitUntil(timeout: 2.0) { geocoder.isPending })
        geocoder.complete()
        XCTAssertTrue(waitUntil(timeout: 2.0) { !box.outcomes.isEmpty })
        guard case .city(let name) = box.outcomes.first else {
            XCTFail("expected .city outcome (administrativeArea fallback)")
            return
        }
        XCTAssertEqual(name, "四川省", "locality nil must fall back to administrativeArea")
        XCTAssertEqual(source.counts.stopCount, 1, "resolve must stop location updates")
    }

    func testResolveWithoutPlacemarkReportsNoPlacemarkAndStops() {
        let source = FakeLocationSource()
        let geocoder = FakeGeocoder()
        geocoder.placemarks = nil
        let box = OutcomeBox()
        let session = makeSession(source: source, geocoder: geocoder, box: box)

        session.start()
        source.location = fix
        XCTAssertTrue(waitUntil(timeout: 2.0) { geocoder.isPending })
        geocoder.complete()
        XCTAssertTrue(waitUntil(timeout: 2.0) { !box.outcomes.isEmpty })
        guard case .noPlacemark = box.outcomes.first else {
            XCTFail("expected .noPlacemark outcome, got \(String(describing: box.outcomes.first))")
            return
        }
        XCTAssertEqual(source.counts.stopCount, 1, "no-placemark resolve must stop location updates")
    }

    // MARK: - Timeout path

    func testTimeoutPathStopsLocationUpdatesAndReportsTimedOut() {
        let source = FakeLocationSource()
        let geocoder = FakeGeocoder()
        let box = OutcomeBox()
        let session = makeSession(source: source, geocoder: geocoder, box: box)

        session.start()
        // No fix ever arrives: after maxAttempts ticks (3 x 20 ms) the
        // session must time out, stop location updates and report.
        XCTAssertTrue(waitUntil(timeout: 2.0) { !box.outcomes.isEmpty },
                      "no fix within the attempt budget must time out")
        guard case .timedOut = box.outcomes.first else {
            XCTFail("expected .timedOut outcome, got \(String(describing: box.outcomes.first))")
            return
        }
        XCTAssertEqual(source.counts.stopCount, 1,
                       "timeout must stop location updates (GPS off)")
        XCTAssertEqual(geocoder.geocodeCount, 0, "timeout must not reverse-geocode")
        XCTAssertFalse(session.isActive, "timer must be invalidated at timeout")

        // Session is fully stopped: further pumping changes nothing.
        pumpRunLoop(for: 0.1)
        XCTAssertEqual(box.outcomes.count, 1, "no duplicate outcomes after timeout")
        XCTAssertEqual(source.counts.startCount, 1, "timeout must not restart location updates")
        XCTAssertEqual(source.counts.stopCount, 1, "timeout must not stop twice")
    }

    // MARK: - External stop (view disappeared / window hidden)

    func testStopWhilePollingStopsManagerAndTimerAndDiscardsResults() {
        let source = FakeLocationSource()
        let geocoder = FakeGeocoder()
        let box = OutcomeBox()
        let session = makeSession(source: source, geocoder: geocoder, box: box)

        session.start()
        pumpRunLoop(for: 0.05) // at least one tick, still polling
        XCTAssertTrue(session.isActive, "session must be polling before stop")

        session.stop()
        XCTAssertEqual(source.counts.stopCount, 1,
                       "stop must stop location updates (GPS off, privacy light out)")
        XCTAssertEqual(geocoder.cancelCount, 1, "stop must cancel any in-flight geocode")
        XCTAssertFalse(session.isActive, "stop must invalidate the timer")
        XCTAssertEqual(box.outcomes.count, 0, "stop must not deliver an outcome")

        // Even a late fix arriving after stop must not produce anything.
        source.location = fix
        pumpRunLoop(for: 0.15)
        XCTAssertEqual(box.outcomes.count, 0, "stopped session must never resolve")
        XCTAssertEqual(source.counts.stopCount, 1, "no extra stop calls")
        XCTAssertEqual(geocoder.geocodeCount, 0, "no geocoding after stop")
    }

    func testStopWhileGeocodingDiscardsPendingResult() {
        let source = FakeLocationSource()
        let geocoder = FakeGeocoder()
        geocoder.placemarks = [placemark(city: "成都市")]
        let box = OutcomeBox()
        let session = makeSession(source: source, geocoder: geocoder, box: box)

        session.start()
        source.location = fix
        XCTAssertTrue(waitUntil(timeout: 2.0) { geocoder.isPending },
                      "resolve must reach the geocoding step")

        // View disappears (window closed / tab gone) while geocoding:
        // the pending result must be discarded, not delivered.
        session.stop()
        XCTAssertEqual(source.counts.stopCount, 1, "stop after resolve must not double-stop")
        XCTAssertEqual(geocoder.cancelCount, 1, "stop must cancel the pending geocode")

        geocoder.complete() // simulate the cancelled handler firing late
        pumpRunLoop(for: 0.1)
        XCTAssertEqual(box.outcomes.count, 0,
                       "outcome after stop must be discarded (no city added to a hidden view)")
    }

    // MARK: - Re-entrancy guards

    func testDoubleStartIsIgnored() {
        let source = FakeLocationSource()
        let geocoder = FakeGeocoder()
        let box = OutcomeBox()
        let session = makeSession(source: source, geocoder: geocoder, box: box)

        session.start()
        session.start() // repeated click / accidental double start
        XCTAssertEqual(source.counts.requestCount, 1, "double start must not re-request")
        XCTAssertEqual(source.counts.startCount, 1, "double start must not restart updates")
        XCTAssertEqual(box.outcomes.count, 0, "double start must not deliver anything")
    }

    func testStopBeforeStartIsNoOp() {
        let source = FakeLocationSource()
        let geocoder = FakeGeocoder()
        let box = OutcomeBox()
        let session = makeSession(source: source, geocoder: geocoder, box: box)

        session.stop()
        XCTAssertEqual(source.counts.stopCount, 0, "never-started session must not stop anything")
        XCTAssertEqual(geocoder.cancelCount, 0, "never-started session must not cancel anything")
    }

    func testStopIsIdempotent() {
        let source = FakeLocationSource()
        let geocoder = FakeGeocoder()
        let box = OutcomeBox()
        let session = makeSession(source: source, geocoder: geocoder, box: box)

        session.start()
        pumpRunLoop(for: 0.05)
        session.stop()
        session.stop() // repeated dismiss / hide broadcasts
        XCTAssertEqual(source.counts.stopCount, 1, "repeated stop must stop exactly once")
        XCTAssertEqual(geocoder.cancelCount, 1, "repeated stop must cancel exactly once")
    }
}
