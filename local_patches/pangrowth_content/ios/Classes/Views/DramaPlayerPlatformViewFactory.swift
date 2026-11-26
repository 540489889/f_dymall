import Flutter
import Foundation

/// 短剧播放器 PlatformView 工厂类
///
/// 负责创建 DramaPlayerPlatformView 实例
class DramaPlayerPlatformViewFactory: NSObject, FlutterPlatformViewFactory {

    private let contentManager: ContentManager

    init(contentManager: ContentManager) {
        self.contentManager = contentManager
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return DramaPlayerPlatformView(
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
