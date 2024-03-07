//
//  File.swift
//
//
//  Created by Rouddy on 2/22/24.
//

import Foundation
import XCGLogger
import RxSwift
import RxRelay
import AWSS3

enum RotatingFileDestinationError: Error {
    case destinationReleased
    case fileNotFound
    case fileNotWritable
    case awsNotConfigured
}

public class RotatingFileDestination: AutoRotatingFileDestination {
    
    fileprivate class RFDateFormatter: DateFormatter {
        override init() {
            super.init()
            dateFormat = "yyyy-MM-dd-HH-mm-ss"
            timeZone = TimeZone(abbreviation: "UTC")
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            dateFormat = "yyyy-MM-dd-HH-mm-ss"
            timeZone = TimeZone(abbreviation: "UTC")
        }
    }
    
    public struct LogFile {
        let base: String
        public let rotatedDate: Date
        public let postfix: String
        
        internal var path: String {
            "\(base)\(RotatingFileDestination.formatter.string(from: rotatedDate))\(postfix).log"
        }
        
        init(base: String, rotatedDate: Date = Date(), postfix: String = "") {
            self.base = base
            self.rotatedDate = rotatedDate
            self.postfix = postfix
        }
        
        init?(url: URL) {
            let rotatedDateString: String
            if #available(iOS 16.0, *) {
                let fullPath = url.path(percentEncoded: true)
                guard let regex = try? Regex("^(.*)([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2})(.*).log$") else {
                    return nil
                }
                guard let match = try? regex.firstMatch(in: fullPath) else {
                    return nil
                }
                guard let match1 = match[1].value as? Substring else {
                    return nil
                }
                guard let match2 = match[2].value as? Substring else {
                    return nil
                }
                guard let match3 = match[3].value as? Substring else {
                    return nil
                }
                self.base = String(describing: match1)
                rotatedDateString = String(describing: match2)
                self.postfix = String(describing: match3)
            } else {
                let fullPath = url.path
                guard let regex = try? NSRegularExpression(pattern: "^(.*)([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2})(.*).log$", options: []) else {
                    return nil
                }
                guard let match = regex.firstMatch(in: fullPath, options: [], range: NSRange(location: 0, length: fullPath.count)) else {
                    return nil
                }
                guard let range1 = Range(match.range(at: 1), in: fullPath) else {
                    return nil
                }
                guard let range2 = Range(match.range(at: 2), in: fullPath) else {
                    return nil
                }
                guard let range3 = Range(match.range(at: 3), in: fullPath) else {
                    return nil
                }
                self.base = String(fullPath[range1])
                rotatedDateString = String(fullPath[range2])
                self.postfix = String(fullPath[range3])
            }
            guard let rotatedDate = RotatingFileDestination.formatter.date(from: rotatedDateString) else {
                return nil
            }
            self.rotatedDate = rotatedDate
        }

        func withPostfix(postfix: String) -> LogFile {
            return LogFile(base: base, rotatedDate: rotatedDate, postfix: postfix)
        }
    }
    
    fileprivate static let formatter = RFDateFormatter()
    
    fileprivate static func getPathUrl(relativePath: String) throws -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[urls.endIndex - 1]
        let logURL = documentsDirectory.appendingPathComponent(relativePath)
        let directory = logURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return logURL
    }
    
    fileprivate static func getS3Single(
        accessKey: String,
        secretKey: String,
        region: AWSRegionType
    ) -> Single<AWSS3> {
        return Single<AWSS3>.create(subscribe: { observer in
            let key = "S3_\(accessKey)_\(region)"
            let credential = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
            let configuration = AWSServiceConfiguration(region: region, credentialsProvider: credential)!
            AWSS3.register(with: configuration, forKey: key)
            observer(.success(AWSS3.s3(forKey: key)))
            return Disposables.create()
        })
    }
    
    public static func setPostfix(logFile: LogFile, postfix: String) -> LogFile? {
        guard FileManager.default.fileExists(atPath: logFile.path) else {
            return nil
        }
        guard logFile.postfix != postfix else {
            return logFile
        }

        let renameTo = logFile.withPostfix(postfix: postfix)
        do {
            try FileManager.default.moveItem(atPath: logFile.path, toPath: renameTo.path)
            return renameTo
        } catch {
            return nil
        }
    }

    fileprivate let logFileRelay = PublishRelay<URL>()
    
    fileprivate var rotatedTimeInterval: TimeInterval
    fileprivate var rotateThresholdInterval: TimeInterval
    
    fileprivate var uploadDisposable: Disposable? = nil
    
    public init(writeToFile: Any, owner: XCGLogger? = nil, outputLevel: XCGLogger.Level = .debug, identifier: String = String(describing: RotatingFileDestination.self), shouldAppend: Bool = true, maxFileSize: UInt64 = 10 * 1024 * 1024, targetMaxLogFiles: UInt8 = 5, rotateCheckInterval: TimeInterval = 300, maxTimeInterval: TimeInterval = 0, appendMarker: String? = "-- ** ** ** --", attributes: [FileAttributeKey : Any]? = nil) {
        self.rotatedTimeInterval = 0
        self.rotateThresholdInterval = rotateCheckInterval
        super.init(owner: owner ?? LogManager.defaultLogger, writeToFile: writeToFile, identifier: identifier, shouldAppend: shouldAppend, appendMarker: appendMarker, maxFileSize: maxFileSize, maxTimeInterval: maxTimeInterval, archiveSuffixDateFormatter: RotatingFileDestination.formatter, targetMaxLogFiles: targetMaxLogFiles)
        self.outputLevel = outputLevel
    }
    
    public init(relativePath: String, owner: XCGLogger? = nil, identifier: String = String(describing: RotatingFileDestination.self), outputLevel: XCGLogger.Level = .debug, shouldAppend: Bool = true, maxFileSize: UInt64 = 10 * 1024 * 1024, targetMaxLogFiles: UInt8 = 5, rotateCheckInterval: TimeInterval = 300, maxTimeInterval: TimeInterval = 0, appendMarker: String? = "-- ** ** ** --", attributes: [FileAttributeKey : Any]? = nil) throws {
        let path = try RotatingFileDestination.getPathUrl(relativePath: relativePath)
        self.rotatedTimeInterval = 0
        self.rotateThresholdInterval = rotateCheckInterval
        super.init(owner: owner ?? LogManager.defaultLogger, writeToFile: path, identifier: identifier, shouldAppend: shouldAppend, appendMarker: appendMarker, maxFileSize: maxFileSize, maxTimeInterval: maxTimeInterval, archiveSuffixDateFormatter: RotatingFileDestination.formatter, targetMaxLogFiles: targetMaxLogFiles)
        self.outputLevel = outputLevel
    }
    
    deinit {
        uploadDisposable?.dispose()
        uploadDisposable = nil
    }
    
    public override func rotateFile(to archiveToFile: Any, closure: ((Bool) -> Void)? = nil) -> Bool {
        return super.rotateFile(to: archiveToFile, closure: { [weak self] success in
            if success {
                self?.rotatedTimeInterval = Date().timeIntervalSince1970
                var archiveToFileURL: URL!
                if archiveToFile is NSString {
                    archiveToFileURL = URL(fileURLWithPath: archiveToFile as! String)
                } else if let archiveToFile = archiveToFile as? URL, archiveToFile.isFileURL {
                    archiveToFileURL = archiveToFile
                }
                
                self?.logFileRelay.accept(archiveToFileURL)
            }
            closure?(success)
        })
    }
    
    public override func shouldRotate() -> Bool {
        if (targetMaxTimeInterval == 0 || targetMaxTimeInterval > rotateThresholdInterval) &&
            Date().timeIntervalSince1970 - rotatedTimeInterval < rotateThresholdInterval {
            return false
        }
        
        return super.shouldRotate()
    }
    
    public func getLogFileObservable() -> Observable<URL> {
        return Single<[URL]>.just(archivedFileURLs())
            .asObservable()
            .flatMap { list in
                Observable.from(list)
            }
            .concat(logFileRelay.asObservable())
    }
    
    public func registerS3Uploader(
        accessKey: String,
        secretKey: String,
        region: AWSRegionType,
        bucketName: String,
        keyDelegate: @escaping (LogFile) -> String
    ) {
        uploadDisposable?.dispose()
        uploadDisposable = RotatingFileDestination.getS3Single(accessKey: accessKey, secretKey: secretKey, region: region)
            .asObservable()
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .flatMap({ [weak self] awsS3 in
                guard let self = self else { return Observable<Never>.error(RotatingFileDestinationError.destinationReleased) }
                
                return self.getLogFileObservable()
                    .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                    .flatMap({ url in
                        if let logFile = LogFile(url: url) {
                            return Observable.just(logFile)
                        } else {
                            return Observable.empty()
                        }
                    })
                    .filter({ logFile in
                        logFile.postfix.isEmpty
                    })
                    .concatMap { logFile in
                        return awsS3
                            .putObjectCompletable(logFile: logFile, bucketName: bucketName, keyDelegate: keyDelegate)
                            .retry(when: { errorObservable in
                                errorObservable
                                    .delay(RxTimeInterval.seconds(60), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                            })
                            .do(onCompleted: {
                                _ = RotatingFileDestination.setPostfix(logFile: logFile, postfix: "s3")
                            })
                    }
            })
            .ignoreElements()
            .subscribe(onError: { [weak self] error in
                self?.owner?.info("registerS3Uploader error", userInfo: [L.error: error])
            })
    }
    
    public func registerS3Uploader(
        accessKey: String,
        secretKey: String,
        region: AWSRegionType,
        bucketName: String,
        dateFormatter: DateFormatter
    ) {
        uploadDisposable?.dispose()
        uploadDisposable = RotatingFileDestination.getS3Single(accessKey: accessKey, secretKey: secretKey, region: region)
            .asObservable()
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .flatMap({ [weak self] awsS3 in
                guard let self = self else { return Observable<Never>.error(RotatingFileDestinationError.destinationReleased) }
                
                return self.getLogFileObservable()
                    .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                    .flatMap({ url in
                        if let logFile = LogFile(url: url) {
                            return Observable.just(logFile)
                        } else {
                            return Observable.empty()
                        }
                    })
                    .filter({ logFile in
                        logFile.postfix.isEmpty
                    })
                    .concatMap { logFile in
                        return awsS3
                            .putObjectCompletable(logFile: logFile, bucketName: bucketName) { logFile in
                                dateFormatter.string(from: logFile.rotatedDate)
                            }
                            .retry(when: { errorObservable in
                                errorObservable
                                    .delay(RxTimeInterval.seconds(60), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                            })
                            .do(onCompleted: {
                                _ = RotatingFileDestination.setPostfix(logFile: logFile, postfix: "s3")
                            })
                    }
            })
            .ignoreElements()
            .subscribe(onError: { [weak self] error in
                self?.owner?.info("registerS3Uploader error", userInfo: [L.error: error])
            })
    }
    
    public func unregisterUploader() {
        uploadDisposable?.dispose()
        uploadDisposable = nil
    }
}

extension AWSS3 {
    func putObjectCompletable(logFile: RotatingFileDestination.LogFile, bucketName: String, keyDelegate: @escaping (RotatingFileDestination.LogFile) -> String) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(RotatingFileDestinationError.destinationReleased))
                return Disposables.create()
            }
            
            if FileManager.default.fileExists(atPath: logFile.path),
               let data = try? Data(contentsOf: URL(fileURLWithPath: logFile.path)) {
                if let request = AWSS3PutObjectRequest() {
                    request.bucket = bucketName
                    request.key = keyDelegate(logFile)
                    request.body = data
                    request.contentLength = NSNumber(value: UInt64(data.count))
                    request.contentType = "text/plain"
                    self.putObject(request) { output, error in
                        if let error = error {
                            observer(.error(error))
                        } else {
                            observer(.completed)
                        }
                    }
                } else {
                    observer(.error(RotatingFileDestinationError.awsNotConfigured))
                }
            } else {
                observer(.completed)
            }
            return Disposables.create()
        }
    }
}
