//
//  AnimatedSplashView.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Fluid Liquid Intro Sequence with Slower 360° Orbital Leaf:
//  - White fluid stream forms "t" from left
//  - Mint green fluid stream forms "m" from right (no gap between t and m)
//  - Mint leaf performs a graceful, slow 360° circular orbit around logo assembly
//  - Leaf settles elegantly right above the t-m junction
//  - Subtle low-intensity mint background glow
//  - App name & subtitle fade in smoothly below
//  - Fast window fade out revealing home screen
//

import SwiftUI

struct AnimatedSplashView: View {
    
    var isQuickMode: Bool = false
    var onFinish: () -> Void
    
    // Fluid Stream & Motion States
    @State private var tOffsetX: CGFloat = -320
    @State private var mOffsetX: CGFloat = 320
    
    @State private var tFluidWidth: CGFloat = 220
    @State private var mFluidWidth: CGFloat = 220
    @State private var fluidOpacity: Double = 0.85
    
    // Slower 360° Orbital Leaf Animation States
    @State private var isOrbiting: Bool = false
    @State private var orbitDegrees: Double = 0.0
    @State private var leafScale: CGFloat = 0.0
    @State private var leafOpacity: Double = 0.0
    
    // Subtle Low-Intensity Mint Glow
    @State private var glowOpacity: Double = 0.0
    @State private var glowScale: CGFloat = 0.6
    
    @State private var textOpacity: Double = 0.0
    @State private var textOffsetY: CGFloat = 20
    
    @State private var containerOpacity: Double = 1.0
    
    var body: some View {
        ZStack {
            // Deep Navy Background (#0F1115 / #0D1117)
            Color(hex: "0F1115")
                .edgesIgnoringSafeArea(.all)
            
            // Subtle Low-Intensity Mint Glow Backdrop
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color(hex: "10B981").opacity(0.18), Color(hex: "34D399").opacity(0.05), Color.clear]),
                        center: .center,
                        startRadius: 5,
                        endRadius: 200
                    )
                )
                .frame(width: 420, height: 420)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
            
            VStack(spacing: 36) {
                // Fluid Standalone "tm" Wordmark Assembly (No space between t and m)
                ZStack {
                    // White Milk-like Fluid Trail from Left
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.0), Color.white.opacity(0.85), Color.white]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: tFluidWidth, height: 16)
                        .blur(radius: 5)
                        .opacity(fluidOpacity)
                        .offset(x: tOffsetX - 50, y: 26)
                    
                    // Mint Green Fluid Trail from Right
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "10B981").opacity(0.0), Color(hex: "34D399").opacity(0.85), Color(hex: "10B981")]),
                                startPoint: .trailing,
                                endPoint: .leading
                            )
                        )
                        .frame(width: mFluidWidth, height: 16)
                        .blur(radius: 5)
                        .opacity(fluidOpacity)
                        .offset(x: mOffsetX + 50, y: 26)
                    
                    // Core Standalone Wordmark Assembly ("t" and "m" tightly touching)
                    HStack(spacing: -2) {
                        Text("t")
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.white.opacity(0.35), radius: 12, x: 0, y: 3)
                            .offset(x: tOffsetX)
                        
                        Text("m")
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "10B981"))
                            .shadow(color: Color(hex: "10B981").opacity(0.45), radius: 14, x: 0, y: 3)
                            .offset(x: mOffsetX)
                    }
                    
                    // Mint Leaf Orbiting 360° Slower Around Logo & Settling Above Junction
                    ZStack {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "34D399"))
                            .shadow(color: Color(hex: "34D399").opacity(0.8), radius: 8)
                            .scaleEffect(leafScale)
                            .opacity(leafOpacity)
                            // When orbiting: 105pt radius. When settled: hovering right above the t-m junction!
                            .offset(x: isOrbiting ? 0 : 0, y: isOrbiting ? -105 : -48)
                    }
                    .rotationEffect(.degrees(isOrbiting ? orbitDegrees : 0))
                }
                
                // TrackMint App Title & Subtitle (Fading in smoothly below)
                VStack(spacing: 8) {
                    Text("TrackMint")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.6)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Text("SMART EXPENSE TRACKING")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "94A3B8"))
                        .tracking(3.5)
                }
                .offset(y: textOffsetY)
                .opacity(textOpacity)
            }
        }
        .opacity(containerOpacity)
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        if isQuickMode {
            // Quick 0.35s mode for repeat opens
            withAnimation(.easeInOut(duration: 0.25)) {
                tOffsetX = 0
                mOffsetX = 0
                tFluidWidth = 0
                mFluidWidth = 0
                fluidOpacity = 0.0
                isOrbiting = false
                orbitDegrees = 0
                leafScale = 1.0
                leafOpacity = 1.0
                glowOpacity = 0.3
                glowScale = 1.0
                textOpacity = 1.0
                textOffsetY = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    containerOpacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onFinish()
                }
            }
            return
        }
        
        // ── FLUID LIQUID INTRO SEQUENCE WITH SLOWER 360° ORBITAL LEAF ──
        
        // 1. White fluid "t" (left) & Green fluid "m" (right) glide smoothly to center
        withAnimation(.interactiveSpring(response: 0.55, dampingFraction: 0.72, blendDuration: 0)) {
            tOffsetX = 0
            mOffsetX = 0
        }
        
        // 2. Fluid trails dissolve as letters form logo mark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.easeOut(duration: 0.32)) {
                tFluidWidth = 0
                mFluidWidth = 0
                fluidOpacity = 0.0
            }
        }
        
        // 3. Subtle low-intensity mint glow appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.6)) {
                glowOpacity = 0.3
                glowScale = 1.1
            }
        }
        
        // 4. Leaf appears & executes a smooth, SLOWER 360-degree circular orbit (1.85s duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            isOrbiting = true
            leafScale = 1.0
            withAnimation(.easeIn(duration: 0.2)) {
                leafOpacity = 1.0
            }
            
            // Full 360° rotation around the logo at a graceful, slower pace (1.85s)
            withAnimation(.easeInOut(duration: 1.85)) {
                orbitDegrees = 360
            }
            
            // 5. Leaf glides smoothly into final resting spot above the t-m junction
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.88) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    isOrbiting = false
                    orbitDegrees = 0
                }
            }
        }
        
        // 6. TrackMint App Title & Subtitle Fade In smoothly underneath
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.45)) {
                textOpacity = 1.0
                textOffsetY = 0
            }
        }
        
        // 7. Extended Hold (~4.2s delay) before Fast Window Fade Out
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                containerOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onFinish()
            }
        }
    }
}
