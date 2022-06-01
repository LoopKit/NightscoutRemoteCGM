//
//  NightscoutAPIManager.swift
//  NightscoutAPIClient
//
//  Created by Ivan Valkou on 10.10.2019.
//  Copyright © 2019 Ivan Valkou. All rights reserved.
//

import LoopKit
import HealthKit
import Combine
import NightscoutUploadKit

public class NightscoutRemoteCGM: CGMManager {
    
    public static let managerIdentifier = "NightscoutAPIClient"
    
    public var managerIdentifier: String {
        return NightscoutRemoteCGM.managerIdentifier
    }

    public static let localizedTitle = LocalizedString("Nightscout Remote CGM", comment: "Title for the CGMManager option")
    
    public var localizedTitle: String {
        return NightscoutRemoteCGM.localizedTitle
    }
    
    public var glucoseDisplay: GlucoseDisplayable? { latestBackfill }
    
    public var cgmManagerStatus: CGMManagerStatus {
        return .init(hasValidSensorSession: isOnboarded, device: device)
    }
    
    public var isOnboarded: Bool {
        return keychain.getNightscoutCgmURL() != nil
    }
    
    public enum CGMError: String, Error {
        case tooFlatData = "BG data is too flat."
    }

    private enum Config {
        static let useFilterKey = "NightscoutRemoteCGM.useFilter"
        static let filterNoise = 2.5
    }

    public init() {
        nightscoutService = NightscoutAPIService(keychainManager: keychain)
        updateTimer = DispatchTimer(timeInterval: 10, queue: processQueue)
        scheduleUpdateTimer()
    }

    public convenience required init?(rawState: CGMManager.RawStateValue) {
        self.init()
        useFilter = rawState[Config.useFilterKey] as? Bool ?? false
    }

    public var rawState: CGMManager.RawStateValue {
        [
            Config.useFilterKey: useFilter
        ]
    }

    private let keychain = KeychainManager()

    public var nightscoutService: NightscoutAPIService {
        didSet {
            keychain.setNightscoutCgmCredentials(nightscoutService.url, apiSecret: nightscoutService.apiSecret)
        }
    }

    public let delegate = WeakSynchronizedDelegate<CGMManagerDelegate>()

    public var delegateQueue: DispatchQueue! {
        get { delegate.queue }
        set { delegate.queue = newValue }
    }

    public var cgmManagerDelegate: CGMManagerDelegate? {
        get { delegate.delegate }
        set { delegate.delegate = newValue }
    }

    public let providesBLEHeartbeat = false

    public var managedDataInterval: TimeInterval?

    public var shouldSyncToRemoteService = false

    public var useFilter = false

    public private(set) var latestBackfill: GlucoseEntry?

    private var requestReceiver: Cancellable?

    private let processQueue = DispatchQueue(label: "NightscoutRemoteCGM.processQueue")

    private var isFetching = false

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMReadingResult) -> Void) {
        guard let nightscoutClient = nightscoutService.client, !isFetching else {
            delegateQueue.async {
                completion(.noData)
            }
            return
        }

        if let latestGlucose = latestBackfill, latestGlucose.startDate.timeIntervalSinceNow > -TimeInterval(minutes: 4.5) {
            delegateQueue.async {
                completion(.noData)
            }
            return
        }

        processQueue.async {
            self.isFetching = true

            nightscoutClient.fetchRecent { fetchResult in
                
                self.isFetching = false
                
                switch fetchResult {
                case .success(let glucoseEntries):
                    guard !glucoseEntries.isEmpty else {
                        self.delegateQueue.async {
                            completion(.noData)
                        }
                        return
                    }

                    var filteredGlucose = glucoseEntries
                    if self.useFilter {
                        var filter = KalmanFilter(stateEstimatePrior: glucoseEntries.last!.glucose, errorCovariancePrior: Config.filterNoise)
                        filteredGlucose.removeAll()
                        for item in glucoseEntries.reversed() {
                            let prediction = filter.predict(stateTransitionModel: 1, controlInputModel: 0, controlVector: 0, covarianceOfProcessNoise: Config.filterNoise)
                            let update = prediction.update(measurement: item.glucose, observationModel: 1, covarienceOfObservationNoise: Config.filterNoise)
                            filter = update
                            filteredGlucose.append(
                                GlucoseEntry(
                                    glucose: filter.stateEstimatePrior.rounded(),
                                    date: item.date,
                                    device: item.device,
                                    glucoseType: item.glucoseType,
                                    trend: item.trend,
                                    changeRate: item.changeRate,
                                    id: item.id
                                )
                            )
                        }
                        filteredGlucose = filteredGlucose.reversed()
                    }

                    let startDate = self.delegate.call { (delegate) -> Date? in
                        return delegate?.startDateToFilterNewData(for: self)
                    }
                    let newGlucose = filteredGlucose.filterDateRange(startDate, nil)
                    let newSamples = newGlucose.filter({ $0.isStateValid }).map { glucose -> NewGlucoseSample in
                        let glucoseTrend: LoopKit.GlucoseTrend?
                        if let trend = glucose.trend {
                            glucoseTrend = LoopKit.GlucoseTrend(rawValue: trend.rawValue)
                        } else {
                            glucoseTrend = nil
                        }
                        return NewGlucoseSample(
                            date: glucose.startDate,
                            quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: glucose.glucose),
                            condition: nil,
                            trend: glucoseTrend,
                            trendRate: glucose.trendRate,
                            isDisplayOnly: glucose.isCalibration == true,
                            wasUserEntered: glucose.glucoseType == .meter,
                            syncIdentifier: glucose.id ?? "\(Int(glucose.startDate.timeIntervalSince1970))",
                            device: self.device)
                    }

                    if let latestBackfill = newGlucose.max(by: {$0.startDate > $1.startDate}) {
                        self.latestBackfill = latestBackfill
                    }

                    self.delegateQueue.async {
                        guard !newSamples.isEmpty else {
                            completion(.noData)
                            return
                        }
                        completion(.newData(newSamples))
                    }
                case let .failure(error):
                    self.delegateQueue.async {
                        completion(.error(error))
                    }
                }


            }
        }


    }

    public var device: HKDevice? = nil

    public var debugDescription: String {
        "## NightscoutRemoteCGM\nlatestBackfill: \(String(describing: latestBackfill))\n"
    }

    public var appURL: URL? {
        guard let url = nightscoutService.url else { return nil }
        switch url.absoluteString {
        case "http://127.0.0.1:1979":
            return URL(string: "spikeapp://")
        case "http://127.0.0.1:17580":
            return URL(string: "diabox://")
        default:
            return url
        }
    }

    private let updateTimer: DispatchTimer

    private func scheduleUpdateTimer() {
        updateTimer.suspend()
        updateTimer.eventHandler = { [weak self] in
            guard let self = self else { return }
            self.fetchNewDataIfNeeded { result in
                guard case .newData = result else { return }
                self.delegate.notify { delegate in
                    delegate?.cgmManager(self, hasNew: result)
                }
            }
        }
        updateTimer.resume()
    }
}

// MARK: - AlertResponder implementation
extension NightscoutRemoteCGM {
    public func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
}

// MARK: - AlertSoundVendor implementation
extension NightscoutRemoteCGM {
    public func getSoundBaseURL() -> URL? { return nil }
    public func getSounds() -> [Alert.Sound] { return [] }
}
