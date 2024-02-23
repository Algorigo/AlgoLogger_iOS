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

enum RotatingFileDestinationError: Error {
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
    
    fileprivate let logFileRelay = PublishRelay<URL>()
    
    fileprivate var rotatedTimeInterval: TimeInterval
    fileprivate var rotateThresholdInterval: TimeInterval
    
    public init(writeToFile: Any, owner: XCGLogger? = nil, identifier: String = "", outputLevel: XCGLogger.Level = .debug, shouldAppend: Bool = true, maxFileSize: UInt64 = 10 * 1024 * 1024, targetMaxLogFiles: UInt8 = 5, rotateCheckInterval: TimeInterval = 300, maxTimeInterval: TimeInterval = 0, appendMarker: String? = "-- ** ** ** --", attributes: [FileAttributeKey : Any]? = nil) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        self.rotatedTimeInterval = 0
        self.rotateThresholdInterval = rotateCheckInterval
        super.init(owner: owner, writeToFile: writeToFile, identifier: identifier, shouldAppend: shouldAppend, appendMarker: appendMarker, maxFileSize: maxFileSize, maxTimeInterval: maxTimeInterval, archiveSuffixDateFormatter: formatter, targetMaxLogFiles: targetMaxLogFiles)
        self.outputLevel = outputLevel
    }
    
    public init(relativePath: String, owner: XCGLogger? = nil, identifier: String = "", outputLevel: XCGLogger.Level = .debug, shouldAppend: Bool = true, maxFileSize: UInt64 = 10 * 1024 * 1024, targetMaxLogFiles: UInt8 = 5, rotateCheckInterval: TimeInterval = 300, maxTimeInterval: TimeInterval = 0, appendMarker: String? = "-- ** ** ** --", attributes: [FileAttributeKey : Any]? = nil) throws {
        let path = try RotatingFileDestination.getPathUrl(relativePath: relativePath)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        self.rotatedTimeInterval = 0
        self.rotateThresholdInterval = rotateCheckInterval
        super.init(owner: owner, writeToFile: path, identifier: identifier, shouldAppend: shouldAppend, appendMarker: appendMarker, maxFileSize: maxFileSize, maxTimeInterval: maxTimeInterval, archiveSuffixDateFormatter: formatter, targetMaxLogFiles: targetMaxLogFiles)
        self.outputLevel = outputLevel
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
}
