import SwiftUI

struct JoinedPillPicker<Option: Hashable & Identifiable>: View where Option.ID == String {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var height: CGFloat = 62

    var body: some View {
        GeometryReader { geometry in
            let segmentWidth = geometry.size.width / CGFloat(max(options.count, 1))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(InLANTheme.pillGradient)
                    .background(
                        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                            .fill(InLANTheme.panel)
                    )

                RoundedRectangle(cornerRadius: height / 2 - 5, style: .continuous)
                    .fill(InLANTheme.selected)
                    .frame(width: max(segmentWidth - 8, 1), height: height - 10)
                    .offset(x: segmentWidth * CGFloat(selectedIndex) + 4)
                    .animation(.easeInOut(duration: 0.18), value: selection)

                HStack(spacing: 0) {
                    ForEach(options) { option in
                        Button {
                            selection = option
                        } label: {
                            Text(title(option))
                                .font(.system(size: height > 56 ? 19 : 17, weight: option == selection ? .semibold : .regular, design: .rounded))
                                .foregroundStyle(option == selection ? InLANTheme.primaryText : InLANTheme.secondaryText)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("choose-\(option.id)")
                        .accessibilityAddTraits(option == selection ? .isSelected : [])
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .stroke(InLANTheme.border, lineWidth: 1)
            )
        }
        .frame(height: height)
    }

    private var selectedIndex: Int {
        options.firstIndex(of: selection) ?? 0
    }
}
