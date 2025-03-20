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

public enum RotatingFileDestinationError: Error {
    case destinationReleased
    case fileNotFound
    case fileNotWritable
}

public class RotatingFileDestination: AutoRotatingFileDestination {
    
    
    fileprivate static func getPathUrl(relativePath: String) throws -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[urls.endIndex - 1]
        let logURL = documentsDirectory.appendingPathComponent(relativePath)
        let directory = logURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return logURL
    }
    
    public static func setPostfix(logFile: RatatingLogFile, postfix: String) -> RatatingLogFile? {
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
        super.init(owner: owner ?? LogManager.defaultLogger, writeToFile: writeToFile, identifier: identifier, shouldAppend: shouldAppend, appendMarker: appendMarker, maxFileSize: maxFileSize, maxTimeInterval: maxTimeInterval, archiveSuffixDateFormatter: RFDateFormatter.formatter, targetMaxLogFiles: targetMaxLogFiles)
        self.outputLevel = outputLevel
    }
    
    public init(relativePath: String, owner: XCGLogger? = nil, identifier: String = String(describing: RotatingFileDestination.self), outputLevel: XCGLogger.Level = .debug, shouldAppend: Bool = true, maxFileSize: UInt64 = 10 * 1024 * 1024, targetMaxLogFiles: UInt8 = 5, rotateCheckInterval: TimeInterval = 300, maxTimeInterval: TimeInterval = 0, appendMarker: String? = "-- ** ** ** --", attributes: [FileAttributeKey : Any]? = nil) throws {
        let path = try RotatingFileDestination.getPathUrl(relativePath: relativePath)
        self.rotatedTimeInterval = 0
        self.rotateThresholdInterval = rotateCheckInterval
        super.init(owner: owner ?? LogManager.defaultLogger, writeToFile: path, identifier: identifier, shouldAppend: shouldAppend, appendMarker: appendMarker, maxFileSize: maxFileSize, maxTimeInterval: maxTimeInterval, archiveSuffixDateFormatter: RFDateFormatter.formatter, targetMaxLogFiles: targetMaxLogFiles)
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
    
    public func getLogFileObservable() -> Observable<RatatingLogFile> {
        return Single<[URL]>.just(archivedFileURLs())
            .asObservable()
            .flatMap { list in
                Observable.from(list)
            }
            .concat(logFileRelay.asObservable())
            .flatMap({ url in
                if let logFile = RatatingLogFile(url: url) {
                    return Observable.just(logFile)
                } else {
                    return Observable.empty()
                }
            })
    }
    
    public func registerUploader(completable: Completable) {
        uploadDisposable?.dispose()
        uploadDisposable = completable
            .subscribe(onError: { [weak self] error in
                self?.owner?.info("registerS3Uploader error", userInfo: [L.errorKey: error])
            })
    }
    
    public func unregisterUploader() {
        uploadDisposable?.dispose()
        uploadDisposable = nil
    }
}
