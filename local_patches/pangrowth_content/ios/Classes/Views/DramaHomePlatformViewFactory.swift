import Flutter
import Foundation

/// 短剧聚合页 PlatformView 工厂类
///
/// 负责创建 DramaHomePlatformView 实例
class DramaHomePlatformViewFactory: NSObject, FlutterPlatformViewFactory {

    private let contentManager: ContentManager

    init(contentManager: ContentManager) {
        self.contentManager = contentManager
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return DramaHomePlatformView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            contentManager: contentManager
        )
    }

    /// 创建带编码的参数（如果需要）
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
