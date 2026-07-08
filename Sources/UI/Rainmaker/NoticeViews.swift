import SwiftUI

/// 系统通知的 UI 三件套：应用内横幅（iOS 通知样式）+ 消息列表置顶入口 + 通知中心。
/// 旁白不再进聊天流——即时反馈靠横幅，回看靠通知中心。

/// 消息列表 → 通知中心的路由值（与 npcID 的 String 路由区分开）。
enum NoticeRoute: Hashable {
    case center
}

/// 横幅宿主：挂在 App 根视图顶部，监听 store.activeBanner，自动收起。
struct NoticeBannerHost: View {
    @Bindable var store: RainmakerStore
    /// 点横幅 → 打开通知中心。
    let onOpen: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            if let banner = store.activeBanner {
                NoticeBannerCard(notice: banner) {
                    store.dismissBanner()
                    onOpen()
                } onDismiss: {
                    store.dismissBanner()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: banner.id) {
                    try? await Task.sleep(for: .seconds(4))
                    store.dismissBanner()
                }
            }
        }
        .animation(.spring(duration: 0.35), value: store.activeBanner?.id)
    }
}

/// 仿 iOS 通知横幅卡片：圆角材质卡 + 图标 + 标题行 + 正文，上滑关闭、点按进中心。
private struct NoticeBannerCard: View {
    let notice: SystemNotice
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 9)
                .fill(WA.accent)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: "bell.badge.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text("系统通知")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(WA.textPrimary)
                    Spacer(minLength: 8)
                    Text("现在")
                        .font(.caption2)
                        .foregroundStyle(WA.textSecondary)
                }
                Text(notice.text)
                    .font(.footnote)
                    .foregroundStyle(WA.textPrimary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .padding(.horizontal, 10)
        .onTapGesture(perform: onTap)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.height < 0 { onDismiss() }
                }
        )
    }
}

/// 消息列表置顶行（微信「服务通知」形态）：铃铛头像 + 最新一条预览 + 未读角标。
struct NoticeCenterRow: View {
    @Bindable var store: RainmakerStore

    private var latest: SystemNotice? { store.state.noticeLog.last }
    private var unread: Int { store.state.unreadNoticeCount }

    var body: some View {
        HStack(spacing: 12) {
            WAAvatar(systemImage: "bell.badge.fill", background: .orange)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text("系统通知")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(WA.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let latest {
                        Text(RainmakerUI.listTimeLabel(latest.at))
                            .font(.subheadline)
                            .foregroundStyle(unread > 0 ? WA.accent : WA.textSecondary)
                    }
                }
                HStack(alignment: .top, spacing: 4) {
                    Text(latest.map { $0.text.components(separatedBy: "\n")[0] } ?? "世界事件与结算都会在这里")
                        .font(.subheadline)
                        .foregroundStyle(WA.textSecondary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(WA.accent, in: Capsule())
                    }
                }
            }
        }
    }
}

/// 通知中心：与聊天线程同形态——涂鸦壁纸 + 信息卡片气泡，
/// 旧→新往下排、最新一条在最底部（进页即滚到底、全部已读）。
struct NoticeCenterView: View {
    @Bindable var store: RainmakerStore

    private var notices: [SystemNotice] { store.state.noticeLog }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(notices) { notice in
                        NoticeBubble(notice: notice)
                            .id(notice.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(WADoodleWallpaper())
            .defaultScrollAnchor(.bottom)
            .onChange(of: notices.count) {
                store.markNoticesRead()
                if let last = notices.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .overlay {
            if notices.isEmpty {
                ContentUnavailableView("暂无通知", systemImage: "bell.slash", description: Text("世界事件、每日结算、谈判记分都会落在这里。"))
            }
        }
        .navigationTitle("系统通知")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.markNoticesRead() }
    }
}

/// 通知信息卡片：与聊天来消息同款左侧气泡（带尾巴 + 时间戳）。
private struct NoticeBubble: View {
    let notice: SystemNotice

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(notice.text)
                    .font(.callout)
                    .foregroundStyle(WA.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(RainmakerUI.timeLabel(notice.at))
                    .font(.caption2)
                    .foregroundStyle(WA.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(WA.bubbleIn)
            .clipShape(BubbleShape(mine: false))
            Spacer(minLength: 48)
        }
    }
}
