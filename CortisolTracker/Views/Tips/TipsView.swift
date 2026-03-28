import SwiftUI

struct TipsView: View {
    @StateObject private var viewModel = TipsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()

                Group {
                    if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.4)
                            Text("Generating your tips...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.tips.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "lightbulb.slash")
                                .font(.system(size: 56))
                                .foregroundStyle(Color(hex: "8B7EC8").opacity(0.4))
                            Text("No Tips Yet")
                                .font(.title3.weight(.semibold))
                            Text("Take a stress reading to get personalized AI tips")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(viewModel.tips) { tip in
                                    TipCard(tip: tip)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Tips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.loadTips() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color(hex: "1A6B5C"))
                    }
                }
            }
            .task { await viewModel.loadTips() }
            .refreshable { await viewModel.loadTips() }
        }
    }
}

struct TipCard: View {
    let tip: Tip
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "8B7EC8").opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: tip.category.icon)
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "8B7EC8"))
                }

                Text(tip.category.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "8B7EC8"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "8B7EC8").opacity(0.1))
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}
