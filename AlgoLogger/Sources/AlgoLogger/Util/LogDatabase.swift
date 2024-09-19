//
//  File.swift
//  
//
//  Created by Rouddy on 2/27/24.
//

import Foundation

import SQLite
import RxSwift

class LogDatabase {
    
    enum LogDatabaseError: Error {
        case logDatabaseReleased
        case messageNotEncodable
        case noElement
    }
    
    struct LogData {
        fileprivate static let EXTRA_MSG_PAYLOAD_SIZE = 26
        
        let message: String
        let timestamp: Date
        let size: Int
        
        init(message: String, timestamp: Date, maxSize: Int = Int.max) throws {
            self.timestamp = timestamp
            guard let data = message.data(using: .utf8) else {
                throw LogDatabaseError.messageNotEncodable
            }
            
            let dataSize = data.count + LogData.EXTRA_MSG_PAYLOAD_SIZE
            if dataSize > maxSize {
                self.size = maxSize
                self.message = data.subdata(in: 0..<maxSize - LogData.EXTRA_MSG_PAYLOAD_SIZE).string()
            } else {
                self.size = data.count
                self.message = message
            }
        }
        
    }
    
    fileprivate static let DATABASE_NAME = "android_cloudwatch_log.db"
    
    fileprivate static let LOG_TABLE = Table("log")
    fileprivate static let COLUMN_ID = SQLite.Expression<Int64>("_id")
    fileprivate static let COLUMN_MESSAGE = SQLite.Expression<String>("message")
    fileprivate static let COLUMN_TIMESTAMP = SQLite.Expression<Date>("timestamp")
    fileprivate static let COLUMN_SIZE = SQLite.Expression<Int64>("size")
    fileprivate static let COLUMN_CREATED_AT = SQLite.Expression<Date>("created_at")
    fileprivate static let COLUMN_SEND_INDEX = SQLite.Expression<Int64>("send_index")
    
    fileprivate static func getPathUrl(relativePath: String) throws -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[urls.endIndex - 1]
        let logURL = documentsDirectory.appendingPathComponent(relativePath)
        let directory = logURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return logURL
    }
    
    static func connect(relativePath: String = DATABASE_NAME) -> Observable<LogDatabase> {
        return Observable.create { observer in
            let database = LogDatabase()
            do {
                let path = try LogDatabase.getPathUrl(relativePath: relativePath)
                try database.initialize(path: path.absoluteString)
                observer.onNext(database)
            } catch {
                observer.onError(error)
            }
            return Disposables.create {
                database.close()
            }
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    fileprivate var connection: Connection!
    
    func initialize(path: String) throws {
        let connection = try Connection(path)
        try connection.run(LogDatabase.LOG_TABLE.create(ifNotExists: true) { t in
            t.column(LogDatabase.COLUMN_ID, primaryKey: .autoincrement)
            t.column(LogDatabase.COLUMN_MESSAGE)
            t.column(LogDatabase.COLUMN_TIMESTAMP)
            t.column(LogDatabase.COLUMN_SIZE)
            t.column(LogDatabase.COLUMN_CREATED_AT, defaultValue: Date())
            t.column(LogDatabase.COLUMN_SEND_INDEX)
        })
        self.connection = connection
    }
    
    func close() {
        self.connection = nil
    }
    
    func insert(log: LogData) -> Single<Int64> {
        return Single.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(LogDatabaseError.logDatabaseReleased))
                return Disposables.create()
            }
            do {
                let insert = LogDatabase.LOG_TABLE.insert(
                    LogDatabase.COLUMN_MESSAGE <- log.message,
                    LogDatabase.COLUMN_TIMESTAMP <- log.timestamp,
                    LogDatabase.COLUMN_SIZE <- Int64(log.message.count),
                    LogDatabase.COLUMN_CREATED_AT <- Date(),
                    LogDatabase.COLUMN_SEND_INDEX <- 0
                )
                let rowId = try self.connection.run(insert)
                observer(.success(rowId))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    func selectForId(id: Int64) -> Single<Date> {
        return Single<Date>.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(LogDatabaseError.logDatabaseReleased))
                return Disposables.create()
            }
            do {
                let query = LogDatabase.LOG_TABLE
                    .where(LogDatabase.COLUMN_ID == id)
                let logs = Array(try self.connection.prepare(query))
                if logs.count == 1 {
                    let row = logs[0]
                    observer(.success(row[LogDatabase.COLUMN_CREATED_AT]))
                } else {
                    observer(.failure(LogDatabaseError.noElement))
                }
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    func selectBetween(from: Date, to: Date, sendIndex: Int64) -> Single<[LogData]> {
        return Single<[LogData]>.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(LogDatabaseError.logDatabaseReleased))
                return Disposables.create()
            }
            do {
                let query = LogDatabase.LOG_TABLE
                    .where(from...to ~= LogDatabase.COLUMN_TIMESTAMP && LogDatabase.COLUMN_SEND_INDEX == 0)
                    .order(LogDatabase.COLUMN_TIMESTAMP.asc)
                let logs = Array(try self.connection.prepare(query))
                let ids = logs.map { row in
                    row[LogDatabase.COLUMN_ID]
                }
                let update = LogDatabase.LOG_TABLE
                    .filter(ids.contains(LogDatabase.COLUMN_ID))
                    .update(LogDatabase.COLUMN_SEND_INDEX <- sendIndex)
                try self.connection.run(update)
                let logDatas = try logs.map { row in
                    let message = row[LogDatabase.COLUMN_MESSAGE]
                    let timestamp = row[LogDatabase.COLUMN_TIMESTAMP]
                    return try LogData(message: message, timestamp: timestamp)
                }
                observer(.success(logDatas))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    func delete(sendIndex: Int64) -> Single<Int> {
        return Single.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(LogDatabaseError.logDatabaseReleased))
                return Disposables.create()
            }
            do {
                let delete = LogDatabase.LOG_TABLE
                    .filter(LogDatabase.COLUMN_SEND_INDEX == sendIndex)
                    .delete()
                observer(.success(try self.connection.run(delete)))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    func countAndSize() -> Single<(Int, Int64)> {
        return Single.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(LogDatabaseError.logDatabaseReleased))
                return Disposables.create()
            }
            do {
                let count = try self.connection.scalar(LogDatabase.LOG_TABLE.count)
                let sum = try self.connection.scalar(LogDatabase.LOG_TABLE.select(LogDatabase.COLUMN_SIZE.sum)) ?? 0
                observer(.success((count, sum)))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    func deleteBefore(date: Date) -> Single<Int> {
        return Single.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(LogDatabaseError.logDatabaseReleased))
                return Disposables.create()
            }
            do {
                let delete = LogDatabase.LOG_TABLE
                    .filter(LogDatabase.COLUMN_TIMESTAMP < date)
                    .delete()
                observer(.success(try self.connection.run(delete)))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
    
    func updateAllSendIndexZero() -> Single<Int> {
        return Single.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(LogDatabaseError.logDatabaseReleased))
                return Disposables.create()
            }
            do {
                let update = LogDatabase.LOG_TABLE
                    .update(LogDatabase.COLUMN_SEND_INDEX <- 0)
                observer(.success(try self.connection.run(update)))
            } catch {
                observer(.failure(error))
            }
            return Disposables.create()
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
}

fileprivate extension Data {
    func string() -> String {
        return String(data: self, encoding: .utf8) ?? subdata(in: 0..<count-1).string()
    }
}
