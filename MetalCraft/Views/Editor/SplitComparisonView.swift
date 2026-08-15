//
//  SplitComparisonView.swift
//  MetalCraft
//
//  Interactive split before/after viewer with draggable vertical divider.
//

import SwiftUI

struct SplitComparisonView: View {
    let originalImage: UIImage
    let processedImage: UIImage
    @Binding var splitPosition: CGFloat // 0.0 to 1.0
    
    @State private var dragOffset: CGFloat = 0.0
    
    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let totalHeight = geo.size.height
            let currentX = max(10, min(totalWidth - 10, (splitPosition * totalWidth) + dragOffset))
            
            ZStack(alignment: .leading) {
                // Right Layer: Processed image (full)
                Image(uiImage: processedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: totalWidth, height: totalHeight)
                
                // Left Layer: Original image (masked/clipped to divider position)
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: totalWidth, height: totalHeight)
                    .mask(
                        Rectangle()
                            .frame(width: currentX, height: totalHeight)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    )
                
                // Vertical Divider Line
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 3)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 0)
                    .position(x: currentX, y: totalHeight / 2)
                
                // Center Drag Handle Knob
                Circle()
                    .fill(Color.white)
                    .frame(width: 34, height: 34)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 1)
                    .overlay {
                        Image(systemName: "chevron.left.and.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                    }
                    .position(x: currentX, y: totalHeight / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let newPosition = ((splitPosition * totalWidth) + value.translation.width) / totalWidth
                                splitPosition = max(0.05, min(0.95, newPosition))
                                dragOffset = 0.0
                            }
                    )
                
                // Labels
                VStack {
                    HStack {
                        Text("ORIGINAL")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.leading, 12)
                            .opacity(currentX > 80 ? 1 : 0)
                        
                        Spacer()
                        
                        Text("PROCESSED")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.trailing, 12)
                            .opacity((totalWidth - currentX) > 80 ? 1 : 0)
                    }
                    .padding(.top, 12)
                    Spacer()
                }
            }
            .frame(width: totalWidth, height: totalHeight)
        }
    }
}
