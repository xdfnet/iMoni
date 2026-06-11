import Foundation

/// DispatchSourceTimer 的轻量封装，消除各 Monitor 中的重复样板代码。
///
/// 用法：
/// ```swift
/// private let timer = TimerHelper()
/// timer.start(queue: queue, interval: 1) { [weak self] in self?.update() }
/// timer.stop()
/// ```
class TimerHelper {
    private var source: DispatchSourceTimer?

    deinit { stop() }

    /// 启动定时器（如果已运行则先停止再重启）。
    /// - Parameters:
    ///   - queue: 事件处理器执行的 dispatch queue
    ///   - interval: 触发间隔（秒）
    ///   - leeway: 允许的延迟窗口（毫秒），默认 100ms 以便系统节能聚合
    ///   - handler: 每次触发时执行的回调
    func start(queue: DispatchQueue, interval: TimeInterval, leeway: Int = 100, handler: @escaping () -> Void) {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        let ms = Int(interval * 1000)
        t.schedule(deadline: .now(), repeating: .milliseconds(ms), leeway: .milliseconds(leeway))
        t.setEventHandler(handler: handler)
        t.activate()
        source = t
    }

    /// 停止定时器，可安全重复调用。
    func stop() {
        source?.cancel()
        source = nil
    }

    /// 定时器当前是否在运行。
    var isActive: Bool { source != nil }
}
