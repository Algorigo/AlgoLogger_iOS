//
//  File.swift
//  
//
//  Created by Rouddy on 2/26/24.
//

import Foundation
import XCGLogger
import AWSLogs
import RxSwift
import RxRelay

public class CloudWatchDestination: AlgorigoLoggingDestination {
    
    enum CloudWatchDestinationError: Error {
        case destinationReleased
        case logGrouNotFound
        case logStreamNotFound
        case awsNotConfigured
        case putLogsError(nextSeqeunceToken: String?)
    }
    
    fileprivate let client: AWSLogs
    
    fileprivate let disposeBag = DisposeBag()
    fileprivate var logUploadStream: LogUploadStream!
    fileprivate let logRelay = ReplayRelay<LogDatabase.LogData>.createUnbound()
    fileprivate var logDelegate: ((LogDatabase.LogData) -> Void)?
    
    public init(
        logGroupNameSingle: Single<String>,
        logStreamNameSingle: Single<String>,
        accessKey: String,
        secretKey: String,
        region: AWSRegionType,
        owner: XCGLogger? = nil,
        formatter: LogFormatterProtocol? = nil,
        outputLevel: XCGLogger.Level = .info,
        useQueue: Bool = true,
        sendInterval: TimeInterval = 60, // 1 minutes
        maxQueueSize: Int = 1048576, // 1 MBytes
        maxBatchCount: Int = 10000,
        maxMessageSize: Int = 262114, // 256 KBytes
        logGroupRetentionDays: RetentionDays = RetentionDays.month_6,
        createLogGroup: Bool = true,
        createLogStream: Bool = true
    ) {
        let key = "CloudWatch_\(accessKey)_\(region)"
        let credential = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        let configuration = AWSServiceConfiguration(region: region, credentialsProvider: credential)!
        AWSLogs.register(with: configuration, forKey: key)
        self.client = AWSLogs(forKey: key)
        
        super.init(owner: owner, formatter: formatter, outputLevel: outputLevel, identifier: String(describing: CloudWatchDestination.self))
        if useQueue {
            self.logUploadStream = LogUploadStream(
                retentionDays: logGroupRetentionDays,
                sendInterval: sendInterval < 10 ? 10 : sendInterval,
                maxBatchSize: maxQueueSize,
                maxBatchCount: maxBatchCount,
                logger: self.owner
            )
            logDelegate = { [weak self] log in
                self?.logUploadStream.add(log: log)
            }
        } else {
            logDelegate = { [weak self] log in
                self?.logRelay.accept(log)
            }
        }
        
        Single.zip(logGroupNameSingle, logStreamNameSingle)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .flatMap { [weak self] logGroupName, logStreamName -> Single<(String, String)> in
                return self?.initCloudWatch(logGroupName: logGroupName, logStreamName: logStreamName, createLogGroup: createLogGroup, retentionDays: logGroupRetentionDays, createLogStream: createLogStream)
                    .andThen(Single.just((logGroupName, logStreamName)))
                ?? Single.error(CloudWatchDestinationError.destinationReleased)
            }
            .asObservable()
            .flatMap({ [weak self] logGroupName, logStreamName -> Observable<(Bool, String?)> in
                guard let self = self else {
                    return Observable.error(CloudWatchDestinationError.destinationReleased)
                }
                if useQueue {
                    return self.getLogBatchUpload(logGroupName: logGroupName, logStreamName: logStreamName)
                } else {
                    return self.getLogUpload(logGroupName: logGroupName, logStreamName: logStreamName)
                }
            })
            .ignoreElements()
            .asCompletable()
            .subscribe { [weak self] event in
                switch event {
                case .completed:
                    self?.owner?.debug("init cloud watch complete")
                case .error(let error):
                    self?.owner?.warning("init cloud watch error", userInfo: [L.error: error])
                }
            }
            .disposed(by: self.disposeBag)
    }
    
    private func initCloudWatch(
        logGroupName: String,
        logStreamName: String,
        createLogGroup: Bool,
        retentionDays: RetentionDays,
        createLogStream: Bool
    ) -> Completable {
        return ensureLogGroup(logGroupName: logGroupName, createLogGroup: createLogGroup, retentionDays: retentionDays)
            .andThen(ensureLogStream(logGroupName: logGroupName, logStreamName: logStreamName, createLogStream: createLogStream))
            .do(onError: { [weak self] error in
                self?.owner?.warning("initCloudWatch error", userInfo: [L.error: error])
            })
            .retry(when: { observable in
                observable.delay(RxTimeInterval.seconds(60), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
            })
    }

    private func ensureLogGroup(
        logGroupName: String,
        createLogGroup: Bool,
        retentionDays: RetentionDays
    ) -> Completable {
        return logGroupExists(logGroupName: logGroupName)
            .flatMapCompletable({ [weak self] exists in
                if (exists) {
                    return Completable.empty()
                } else if (createLogGroup) {
                    if let self = self {
                        return self.createLogGroup(logGroupName: logGroupName)
                    } else {
                        return Completable.error(CloudWatchDestinationError.destinationReleased)
                    }
                } else {
                    return Completable.error(CloudWatchDestinationError.logGrouNotFound)
                }
            })
            .andThen(putRetentionPolicy(logGroupName: logGroupName, retentionDays: retentionDays))
    }
    
    private func logGroupExists(logGroupName: String) -> Single<Bool> {
        return Single.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(CloudWatchDestinationError.destinationReleased))
                return Disposables.create()
            }
            guard let request = AWSLogsDescribeLogGroupsRequest() else {
                observer(.failure(CloudWatchDestinationError.awsNotConfigured))
                return Disposables.create()
            }
            request.logGroupNamePattern = logGroupName
            self.client.describeLogGroups(request) { response, error in
                if let error = error {
                    observer(.failure(error))
                } else {
                    observer(.success(response?.logGroups?.isEmpty == false))
                }
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }

    private func createLogGroup(logGroupName: String) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(CloudWatchDestinationError.destinationReleased))
                return Disposables.create()
            }
            guard let request = AWSLogsCreateLogGroupRequest() else {
                observer(.error(CloudWatchDestinationError.awsNotConfigured))
                return Disposables.create()
            }
            request.logGroupName = logGroupName
            self.client.createLogGroup(request) { error in
                if let error = error {
                    observer(.error(error))
                } else {
                    observer(.completed)
                }
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    private func putRetentionPolicy(
        logGroupName: String,
        retentionDays: RetentionDays
    ) -> Completable {
        return Completable.create(subscribe: { [weak self] observer in
            guard let self = self else {
                observer(.error(CloudWatchDestinationError.destinationReleased))
                return Disposables.create()
            }
            guard let request = AWSLogsPutRetentionPolicyRequest() else {
                observer(.error(CloudWatchDestinationError.awsNotConfigured))
                return Disposables.create()
            }
            request.logGroupName = logGroupName
            request.retentionInDays = NSNumber(value: retentionDays.rawValue)
            self.client.putRetentionPolicy(request) { error in
                if let error = error {
                    observer(.error(error))
                } else {
                    observer(.completed)
                }
            }
            return Disposables.create()
        })
    }

    private func ensureLogStream(
        logGroupName: String,
        logStreamName: String,
        createLogStream: Bool
    ) -> Completable {
        return logStreamExists(logGroupName: logGroupName, logStreamName: logStreamName)
            .flatMapCompletable({ [weak self] exist in
                if (exist) {
                    return Completable.empty()
                } else if (createLogStream) {
                    if let self = self {
                        return self.createLogStream(logGroupName: logGroupName, logStreamName: logStreamName)
                    } else {
                        return Completable.error(CloudWatchDestinationError.destinationReleased)
                    }
                } else {
                    return Completable.error(CloudWatchDestinationError.logStreamNotFound)
                }
            })
    }
    
    private func logStreamExists(logGroupName: String, logStreamName: String) -> Single<Bool> {
        return Single.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(CloudWatchDestinationError.destinationReleased))
                return Disposables.create()
            }
            guard let request = AWSLogsDescribeLogStreamsRequest() else {
                observer(.failure(CloudWatchDestinationError.awsNotConfigured))
                return Disposables.create()
            }
            request.logGroupName = logGroupName
            request.logStreamNamePrefix = logStreamName
            self.client.describeLogStreams(request) { response, error in
                if let error = error {
                    observer(.failure(error))
                } else {
                    observer(.success(response?.logStreams?.isEmpty == false))
                }
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }

    private func createLogStream(logGroupName: String, logStreamName: String) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(CloudWatchDestinationError.destinationReleased))
                return Disposables.create()
            }
            guard let request = AWSLogsCreateLogStreamRequest() else {
                observer(.error(CloudWatchDestinationError.awsNotConfigured))
                return Disposables.create()
            }
            request.logGroupName = logGroupName
            request.logStreamName = logStreamName
            self.client.createLogStream(request) { error in
                if let error = error {
                    observer(.error(error))
                } else {
                    observer(.completed)
                }
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    private func submitLogs(
        logGroupName: String,
        logStreamName: String,
        logs: [AWSLogsInputLogEvent],
        sequenceToken: String? = nil
    ) -> Single<(Bool, String?)> {
        if (logs.isEmpty) {
            return Single<(Bool, String?)>.just((false, sequenceToken))
        }
        return Single<(Bool, String?)>.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(CloudWatchDestinationError.destinationReleased))
                return Disposables.create()
            }
            guard let request = AWSLogsPutLogEventsRequest() else {
                observer(.failure(CloudWatchDestinationError.awsNotConfigured))
                return Disposables.create()
            }
            request.logGroupName = logGroupName
            request.logStreamName = logStreamName
            request.logEvents = logs
            request.sequenceToken = sequenceToken
            self.client.putLogEvents(request) { [weak self] response, error in
                if let error = error as? NSError {
                    self?.owner?.warning("put log event error", userInfo: [L.error: error])
                    switch (error.code) {
                    case AWSLogsErrorType.dataAlreadyAccepted.rawValue:
                        observer(.success((true, response?.nextSequenceToken)))
                    case AWSLogsErrorType.invalidSequenceToken.rawValue:
                        observer(.failure(CloudWatchDestinationError.putLogsError(nextSeqeunceToken: response?.nextSequenceToken)))
                    default:
                        observer(.success((false, nil)))
                    }
                } else {
                    observer(.success((true, response?.nextSequenceToken)))
                }
            }
            return Disposables.create()
        }
        .catch({ [weak self] error in
            self?.owner?.warning("Failed to deliver logs error", userInfo: [L.error: error])
            switch error {
            case CloudWatchDestinationError.putLogsError(let nextSeqeunceToken):
                return Single<Int>.timer(RxTimeInterval.seconds(1), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                    .flatMap { [weak self] _ in
                        guard let self = self else {
                            return Single.error(CloudWatchDestinationError.destinationReleased)
                        }
                        return self.submitLogs(logGroupName: logGroupName, logStreamName: logStreamName, logs: logs, sequenceToken: nextSeqeunceToken)
                    }
            default:
                return Single.error(error)
            }
        })
    }
    
    fileprivate func getLogBatchUpload(logGroupName: String, logStreamName: String) -> Observable<(Bool, String?)> {
        var nextSequenceToken: String? = nil
        return logUploadStream.getOutputObservable()
            .map({ sendIndex, logDatas -> (Int, [AWSLogsInputLogEvent]) in
                return (sendIndex, try logDatas.map { logData in
                    guard let event = AWSLogsInputLogEvent() else {
                        throw CloudWatchDestinationError.awsNotConfigured
                    }
                    event.message = logData.message
                    event.timestamp = (Int64(logData.timestamp.timeIntervalSince1970 * 1000)) as NSNumber
                    return event
                })
            })
            .concatMap { [weak self] output -> Observable<(Bool, String?)> in
                guard let self = self else {
                    return Observable<(Bool, String?)>.error(CloudWatchDestinationError.destinationReleased)
                }
                return self.submitLogs(logGroupName: logGroupName, logStreamName: logStreamName, logs: output.1, sequenceToken: nextSequenceToken)
                    .do(onSuccess: { [weak self] success, nextToken in
                        nextSequenceToken = nextToken
                        if success {
                            self?.logUploadStream.delete(sendIndex: output.0)
                        }
                    })
                    .asObservable()
            }
    }
    
    fileprivate func getLogUpload(logGroupName: String, logStreamName: String) -> Observable<(Bool, String?)> {
        var nextSequenceToken: String? = nil
        return logRelay
            .map({ logData -> AWSLogsInputLogEvent in
                guard let event = AWSLogsInputLogEvent() else {
                    throw CloudWatchDestinationError.awsNotConfigured
                }
                event.message = logData.message
                event.timestamp = (Int64(logData.timestamp.timeIntervalSince1970 * 1000)) as NSNumber
                return event
            })
            .concatMap { [weak self] log -> Observable<(Bool, String?)> in
                guard let self = self else {
                    return Observable<(Bool, String?)>.error(CloudWatchDestinationError.destinationReleased)
                }
                return self.submitLogs(logGroupName: logGroupName, logStreamName: logStreamName, logs: [log], sequenceToken: nextSequenceToken)
                    .asObservable()
            }
            .do(onNext: { success, token in
                nextSequenceToken = token
            })
    }
    
    public override func write(level: XCGLogger.Level, message: String, date: Date) {
        if (message.isEmpty) {
            self.owner?.debug("write record is empty")
            return
        }
        
        let logData: LogDatabase.LogData
        do {
            logData = try LogDatabase.LogData(message: message, timestamp: date)
        } catch {
            self.owner?.warning("message is not decodable", userInfo: [L.error: error])
            return
        }
        
        self.logDelegate?(logData)
    }
}
