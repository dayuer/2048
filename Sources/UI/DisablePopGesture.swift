import SwiftUI

/// 关闭所在 UINavigationController 的边缘返回手势（interactivePopGestureRecognizer），
/// 让整块区域的右滑只作为游戏输入，退出改由左上角返回按钮完成。
/// 离开该页时自动恢复，不影响导航栈里的其他页面。
struct DisablePopGesture: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { PopGestureController() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class PopGestureController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}
