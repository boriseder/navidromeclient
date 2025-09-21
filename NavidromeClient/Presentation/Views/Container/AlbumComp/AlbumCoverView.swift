//
//  AlbumCoverView.swift
//  NavidromeClient
//
//  Created by Boris Eder on 21.09.25.
//
import SwiftUI

struct AlbumCoverView: View {
    let cover: UIImage?
    
    var body: some View {
        Group {
            if let cover = cover {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
                    .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
                    .clipShape(RoundedRectangle(cornerRadius: DSCorners.tight))
            } else {
                RoundedRectangle(cornerRadius: DSCorners.tight)
                    .fill(DSColor.surface)
                    .frame(width: DSLayout.cardCover, height: DSLayout.cardCover)
                    .overlay(
                        Image(systemName: "record.circle.fill")
                            .font(.system(size: DSLayout.largeIcon))
                            .foregroundStyle(DSColor.tertiary)
                    )

            }
        }
    }
}
