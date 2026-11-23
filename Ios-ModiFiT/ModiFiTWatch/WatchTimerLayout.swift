import SwiftUI

/// Gives the artwork the space left by the header and the timer controls.
struct WatchTimerLayout: Layout {
    private let spacing: CGFloat = 4
    private let minimumMascotHeight: CGFloat = 28
    private let maximumMascotHeight: CGFloat = 110

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = rowSizes(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? max(sizes.header.width, sizes.footer.width),
                      height: sizes.totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = rowSizes(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        let center = bounds.midX
        subviews[0].place(at: CGPoint(x: center, y: bounds.minY), anchor: .top,
                          proposal: ProposedViewSize(width: bounds.width, height: sizes.header.height))
        subviews[1].place(at: CGPoint(x: center, y: bounds.minY + sizes.mascotTop), anchor: .top,
                          proposal: ProposedViewSize(width: bounds.width, height: sizes.mascotHeight))
        subviews[2].place(at: CGPoint(x: center, y: bounds.minY + sizes.footerTop), anchor: .top,
                          proposal: ProposedViewSize(width: bounds.width, height: sizes.footer.height))
    }

    private func rowSizes(proposal: ProposedViewSize, subviews: Subviews)
        -> (header: CGSize, footer: CGSize, mascotHeight: CGFloat, mascotTop: CGFloat,
            footerTop: CGFloat, totalHeight: CGFloat) {
        let textProposal = ProposedViewSize(width: proposal.width, height: nil)
        let header = subviews[0].sizeThatFits(textProposal)
        let footer = subviews[2].sizeThatFits(textProposal)
        let mascotTop = header.height > 0 ? header.height + spacing : 0
        let fixedHeight = mascotTop + spacing + footer.height
        let available = (proposal.height ?? fixedHeight + minimumMascotHeight) - fixedHeight
        let mascotHeight = min(max(available, minimumMascotHeight), maximumMascotHeight)
        let footerTop = mascotTop + mascotHeight + spacing
        return (header, footer, mascotHeight, mascotTop, footerTop, footerTop + footer.height)
    }
}
