import SwiftUI

struct Wordmark: View {
    var size: CGFloat = 38
    var oneLine: Bool = false

    var body: some View {
        Group {
            if oneLine {
                HStack(spacing: 8) {
                    Text("LETTER").foregroundColor(Theme.cyanSoft)
                    Text("·").opacity(0.4)
                    Text("RAIDERS").foregroundColor(Theme.pinkSoft)
                }
            } else {
                VStack(spacing: 2) {
                    Text("LETTER").foregroundColor(Theme.cyanSoft)
                    Text("RAIDERS").foregroundColor(Theme.pinkSoft)
                }
            }
        }
        .font(AppFont.display(size, weight: .bold))
        .kerning(-size * 0.04)
        .lineSpacing(0)
        .shadow(color: Theme.pink.opacity(0.5), radius: 18)
        .shadow(color: Theme.violet.opacity(0.4), radius: 38)
    }
}
