import StoreKit
import SwiftUI

/// Native subscription paywall backed by the Premium subscription group.
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(groupID: StoreService.subscriptionGroupID) {
            VStack(spacing: Design.spacing) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                Text("Janey Premium")
                    .font(.system(.title, design: .rounded))
                    .bold()
                Text("Festivus holiday themes and stats sync across your devices.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .storeButton(.visible, for: .restorePurchases)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result {
                await model.store.refreshEntitlement()
                dismiss()
            }
        }
    }
}
