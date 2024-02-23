//
//  MainViewController.swift
//  AlgoLoggerApp
//
//  Created by Rouddy on 2/23/24.
//

import UIKit
import RxSwift
import XCGLogger
import AlgoLogger

class MainViewController: UIViewController {
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
}
