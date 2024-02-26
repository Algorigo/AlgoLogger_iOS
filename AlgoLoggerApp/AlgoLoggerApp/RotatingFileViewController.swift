//
//  ViewController.swift
//  AlgoLoggerApp
//
//  Created by Jaehong Yoo on 2023/02/23.
//

import UIKit
import RxSwift
import XCGLogger
import AlgoLogger
import AWSS3

class RotatingFileViewController: UIViewController {
    
    fileprivate class PathFormatter: DateFormatter {
        override init() {
            super.init()
            dateFormat = "yyyy/MM/dd"
            timeZone = TimeZone(abbreviation: "UTC")
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            dateFormat = "yyyy/MM/dd"
            timeZone = TimeZone(abbreviation: "UTC")
        }
    }
    
    fileprivate class KeyFormatter: DateFormatter {
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
    
    fileprivate static let pathFormatter = PathFormatter()
    fileprivate static let keyFormatter = KeyFormatter()
    fileprivate static let accessKey = ""
    fileprivate static let secretKey = ""
    fileprivate static let region = AWSRegionType.APNortheast2
    
    @IBOutlet weak var logTableView: UITableView!
    
    private var logs = [URL]()
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        logTableView.estimatedRowHeight = 68.0
        logTableView.rowHeight = UITableView.automaticDimension
        
        logTableView.reloadData()
        
        initLog()
        subscribeRotatingFileDestination()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        L.debug(TestTag, "destination:\(segue.destination), sender:\(String(describing: sender))")
        if let viewController = segue.destination as? LogViewController,
           let logURL = sender as? URL,
           let contents = try? String(contentsOf: logURL, encoding: .utf8) {
            viewController.setLog(log: contents)
        }
    }
    
    @IBAction func handleRotate(_ sender: Any) {
        if let rotatingFileDestination = LogManager.singleton.getLogger(TestTag).destination(withIdentifier: "RotatingFileDestination") as? RotatingFileDestination {
            rotatingFileDestination.rotateFile()
        }
    }
    
    fileprivate func initLog() {
        // Do any additional setup after loading the view.
        L.verbose(TestTag, "verbose")
        L.debug(TestTag, "debug")
        L.info(TestTag, "info")
        L.notice(TestTag, "notice")
        L.warning(TestTag, "warning")
        L.error(TestTag, "error")
        L.assert(TestTag, "assert")
        L.warning(TestTag.TestTag2, "TestTag.TestTag2")
        L.warning(TestTag.TestTag2.TestTag3, "TestTag.TestTag2.TestTag3")
        L.warning(TestTag.TestTag4, "TestTag.TestTag4")
        
        do {
            throw NSError(domain: "test", code: 0, userInfo: nil)
        } catch {
            L.error(TestTag, "error", error: error, callStackSymbols: Thread.callStackSymbols)
        }
        
        Observable<Int>.interval(RxTimeInterval.seconds(5), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { value in
                L.info(TestTag.TestTag2, "intervaled:\(value)")
            })
            .disposed(by: disposeBag)
    }
    
    fileprivate func subscribeRotatingFileDestination() {
        if let rotatingFileDestination = LogManager.singleton.getLogger(TestTag).destination(withIdentifier: "RotatingFileDestination") as? RotatingFileDestination {
            rotatingFileDestination.getLogFileObservable()
                .debounce(RxTimeInterval.seconds(1), scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                .map { url in
                    return rotatingFileDestination.archivedFileURLs()
                        .sorted { left, right in
                            left.absoluteString < right.absoluteString
                        }
                }
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] urls in
                    self?.logs = urls
                    self?.logTableView.reloadData()
                })
                .disposed(by: disposeBag)
            
            rotatingFileDestination.registerS3Uploader(accessKey: RotatingFileViewController.accessKey, secretKey: RotatingFileViewController.secretKey, region: RotatingFileViewController.region, bucketName: "woon") { logFile in
                "log_file/\(RotatingFileViewController.pathFormatter.string(from: logFile.rotatedDate))/algorigo_logger_ios-log-\(RotatingFileViewController.keyFormatter.string(from: logFile.rotatedDate)).log"
            }
        }
    }
}

extension RotatingFileViewController : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: LogTableViewCell
        if let _cell = tableView.dequeueReusableCell(withIdentifier: "log_cell") as? LogTableViewCell {
            cell = _cell
        } else {
            cell = LogTableViewCell()
        }
        cell.setLogFile(file: logs[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "log_text_segue", sender: logs[indexPath.row])
    }
}
