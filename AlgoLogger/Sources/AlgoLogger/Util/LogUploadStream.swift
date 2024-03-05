//
//  File.swift
//  
//
//  Created by Rouddy on 2/27/24.
//

import Foundation
import AWSLogs
import RxSwift
import RxRelay
import XCGLogger

public enum RetentionDays: Int {
    case day_1 = 1
    case day_3 = 3
    case day_5 = 5
    case week_1 = 7
    case week_2 = 14
    case month_1 = 30
    case month_2 = 60
    case month_3 = 90
    case month_4 = 120
    case month_5 = 150
    case month_6 = 180
    case year_1 = 365
    case month_13 = 400
    case month_18 = 545
    case year_2 = 731
    case year_3 = 1096
    case year_5 = 1827
    case year_6 = 2192
    case year_7 = 2557
    case year_8 = 2922
    case year_9 = 3288
    case year_10 = 3653
}

class LogUploadStream {
    
    fileprivate struct MidResult {
        let logBatches: [(count: Int, size: Int, from: Date, to: Date, sendIndex: Int)]
        let result: (from: Date, to: Date, sendIndex: Int)?
    }
    
    enum LogUploadStreamError : Error {
        case logUploadStreamReleased
    }
    
    enum Event {
        case logAddEvent(log: LogDatabase.LogData)
        case logDeleteEvent(sendIndex: Int)
    }
    
    enum DatabaseResult {
        case inserted(count: Int, size: Int, createdAt: Date)
        case deleted(sendIndex: Int, restCount: Int, restSize: Int)
    }
    
    fileprivate let sendInterval: TimeInterval
    fileprivate let maxBatchSize: Int
    fileprivate let maxBatchCount: Int
    fileprivate let logger: XCGLogger?
    
    fileprivate let eventRelay = ReplayRelay<Event>.createUnbound()
    fileprivate let outputRelay = PublishRelay<(Int, [LogDatabase.LogData])>()
    fileprivate var disposeBag = DisposeBag()
    
    init(retentionDays: RetentionDays, sendInterval: TimeInterval = 60, maxBatchSize: Int = 1024 * 1024, maxBatchCount: Int = 10000, logger: XCGLogger? = nil) {
        self.sendInterval = sendInterval
        self.maxBatchSize = maxBatchSize
        self.maxBatchCount = maxBatchCount
        self.logger = logger
        
        LogDatabase.connect()
            .flatMap({ database -> Observable<(Int, [LogDatabase.LogData])> in
                database.deleteBefore(date: Calendar.current.date(byAdding: .day, value: -retentionDays.rawValue, to: Date())!)
                    .flatMap({ _ in
                        database.updateAllSendIndexZero()
                    })
                    .flatMap({ _ in
                        database.countAndSize()
                    })
                    .asObservable()
                    .flatMap({ [weak self] count, size -> Observable<MidResult> in
                        guard let self = self else {
                            return Observable<MidResult>.error(LogUploadStreamError.logUploadStreamReleased)
                        }
                        
                        return self.eventRelay
                            .concatMap { event -> Observable<DatabaseResult> in
                                switch event {
                                case .logAddEvent(let log):
                                    return database.insert(log: log)
                                        .flatMap { id in
                                            database.selectForId(id: id)
                                        }
                                        .map { createdAt in
                                            DatabaseResult.inserted(count: 1, size: log.size, createdAt: createdAt)
                                        }
                                        .asObservable()
                                case .logDeleteEvent(let sendIndex):
                                    return database.delete(sendIndex: Int64(sendIndex))
                                        .flatMap({ _ in
                                            database.countAndSize()
                                        })
                                        .map { count, size in
                                            DatabaseResult.deleted(sendIndex: sendIndex, restCount: count, restSize: Int(size))
                                        }
                                        .asObservable()
                                }
                            }
                            .scan(MidResult(logBatches: [(count: count, size: Int(size), from: Date.zero, to: Date.zero, sendIndex: 0)], result: nil)) { acc, result -> MidResult in
                                var logBatches = acc.logBatches
                                switch result {
                                case .inserted(let count, let size, let createdAt):
                                    if logBatches.isEmpty || logBatches.last!.sendIndex != 0 {
                                        logBatches.append((count: count, size: size, from: createdAt, to: createdAt, sendIndex: 0))
                                    } else {
                                        let lastIndex = logBatches.count - 1
                                        let count = logBatches.last!.count + count
                                        let size = logBatches.last!.size + size
                                        if count >= maxBatchCount || size >= maxBatchSize {
                                            logBatches[lastIndex] = (count: count, size: size, from: logBatches.last!.from, to: createdAt, sendIndex: Int.random(in: 1..<Int.max))
                                        } else {
                                            logBatches[lastIndex] = (count: count, size: size, from: logBatches.last!.from, to: logBatches.last!.to, sendIndex: 0)
                                        }
                                    }
                                    
                                    if logBatches.last?.sendIndex ?? 0 > 0 {
                                        return MidResult(logBatches: logBatches, result: (from: logBatches.last!.from, to: logBatches.last!.to, sendIndex: logBatches.last!.sendIndex))
                                    } else {
                                        return MidResult(logBatches: logBatches, result: nil)
                                    }
                                case .deleted(let sendIndex, let restCount, let restSize):
                                    if let index = logBatches.firstIndex(where: { $0.sendIndex == sendIndex }) {
                                        logBatches.remove(at: index)
                                    } else {
                                        logBatches = [(count: restCount, size: restSize, from: Date.zero, to: Date.zero, sendIndex: 0)]
                                    }
                                    return MidResult(logBatches: logBatches, result: nil)
                                }
                            }
                    })
                    .filter { $0.result != nil }
                    .map { $0.result! }
                    .flatMap { from, to, sendIndex -> Observable<(Int, [LogDatabase.LogData])> in
                        database.selectBetween(from: from, to: to, sendIndex: Int64(sendIndex))
                            .map { logs in
                                (sendIndex, logs)
                            }
                            .asObservable()
                    }
            })
            .subscribe({ [weak self] event in
                switch event {
                case .next(let data):
                    self?.outputRelay.accept(data)
                case .completed:
                    break
                case .error(let error):
                    self?.logger?.warning("LogUploadStream initialize error", userInfo: [L.error: error])
                }
            })
            .disposed(by: disposeBag)
    }
    
    func getOutputObservable() -> Observable<(Int, [LogDatabase.LogData])> {
        let timeout = RxTimeInterval.milliseconds(Int(sendInterval * 1000))
        return LogDatabase.connect()
            .flatMap { [weak self] database in
                guard let self = self else {
                    return Observable<(Int, [LogDatabase.LogData])>.error(LogUploadStreamError.logUploadStreamReleased)
                }
                return self.outputRelay.asObservable()
                    .timeout(timeout, scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                    .catch { error in
                        Single.just(Int.random(in: 1..<Int.max))
                            .asObservable()
                            .flatMap { [weak self] random in
                                guard let self = self else {
                                    return Observable<(Int, [LogDatabase.LogData])>.error(LogUploadStreamError.logUploadStreamReleased)
                                }
                                return database.selectBetween(from: Date.zero, to: Date(), sendIndex: Int64(random))
                                    .map { (random, $0) }
                                    .asObservable()
                                    .concat(self.outputRelay.timeout(timeout, scheduler: ConcurrentDispatchQueueScheduler(qos: .background)))
                            }
                            .retry()
                    }
            }
    }
    
    func add(log: LogDatabase.LogData) {
        eventRelay.accept(.logAddEvent(log: log))
    }
    
    func delete(sendIndex: Int) {
        eventRelay.accept(.logDeleteEvent(sendIndex: sendIndex))
    }
}

fileprivate extension Date {
    static var zero: Date {
        return Date(timeIntervalSince1970: 0)
    }
}
