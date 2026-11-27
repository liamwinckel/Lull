import HealthKit

/// Completed sessions are saved to Apple Health as Mindful Minutes.
@MainActor
final class Health {
    static let shared = Health()
    private let store = HKHealthStore()
    private let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
    private var asked = UserDefaults.standard.bool(forKey: "healthAsked")

    func requestAccessIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable(), !asked else { return }
        asked = true; UserDefaults.standard.set(true, forKey: "healthAsked")
        store.requestAuthorization(toShare: [mindful], read: [mindful]) { _, _ in }
    }

    func logMindful(from start: Date, to end: Date) {
        guard HKHealthStore.isHealthDataAvailable(), store.authorizationStatus(for: mindful) == .sharingAuthorized else { return }
        let sample = HKCategorySample(type: mindful, value: HKCategoryValue.notApplicable.rawValue, start: start, end: end)
        store.save(sample) { _, _ in }
    }
}
