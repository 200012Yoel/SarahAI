from pathlib import Path

p = Path('SarahIA/SarahIA/Views/ChatScreenView.swift')
s = p.read_text()
start = s.index('    private func choiceCard(')
end = s.index('    private func normalizedVoiceText', start)

replacement = '''    private func choiceCard(
        number: Int,
        title: String,
        detail: String,
        icon: String,
        selected: Bool,
        focused: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let active = selected || focused
        let iconColor: Color = active ? .white : .purple
        let badgeForeground: Color = active ? .black : .white.opacity(0.66)
        let badgeBackground: Color = active ? .white : .white.opacity(0.08)
        let detailColor: Color = active ? .white.opacity(0.88) : .white.opacity(0.48)

        let fillColor: Color
        if selected {
            fillColor = .purple.opacity(0.23)
        } else if focused {
            fillColor = .purple.opacity(0.13)
        } else {
            fillColor = .white.opacity(0.055)
        }

        let strokeColor: Color = active ? .purple.opacity(0.98) : .white.opacity(0.10)
        let strokeWidth: CGFloat = focused ? 2.2 : (selected ? 1.5 : 1.0)
        let shadowColor: Color = focused ? .purple.opacity(0.60) : (selected ? .purple.opacity(0.16) : .clear)
        let shadowRadius: CGFloat = focused ? 24 : 15

        return Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(iconColor)
                    Spacer()
                    Text("\\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(badgeForeground)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(badgeBackground))
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(detailColor)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(color: shadowColor, radius: shadowRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Option \\(number), \\(title), \\(detail)")
    }

    private func styleCard(
        number: Int,
        choice: WebsiteStyleChoice,
        selected: Bool,
        focused: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let active = selected || focused
        let iconBackground: Color = active ? .white.opacity(0.15) : .white.opacity(0.07)
        let iconColor: Color = active ? .white : .purple

        let fillColor: Color
        if selected {
            fillColor = .purple.opacity(0.18)
        } else if focused {
            fillColor = .purple.opacity(0.12)
        } else {
            fillColor = .white.opacity(0.045)
        }

        let strokeColor: Color = active ? .purple.opacity(0.98) : .white.opacity(0.10)
        let strokeWidth: CGFloat = focused ? 2.2 : (selected ? 1.5 : 1.0)
        let shadowColor: Color = focused ? .purple.opacity(0.60) : .clear
        let shadowRadius: CGFloat = focused ? 24 : 0

        return Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(iconBackground)
                    Image(systemName: choice.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\\(number). \\(choice.title)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        if active {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.purple)
                        }
                    }
                    Text(choice.detail)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.52))
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(color: shadowColor, radius: shadowRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Style \\(number), \\(choice.title). \\(choice.detail)")
    }

'''

s = s[:start] + replacement + s[end:]
s = s.replace('name = proposed.prefix(1).uppercased() + proposed.dropFirst()',
              'name = proposed.prefix(1).uppercased() + String(proposed.dropFirst())')
p.write_text(s)
print('Simplified website choice/style cards for Swift compiler.')
