//
//  SparklineView.swift
//  MoneyManager
//
//  Smooth Bezier curve graph for the Hero Balance card & summary cards.
//  Renders a thin stroke line with ambient gradient fill.
//

import SwiftUI

struct SparklineView: View {
    var points: [CGFloat] = [20, 35, 25, 45, 30, 55, 40, 65, 50, 80]
    var lineColor: Color = .white
    var showGradientFill: Bool = true
    
    @State private var drawPercentage: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let path = bezierPath(in: geo.size)
            
            ZStack {
                if showGradientFill {
                    let fillPath = closedBezierPath(in: geo.size)
                    fillPath
                        .fill(
                            LinearGradient(
                                colors: [lineColor.opacity(0.35), lineColor.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                path
                    .trim(from: 0, to: drawPercentage)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                drawPercentage = 1.0
            }
        }
    }
    
    private func bezierPath(in size: CGSize) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        
        let minVal = points.min() ?? 0
        let maxVal = points.max() ?? 1
        let range = max(maxVal - minVal, 1)
        
        let stepX = size.width / CGFloat(points.count - 1)
        
        let p0 = CGPoint(
            x: 0,
            y: size.height - ((points[0] - minVal) / range * (size.height - 8) + 4)
        )
        path.move(to: p0)
        
        for i in 1..<points.count {
            let pt = CGPoint(
                x: CGFloat(i) * stepX,
                y: size.height - ((points[i] - minVal) / range * (size.height - 8) + 4)
            )
            let prevPt = CGPoint(
                x: CGFloat(i - 1) * stepX,
                y: size.height - ((points[i - 1] - minVal) / range * (size.height - 8) + 4)
            )
            
            let control1 = CGPoint(x: prevPt.x + stepX / 2, y: prevPt.y)
            let control2 = CGPoint(x: pt.x - stepX / 2, y: pt.y)
            
            path.addCurve(to: pt, control1: control1, control2: control2)
        }
        
        return path
    }
    
    private func closedBezierPath(in size: CGSize) -> Path {
        var path = bezierPath(in: size)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}
