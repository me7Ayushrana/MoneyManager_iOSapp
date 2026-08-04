//
//  SparklineView.swift
//  MoneyManager
//
//  Smooth Bezier curve graph for the Hero Balance card & summary cards.
//  Includes HeroSparklineGraphView with glowing endpoint, tooltip, and interactive drag gesture.
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
                                colors: [lineColor.opacity(0.25), lineColor.opacity(0.0)],
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

// MARK: - Premium Hero Sparkline Graph View with Glowing Endpoint & Tooltip

struct HeroSparklineGraphView: View {
    var points: [CGFloat] = [18, 28, 22, 36, 26, 44, 34, 52, 42, 60]
    var tooltipValue: String = "₹5,970.50"
    var dateLabels: [String] = ["1 Aug", "8 Aug", "15 Aug", "22 Aug", "31 Aug"]
    
    @State private var drawProgress: CGFloat = 0
    @State private var selectedIndex: Int? = nil
    @State private var isDragging: Bool = false
    
    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height - 30 // reserve space for tooltip
                let graphPoints = getComputedPoints(size: CGSize(width: width, height: height))
                let activeIdx = selectedIndex ?? (graphPoints.count - 1)
                let activePoint = graphPoints.indices.contains(activeIdx) ? graphPoints[activeIdx] : (graphPoints.last ?? .zero)
                
                ZStack(alignment: .topLeading) {
                    // Soft White Bezier Line with Glow
                    bezierPath(points: graphPoints)
                        .trim(from: 0, to: drawProgress)
                        .stroke(
                            Color.white.opacity(0.8),
                            style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color.white.opacity(0.6), radius: 5, x: 0, y: 0)
                    
                    // Glowing Endpoint Dot
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 20, height: 20)
                            .blur(radius: 3)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 9, height: 9)
                            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .position(x: activePoint.x, y: activePoint.y + 30) // shifted down to match frame
                    .opacity(drawProgress > 0.8 ? 1.0 : 0.0)
                    
                    // Floating Tooltip Badge above Endpoint
                    VStack(spacing: 0) {
                        Text(tooltipValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color(hex: "060B18").opacity(0.92))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
                        
                        // Downward Pointer Triangle
                        TrianglePointer()
                            .fill(Color(hex: "060B18").opacity(0.92))
                            .frame(width: 7, height: 4)
                    }
                    .position(x: min(max(activePoint.x, 45), width - 45), y: max(activePoint.y, 16))
                    .opacity(drawProgress > 0.9 ? 1.0 : 0.0)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isDragging = true
                            let stepX = width / CGFloat(max(graphPoints.count - 1, 1))
                            let idx = Int((val.location.x / stepX).rounded())
                            let clampedIdx = min(max(idx, 0), graphPoints.count - 1)
                            withAnimation(.interactiveSpring()) {
                                selectedIndex = clampedIdx
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isDragging = false
                                selectedIndex = nil
                            }
                        }
                )
            }
            .frame(height: 75)
            
            // X-Axis Date Labels along bottom of card
            HStack {
                ForEach(dateLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))
                    if label != dateLabels.last {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                drawProgress = 1.0
            }
        }
    }
    
    private func getComputedPoints(size: CGSize) -> [CGPoint] {
        guard points.count > 1 else { return [] }
        let minVal = points.min() ?? 0
        let maxVal = points.max() ?? 1
        let range = max(maxVal - minVal, 1)
        let stepX = size.width / CGFloat(points.count - 1)
        
        return points.enumerated().map { (i, val) in
            CGPoint(
                x: CGFloat(i) * stepX,
                y: size.height - ((val - minVal) / range * (size.height - 10) + 5)
            )
        }
    }
    
    private func bezierPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        let stepX = points.count > 1 ? (points[1].x - points[0].x) : 0
        
        path.move(to: CGPoint(x: points[0].x, y: points[0].y + 30))
        for i in 1..<points.count {
            let pt = CGPoint(x: points[i].x, y: points[i].y + 30)
            let prevPt = CGPoint(x: points[i - 1].x, y: points[i - 1].y + 30)
            let control1 = CGPoint(x: prevPt.x + stepX / 2, y: prevPt.y)
            let control2 = CGPoint(x: pt.x - stepX / 2, y: pt.y)
            path.addCurve(to: pt, control1: control1, control2: control2)
        }
        return path
    }
}

struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
