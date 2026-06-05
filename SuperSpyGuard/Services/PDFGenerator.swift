import UIKit
import PDFKit

struct PDFGenerator {
    static func generate(session: ScanSession) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "スーパースパイガード",
            kCGPDFContextAuthor: "Super Spy Guard"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 40

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
                                              format: format)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            // Header
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .black),
                .foregroundColor: UIColor.systemGreen
            ]
            "🛡 スーパースパイガード スキャンレポート".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 36

            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let df = DateFormatter(); df.locale = Locale(identifier: "ja_JP"); df.dateStyle = .full; df.timeStyle = .medium
            "スキャン日時: \(df.string(from: session.date))".draw(at: CGPoint(x: margin, y: y), withAttributes: subAttrs)
            y += 18
            if !session.locationLabel.isEmpty {
                "場所: \(session.locationLabel)".draw(at: CGPoint(x: margin, y: y), withAttributes: subAttrs)
                y += 18
            }
            "総合脅威レベル: \(session.overallThreatLevel.label)".draw(at: CGPoint(x: margin, y: y), withAttributes: subAttrs)
            y += 28

            // Divider
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            UIColor.systemGreen.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 1
            path.stroke()
            y += 16

            // Items
            let itemTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let itemDetailAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]

            if session.items.isEmpty {
                "✅ 不審なデバイス・信号は検出されませんでした".draw(at: CGPoint(x: margin, y: y), withAttributes: itemTitleAttrs)
            } else {
                "検出項目 (\(session.items.count)件)".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
                y += 24
                for item in session.items {
                    if y > pageHeight - 80 { ctx.beginPage(); y = margin }
                    let icon = item.threatLevel == .high ? "🔴" : item.threatLevel == .medium ? "🟡" : "🟢"
                    "\(icon) [\(item.phase.name)] \(item.name)".draw(at: CGPoint(x: margin, y: y), withAttributes: itemTitleAttrs)
                    y += 18
                    item.detail.draw(at: CGPoint(x: margin + 16, y: y), withAttributes: itemDetailAttrs)
                    y += 22
                }
            }

            y += 20
            "このレポートはスーパースパイガードが自動生成しました。医療・法的診断ではありません。".draw(
                at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 9),
                    .foregroundColor: UIColor.lightGray
                ])
        }
    }
}
