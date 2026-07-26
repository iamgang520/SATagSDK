//
// SwiftDemoUsage.swift
// SATagSDKDemo
//
// 该文件用于编译验证 SATagSDK 的 Objective-C 头文件可以直接导入 Swift。
// Demo 的实际页面仍使用 Objective-C，接入方可复制下面的调用方式。
//

import SATagSDK
import UIKit

final class SATagSwiftDemoUsage {
    static func initializeAndTrack(from viewController: UIViewController) {
        let sdk = SATagSDK.sharedInstance()
        sdk.initialize(
            withAppsFlyerDevKey: "YOUR_APPSFLYER_DEV_KEY",
            appleAppID: "YOUR_APPLE_APP_ID"
        ) { results in
            results.forEach { result in
                print("[SATagSDK Swift Demo] \(result.providerName): \(result.state)")
            }
        }

        sdk.track(
            event: "swift_demo_event",
            parameters: ["source": "swift-demo"]
        ) { results in
            print("[SATagSDK Swift Demo] \(results)")
        }

        sdk.presentDebugView(from: viewController)
    }
}
