import SpatiaCore
import XCTest

final class FileCategoryTests: XCTestCase {
    func testClassifiesCommonExtensions() {
        XCTAssertEqual(category("clip.mov"), .video)
        XCTAssertEqual(category("photo.heic"), .image)
        XCTAssertEqual(category("track.mp3"), .audio)
        XCTAssertEqual(category("archive.zip"), .archive)
        XCTAssertEqual(category("main.swift"), .source)
        XCTAssertEqual(category("brief.pdf"), .document)
    }

    func testClassifiesUTTypeHints() {
        XCTAssertEqual(category("untitled", typeIdentifier: "public.jpeg"), .image)
        XCTAssertEqual(category("untitled", typeIdentifier: "public.mpeg-4"), .video)
        XCTAssertEqual(category("untitled", typeIdentifier: "public.mp3"), .audio)
    }

    func testClassifiesPackagesCachesAndSystemPaths() {
        XCTAssertEqual(
            FileCategoryClassifier.category(
                name: "Spatia.app",
                path: "/Applications/Spatia.app",
                kind: .package,
                typeIdentifier: nil
            ),
            .appPackage
        )

        XCTAssertEqual(
            FileCategoryClassifier.category(
                name: "com.example.cache",
                path: "/Users/me/Library/Caches/com.example.cache",
                kind: .directory,
                typeIdentifier: nil
            ),
            .cache
        )

        XCTAssertEqual(
            FileCategoryClassifier.category(
                name: "Library",
                path: "/Library",
                kind: .directory,
                typeIdentifier: nil
            ),
            .system
        )
    }

    private func category(_ name: String, typeIdentifier: String? = nil) -> FileCategory {
        FileCategoryClassifier.category(
            name: name,
            path: nil,
            kind: .file,
            typeIdentifier: typeIdentifier
        )
    }
}
