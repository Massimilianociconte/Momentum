import Flutter
import Foundation
import HealthKit

private struct RallyMateHealthSourceRow {
  let application: String
  let bundleIdentifier: String
  let device: String
  let model: String
  var metrics: Set<String>
}

/// Bridge Apple Salute (HealthKit), speculare a HealthConnectBridge.kt:
/// stesso canale `com.rallymate/health_connect` e stesso wire format, così
/// il layer Dart resta identico tra Android e iOS.
///
/// Metodi:
///  - status              → {available, granted, availability, providerPackage}
///  - requestPermissions  → come status, dopo il prompt di autorizzazione
///  - readSummary         → {startMs, endMs, steps, activeCaloriesKcal,
///                           averageHeartRateBpm, exerciseMinutes}
///
/// Nota privacy HealthKit: lo stato di autorizzazione in LETTURA non è
/// osservabile (by design Apple). Tracciamo quindi "richiesto" in
/// UserDefaults: dopo la richiesta le query funzionano e, se l'utente ha
/// negato, restituiscono semplicemente dati vuoti.
final class HealthKitBridge: NSObject {
  private static let channelName = "com.rallymate/health_connect"
  private static let requestedKey = "rallymate.healthkit.requested"

  private let store = HKHealthStore()
  private let channel: FlutterMethodChannel

  private var readTypes: Set<HKObjectType> {
    var types = Set<HKObjectType>()
    if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
      types.insert(steps)
    }
    if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
      types.insert(energy)
    }
    if let heart = HKObjectType.quantityType(forIdentifier: .heartRate) {
      types.insert(heart)
    }
    if let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
      types.insert(exercise)
    }
    if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
      types.insert(hrv)
    }
    if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      types.insert(sleep)
    }
    types.insert(HKObjectType.workoutType())
    return types
  }

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(statusPayload())
    case "requestPermissions":
      requestPermissions(result)
    case "readSummary":
      readSummary(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // ------------------------------------------------------------ status

  private func statusPayload() -> [String: Any?] {
    let available = HKHealthStore.isHealthDataAvailable()
    let requested = UserDefaults.standard.bool(forKey: Self.requestedKey)
    // HealthKit does not expose per-type *read* grants. "requested" means the
    // system dialog was shown. "granted" mirrors that for UX continuity, but
    // empty `readSummary` results must still be treated as denial/no-data —
    // never as proof of live authorization after a Settings revoke.
    //
    // When the user has never been prompted, both flags stay false so the
    // phone does not claim a connected Apple Salute state.
    return [
      "available": available,
      "requested": available && requested,
      "granted": available && requested,
      "partial": false,
      "availability": available
        ? (requested ? "available" : "not_determined")
        : "unavailable",
      "providerPackage": nil,
    ]
  }

  private func requestPermissions(_ result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(statusPayload())
      return
    }
    store.requestAuthorization(toShare: nil, read: readTypes) { success, error in
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(
            code: "healthkit_authorization_error",
            message: error.localizedDescription,
            details: nil
          ))
          return
        }
        UserDefaults.standard.set(success, forKey: Self.requestedKey)
        result(self.statusPayload())
      }
    }
  }

  // ------------------------------------------------------- readSummary

  private func readSummary(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
          let startMs = (args["startMs"] as? NSNumber)?.int64Value,
          let endMs = (args["endMs"] as? NSNumber)?.int64Value,
          startMs < endMs
    else {
      result(FlutterError(code: "bad_args", message: "startMs and endMs required", details: nil))
      return
    }
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "unavailable", message: "HealthKit not available", details: nil))
      return
    }

    let start = Date(timeIntervalSince1970: Double(startMs) / 1000)
    let end = Date(timeIntervalSince1970: Double(endMs) / 1000)
    let predicate = HKQuery.predicateForSamples(
      withStart: start,
      end: end,
      options: .strictStartDate
    )

    let group = DispatchGroup()
    var steps = 0
    var activeCalories = 0.0
    var averageHeartRate: Double?
    var exerciseMinutes = 0
    var heartRateVariability: Double?
    var sleepMinutes = 0
    var sourceRows = [String: RallyMateHealthSourceRow]()
    let sourceLock = NSLock()
    let metricsLock = NSLock()

    func recordSource(_ sample: HKSample, metric: String) {
      let source = sample.sourceRevision.source
      let device = sample.device
      let manufacturer = device?.manufacturer ?? ""
      let model = device?.model ?? ""
      let key = "\(source.bundleIdentifier)|\(manufacturer)|\(model)"
      sourceLock.lock()
      defer { sourceLock.unlock() }
      var row = sourceRows[key] ?? RallyMateHealthSourceRow(
        application: source.name,
        bundleIdentifier: source.bundleIdentifier,
        device: manufacturer,
        model: model,
        metrics: []
      )
      row.metrics.insert(metric)
      sourceRows[key] = row
    }

    func collectSources(_ type: HKSampleType, metric: String) {
      group.enter()
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: 250,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
      ) { _, samples, _ in
        for sample in samples ?? [] { recordSource(sample, metric: metric) }
        group.leave()
      }
      store.execute(query)
    }

    func cumulative(
      _ identifier: HKQuantityTypeIdentifier,
      unit: HKUnit,
      assign: @escaping (Double) -> Void
    ) {
      guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return }
      group.enter()
      let query = HKStatisticsQuery(
        quantityType: type,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
      ) { _, stats, _ in
        // Errore o nessun dato: il totale resta 0, mai un crash.
        if let sum = stats?.sumQuantity() {
          metricsLock.lock()
          assign(sum.doubleValue(for: unit))
          metricsLock.unlock()
        }
        group.leave()
      }
      store.execute(query)
    }

    cumulative(.stepCount, unit: .count()) { steps = Int($0) }
    cumulative(.activeEnergyBurned, unit: .kilocalorie()) { activeCalories = $0 }
    cumulative(.appleExerciseTime, unit: .minute()) { exerciseMinutes = Int($0) }

    if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
      collectSources(stepsType, metric: "STEPS")
    }
    if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
      collectSources(energyType, metric: "ACTIVE_ENERGY")
    }
    if let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
      collectSources(exerciseType, metric: "EXERCISE_MINUTES")
    }

    if let heartType = HKObjectType.quantityType(forIdentifier: .heartRate) {
      group.enter()
      let bpmUnit = HKUnit.count().unitDivided(by: .minute())
      let query = HKStatisticsQuery(
        quantityType: heartType,
        quantitySamplePredicate: predicate,
        options: .discreteAverage
      ) { _, stats, _ in
        if let avg = stats?.averageQuantity() {
          metricsLock.lock()
          averageHeartRate = avg.doubleValue(for: bpmUnit)
          metricsLock.unlock()
        }
        group.leave()
      }
      store.execute(query)
      collectSources(heartType, metric: "HEART_RATE")
    }

    if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
      group.enter()
      let query = HKSampleQuery(
        sampleType: hrvType,
        predicate: predicate,
        limit: 500,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
      ) { _, samples, _ in
        let unit = HKUnit.secondUnit(with: .milli)
        let values = (samples ?? []).compactMap { sample -> Double? in
          recordSource(sample, metric: "HRV")
          return (sample as? HKQuantitySample)?.quantity.doubleValue(for: unit)
        }
        if !values.isEmpty {
          metricsLock.lock()
          heartRateVariability = values.reduce(0, +) / Double(values.count)
          metricsLock.unlock()
        }
        group.leave()
      }
      store.execute(query)
    }

    if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      group.enter()
      let query = HKSampleQuery(
        sampleType: sleepType,
        predicate: predicate,
        limit: 1000,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
      ) { _, samples, _ in
        var intervalsBySource = [String: [(Date, Date)]]()
        for case let sample as HKCategorySample in samples ?? [] {
          recordSource(sample, metric: "SLEEP")
          let isAwake = sample.value == HKCategoryValueSleepAnalysis.awake.rawValue
          let isInBed = sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue
          guard !isAwake && !isInBed else { continue }
          let bundle = sample.sourceRevision.source.bundleIdentifier
          intervalsBySource[bundle, default: []].append((
            max(sample.startDate, start),
            min(sample.endDate, end)
          ))
        }
        // Multiple apps can mirror the same sleep. Use the largest per-source
        // union instead of summing providers and double-counting the night.
        metricsLock.lock()
        sleepMinutes = intervalsBySource.values.map(Self.unionMinutes).max() ?? 0
        metricsLock.unlock()
        group.leave()
      }
      store.execute(query)
    }

    collectSources(HKObjectType.workoutType(), metric: "WORKOUT")

    group.notify(queue: .main) {
      result([
        "startMs": startMs,
        "endMs": endMs,
        "steps": steps,
        "activeCaloriesKcal": activeCalories,
        "averageHeartRateBpm": averageHeartRate as Any?,
        "exerciseMinutes": exerciseMinutes,
        "heartRateVariabilityMs": heartRateVariability as Any?,
        "heartRateVariabilityMethod": "SDNN",
        "sleepMinutes": sleepMinutes,
        "sources": sourceRows.values
          .sorted { $0.application.localizedCaseInsensitiveCompare($1.application) == .orderedAscending }
          .map { row in
            [
              "sourceApplication": row.application,
              "sourceBundleId": row.bundleIdentifier,
              "sourceDevice": row.device,
              "sourceModel": row.model,
              "metrics": row.metrics.sorted(),
            ] as [String: Any]
          },
      ] as [String: Any?])
    }
  }

  private static func unionMinutes(_ intervals: [(Date, Date)]) -> Int {
    let valid = intervals.filter { $0.1 > $0.0 }.sorted { $0.0 < $1.0 }
    guard var current = valid.first else { return 0 }
    var total: TimeInterval = 0
    for interval in valid.dropFirst() {
      if interval.0 <= current.1 {
        current.1 = max(current.1, interval.1)
      } else {
        total += current.1.timeIntervalSince(current.0)
        current = interval
      }
    }
    total += current.1.timeIntervalSince(current.0)
    return max(0, Int(total / 60))
  }
}
