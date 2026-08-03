//
//  File.swift
//  
//
//  Created by Rouddy on 2/26/24.
//

import Foundation
import XCGLogger
import AWSCloudWatchLogs
import RxSwift
import RxRelay
import AlgoLoggerCommon
import AlgoLogger
import SmithyIdentity

public class CloudWatchDestination: AlgorigoLoggingDestination {
    
    enum CloudWatchDestinationError: Error {
        case destinationReleased
        case logGrouNotFound
        case logStreamNotFound
        case awsNotConfigured
        case putLogsError(nextSeqeunceToken: String?)
    }
    
    fileprivate let client: CloudWatchLogsClient
    
    fileprivate let disposeBag = DisposeBag()
    fileprivate var logUploadStream: LogUploadStream!
    fileprivate let logRelay = ReplayRelay<LogDatabase.LogData>.createUnbound()
    fileprivate var logDelegate: ((LogDatabase.LogData) -> Void)?
    
    public init(
        logGroupNameSingle: Single<String>,
        logStreamNameSingle: Single<String>,
        credentialsProviderHolder: CredentialsProviderHolder,
        region: AWSRegion,
        owner: XCGLogger? = nil,
        formatter: LogFormatterProtocol? = nil,
        outputLevel: XCGLogger.Level = .info,
        identifier: String = String(describing: CloudWatchDestination.self),
        useQueue: Bool = true,
        sendInterval: TimeInterval = 60, // 1 minutes
        maxQueueSize: Int = 1048576, // 1 MBytes
        maxBatchCount: Int = 10000,
        maxMessageSize: Int = 262114, // 256 KBytes
        logGroupRetentionDays: RetentionDays = RetentionDays.month_6,
        createLogGroup: Bool = true,
        createLogStream: Bool = true
    ) throws {
        let configuration: CloudWatchLogsClient.CloudWatchLogsClientConfig
        switch credentialsProviderHolder {
        case .accessKeyProvider(let accessKey, let secretKey):
            let credential = AWSCredentialIdentity(accessKey: accessKey, secret: secretKey)
            let resolver = StaticAWSCredentialIdentityResolver(credential)
            configuration = try CloudWatchLogsClient.CloudWatchLogsClientConfig(awsCredentialIdentityResolver: resolver, region: region.rawValue)
        case .identityPoolProvider(let resolver):
            configuration = try CloudWatchLogsClient.CloudWatchLogsClientConfig(region: region.rawValue, authSchemeResolver: resolver)
        }
        client = CloudWatchLogsClient(config: configuration)
        
        super.init(owner: owner, formatter: formatter, outputLevel: outputLevel, identifier: identifier)
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
                    self?.owner?.warning("init cloud watch error", userInfo: [_Key.errorKey: error])
                }
            }
            .disposed(by: self.disposeBag)
    }
    
    public convenience init(
        logGroupName: String,
        logStreamName: String,
        credentialsProviderHolder: CredentialsProviderHolder,
        region: AWSRegion,
        owner: XCGLogger? = nil,
        formatter: LogFormatterProtocol? = nil,
        outputLevel: XCGLogger.Level = .info,
        identifier: String = String(describing: CloudWatchDestination.self),
        useQueue: Bool = true,
        sendInterval: TimeInterval = 60, // 1 minutes
        maxQueueSize: Int = 1048576, // 1 MBytes
        maxBatchCount: Int = 10000,
        maxMessageSize: Int = 262114, // 256 KBytes
        logGroupRetentionDays: RetentionDays = RetentionDays.month_6,
        createLogGroup: Bool = true,
        createLogStream: Bool = true
    ) throws {
        try self.init(logGroupNameSingle: Single.just(logGroupName), logStreamNameSingle: Single.just(logStreamName), credentialsProviderHolder: credentialsProviderHolder, region: region, owner: owner, formatter: formatter, outputLevel: outputLevel, identifier: identifier, useQueue: useQueue, sendInterval: sendInterval, maxQueueSize: maxQueueSize, maxBatchCount: maxBatchCount, maxMessageSize: maxMessageSize, logGroupRetentionDays: logGroupRetentionDays, createLogGroup: createLogGroup, createLogStream: createLogStream)
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
                self?.owner?.warning("initCloudWatch error", userInfo: [_Key.errorKey: error])
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
            let input = DescribeLogGroupsInput(logGroupNamePrefix: logGroupName)
            Task {
                do {
                    let output = try await self.client.describeLogGroups(input: input)
                    let empty = output.logGroups?.filter({ group in
                        group.logGroupName == logGroupName
                    }).isEmpty ?? true
                    observer(.success(!empty))
                } catch {
                    observer(.failure(error))
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
            let input = CreateLogGroupInput(logGroupName: logGroupName)
            Task {
                do {
                    _ = try await self.client.createLogGroup(input: input)
                    observer(.completed)
                } catch {
                    observer(.error(error))
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
            let input = PutRetentionPolicyInput(logGroupName: logGroupName, retentionInDays: retentionDays.rawValue)
            Task {
                do {
                    _ = try await self.client.putRetentionPolicy(input: input)
                    observer(.completed)
                } catch {
                    observer(.error(error))
                }
            }
            return Disposables.create()
        })
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
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
            let input = DescribeLogStreamsInput(logGroupName: logGroupName, logStreamNamePrefix: logStreamName)
            Task {
                do {
                    let output = try await self.client.describeLogStreams(input: input)
                    let empty = output.logStreams?.filter({ stream in
                        stream.logStreamName == logStreamName
                    }).isEmpty ?? true;
                    observer(.success(!empty))
                } catch {
                    observer(.failure(error))
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
            let input = CreateLogStreamInput(logGroupName: logGroupName, logStreamName: logStreamName)
            Task {
                do {
                    _ = try await self.client.createLogStream(input: input)
                    observer(.completed)
                } catch {
                    observer(.error(error))
                }
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    private func submitLogs(
        logGroupName: String,
        logStreamName: String,
        logs: [LogEvent],
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
            let inputLogEvents = logs.map({ log in
                CloudWatchLogsClientTypes.InputLogEvent(
                    message: log.message,
                    timestamp: log.timestamp,
                )
            })
            let input = PutLogEventsInput(
                logEvents: inputLogEvents, logGroupName: logGroupName, logStreamName: logStreamName, sequenceToken: sequenceToken
            )
            Task {
                do {
                    let output = try await self.client.putLogEvents(input: input)
                    observer(.success((true, output.nextSequenceToken)))
                } catch let error as DataAlreadyAcceptedException {
                    observer(.success((true, error.properties.expectedSequenceToken)))
                } catch let error as InvalidSequenceTokenException {
                    observer(.failure(CloudWatchDestinationError.putLogsError(nextSeqeunceToken: error.properties.expectedSequenceToken)))
                } catch {
                    self.owner?.warning("put log event error", userInfo: [_Key.errorKey: error])
                    observer(.success((false, nil)))
                }
            }
            return Disposables.create()
        }
        .catch({ [weak self] error in
            self?.owner?.warning("Failed to deliver logs error", userInfo: [_Key.errorKey: error])
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
            .map({ sendIndex, logDatas -> (Int, [LogEvent]) in
                return (sendIndex, logDatas.map { logData in
                    LogEvent(
                        message: logData.message,
                        timestamp: Int(logData.timestamp.timeIntervalSince1970 * 1000),
                    )
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
            .map({ logData -> LogEvent in
                LogEvent(
                    message: logData.message,
                    timestamp: Int(logData.timestamp.timeIntervalSince1970 * 1000),
                )
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
            self.owner?.warning("message is not decodable", userInfo: [_Key.errorKey: error])
            return
        }
        
        self.logDelegate?(logData)
    }
}
