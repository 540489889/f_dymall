import Flutter
import UIKit

/// UserProfile PlatformView 工厂类
/// 负责创建UserProfilePlatformView实例
class UserProfilePlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private weak var messenger: FlutterBinaryMessenger?

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return UserProfilePlatformView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
