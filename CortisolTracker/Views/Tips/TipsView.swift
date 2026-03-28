import SwiftUI

struct TipsView: View {
    @StateObject private var viewModel = TipsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Generating tips...")
                        .padding(.top, 60)
                } else if viewModel.tips.isEmpty {
                    ContentUnavailableView(
                        "No Tips Yet",
                        systemImage: "lightbulb.slash",
                        description: Text("Take a stress reading to get personalized tips")
                    )
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.tips) { tip in
                            TipCard(tip: tip)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tips")
            .task {
                await viewModel.loadTips()
            }
            .refreshable {
                await viewModel.loadTips()
            }
        }
    }
}

struct TipCard: View {
    let tip: Tip
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: tip.category.icon)
                    .foregroundStyle(.purple)
                    .frame(width: 28)

                Text(tip.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.purple.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(tip.title)
                .font(.headline)

            if isExpanded {
                Text(tip.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}
