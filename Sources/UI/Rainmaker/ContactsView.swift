import SwiftUI

/// 通讯录：全部商界联系人（含助理）。点开进对应线程。
struct ContactsView: View {
    @Bindable var store: RainmakerStore

    /// 与消息页一致：助理 + 债主 + 商界联系人 + 八圈子驻场贩子。
    private var allProfiles: [NPCProfile] {
        [NPCCatalog.assistant, NPCCatalog.creditor] + NPCCatalog.contacts + NPCCatalog.dealers
    }

    var body: some View {
        NavigationStack {
            List(allProfiles) { profile in
                NavigationLink {
                    RainmakerThreadView(store: store, npcID: profile.id)
                } label: {
                    HStack(spacing: 12) {
                        NPCAvatar(npcID: profile.id, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.body)
                                .foregroundStyle(WA.textPrimary)
                            Text(profile.role)
                                .font(.footnote)
                                .foregroundStyle(WA.textSecondary)
                        }
                    }
                }
                .listRowSeparatorTint(WA.separator)
            }
            .listStyle(.plain)
            .background(WA.listBg)
            .navigationTitle("通讯录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
