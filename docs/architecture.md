# marker-swift 架構設計

## 概述

marker-swift 是一個 Swift 套件，用於產生 marker 格式的輸出：Markdown 文件 + JSON 元數據 + 圖片檔案。設計重點在於**可插拔的圖片分類架構**，讓使用者可以整合自己的 OCR/公式辨識模型。

---

## 設計原則

### 1. 延續 Functional Correspondence

來自 macdoc 的核心設計：

```
convert(doc) = for e in extract(doc): emit(f(e))
```

marker-swift 擴展這個模式：

```
convert(doc) =
  for e in extract(doc):
    if isImage(e):
      result = classifier.classify(e)  // 可插拔
      emit(f(result))
    else:
      emit(f(e))
```

### 2. Protocol-Oriented Design

使用協定（Protocol）實現可插拔架構：

```swift
public protocol ImageClassifier {
    func classify(_ image: Data) async throws -> ImageClassification
    func convertToLatex(_ image: Data) async throws -> String
}
```

好處：
- **本地優先**：預設使用本地模型，不需要 API key
- **可替換**：可以輕鬆切換不同的分類器實作
- **測試友好**：可以用 mock 實作進行測試

### 3. Streaming-Compatible

雖然 marker-swift 需要管理檔案輸出，但仍保持與 streaming 架構的相容性：
- 內容可以逐步寫入
- 元數據在最後一次性生成
- 記憶體使用與文件大小無關

---

## 架構圖

```
┌─────────────────────────────────────────────────────────────────────┐
│                           使用者程式碼                               │
│                                                                     │
│   let writer = MarkerWriter(classifier: SuryaClassifier())          │
│   try writer.heading("Title", level: 1)                             │
│   try await writer.image(data: imageData, ...)                      │
│   try writer.finalize()                                             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        MarkerWriter                                  │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                     主要協調者                                │    │
│  │  - 接收內容元素                                               │    │
│  │  - 協調各元件                                                 │    │
│  │  - 追蹤文件狀態                                               │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                             │                                        │
│         ┌───────────────────┼───────────────────┐                   │
│         ▼                   ▼                   ▼                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐         │
│  │MarkdownSwift│    │ImageManager │    │ImageClassifier  │         │
│  │  (依賴)     │    │             │    │    (協定)       │         │
│  │             │    │ - 儲存圖片  │    │                 │         │
│  │ - 格式化 MD │    │ - 產生 ID   │    │ - classify()   │         │
│  │ - 跳脫處理  │    │ - 追蹤元數據│    │ - convertToLatex│         │
│  └─────────────┘    └─────────────┘    └────────┬────────┘         │
│                                                  │                  │
│                                        ┌─────────┴─────────┐        │
│                                        ▼                   ▼        │
│                                ┌─────────────┐    ┌─────────────┐  │
│                                │Passthrough  │    │ SuryaSwift  │  │
│                                │ Classifier  │    │ (使用者實作) │  │
│                                │  (預設)     │    │             │  │
│                                └─────────────┘    └─────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          輸出檔案                                    │
│                                                                     │
│   output/                                                           │
│   ├── document.md           # Markdown 內容                         │
│   ├── document_meta.json    # 元數據 (JSON)                         │
│   └── images/                                                       │
│       ├── _image_001.png                                            │
│       └── _image_002.jpeg                                           │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 元件說明

### MarkerWriter

主要 API，協調所有元件：

```swift
public class MarkerWriter {
    // 依賴
    let classifier: any ImageClassifier
    var imageManager: ImageManager
    var mdWriter: MarkdownWriter<StringOutput>

    // 狀態追蹤
    var tocEntries: [TOCEntry]
    var paragraphIndex: Int

    // 區塊元素
    func heading(_ text: String, level: Int) throws
    func paragraph(_ text: String) throws
    func table(headers: [String], rows: [[String]]) throws

    // 圖片處理 (async)
    func image(data: Data, originalName: String) async throws -> ImageResult

    // 輸出
    func finalize() throws -> MarkerOutputFiles
}
```

### ImageClassifier (協定)

定義圖片分類介面：

```swift
public protocol ImageClassifier: Sendable {
    /// 判斷圖片是數學公式還是一般圖片
    func classify(_ image: Data) async throws -> ImageClassification

    /// 將數學公式圖片轉換為 LaTeX
    func convertToLatex(_ image: Data) async throws -> String
}

public enum ImageClassification {
    case mathFormula
    case regularImage(altText: String)
}
```

### PassthroughClassifier

預設實作，保留所有圖片：

```swift
public struct PassthroughClassifier: ImageClassifier {
    func classify(_ image: Data) async throws -> ImageClassification {
        return .regularImage(altText: "Image")
    }

    func convertToLatex(_ image: Data) async throws -> String {
        throw ImageClassifierError.latexConversionFailed("Not supported")
    }
}
```

### ImageManager

管理圖片檔案：

```swift
public struct ImageManager {
    // 產生唯一 ID
    func generateImageId(extension: String) -> String  // "_image_001.png"

    // 儲存圖片
    func saveImage(_ data: Data, id: String) throws -> String

    // 追蹤元數據
    func addMetadata(_ metadata: ImageMetadata)
    func getStatistics() -> ConversionStatistics

    // 偵測圖片格式
    static func detectImageFormat(_ data: Data) -> String
}
```

### MetadataWriter

產生 JSON 元數據：

```swift
public struct MetadataWriter {
    func encode(_ document: MarkerDocument) throws -> Data
    func write(_ document: MarkerDocument, to url: URL) throws
}
```

---

## 資料模型

### MarkerDocument

```swift
public struct MarkerDocument: Codable {
    let filename: String
    let convertedAt: Date
    let statistics: ConversionStatistics
    let images: [ImageMetadata]
    let tableOfContents: [TOCEntry]
}
```

### ImageMetadata

```swift
public struct ImageMetadata: Codable {
    let id: String              // "_image_001.png"
    let originalName: String    // 原始檔名
    let type: ImageType         // .regular 或 .mathFormula
    let convertedTo: String?    // LaTeX (僅公式)
    let position: ImagePosition // 段落位置
}
```

### ConversionStatistics

```swift
public struct ConversionStatistics: Codable {
    let totalImages: Int
    let convertedToLatex: Int
    let keptAsImages: Int
}
```

---

## JSON 輸出格式

```json
{
  "filename": "document.docx",
  "converted_at": "2025-01-14T12:00:00Z",
  "statistics": {
    "total_images": 5,
    "converted_to_latex": 3,
    "kept_as_images": 2
  },
  "images": [
    {
      "id": "_image_001.png",
      "original_name": "image1.png",
      "type": "regular",
      "position": { "paragraph": 3 }
    },
    {
      "id": "_image_002.png",
      "original_name": "formula.png",
      "type": "math_formula",
      "converted_to": "$\\int_0^\\infty e^{-x^2} dx$",
      "position": { "paragraph": 5 }
    }
  ],
  "table_of_contents": [
    { "title": "Introduction", "level": 1, "position": 0 },
    { "title": "Methods", "level": 2, "position": 10 }
  ]
}
```

---

## 依賴關係

```
marker-swift
    │
    └── markdown-swift (Markdown 語法生成)
            │
            └── 無外部依賴
```

### 未來整合

```
macdoc
├── ooxml-swift          # Word 文件解析
├── marker-swift         # Marker 格式輸出
│   └── markdown-swift   # Markdown 生成
└── SuryaSwift          # 本地 OCR/公式辨識 (使用者專案)
    └── 實作 ImageClassifier 協定
```

---

## 使用範例

### 基本用法（保留所有圖片）

```swift
import MarkerSwift

let writer = try MarkerWriter(
    outputDirectory: URL(fileURLWithPath: "output/"),
    filename: "document"
    // classifier 預設為 PassthroughClassifier
)

try writer.heading("My Document", level: 1)
try writer.paragraph("Some text content.")
try await writer.image(data: pngData, originalName: "photo.png")
try writer.finalize()

// 輸出:
// output/document.md
// output/document_meta.json
// output/images/_image_001.png
```

### 進階用法（整合 SuryaSwift）

```swift
import MarkerSwift
import SuryaSwift  // 你的專案

// 實作 ImageClassifier 協定
struct SuryaClassifier: ImageClassifier {
    let surya: SuryaModel
    let texify: TexifyModel

    func classify(_ image: Data) async throws -> ImageClassification {
        if await surya.isMathFormula(image) {
            return .mathFormula
        }
        let description = await surya.describeImage(image)
        return .regularImage(altText: description)
    }

    func convertToLatex(_ image: Data) async throws -> String {
        return await texify.convert(image)
    }
}

// 使用自定義分類器
let writer = try MarkerWriter(
    outputDirectory: URL(fileURLWithPath: "output/"),
    filename: "document",
    classifier: SuryaClassifier(surya: model, texify: texify)
)

// 數學公式圖片會被轉換為 LaTeX
try await writer.image(data: formulaImage, originalName: "eq1.png")
// 輸出: $\int_0^\infty e^{-x^2} dx$

// 一般圖片保留
try await writer.image(data: photoImage, originalName: "photo.png")
// 輸出: ![Photo description](images/_image_002.png)

try writer.finalize()
```

---

## 測試覆蓋

| 測試檔案 | 測試數量 | 覆蓋範圍 |
|----------|----------|----------|
| ImageClassificationTests | 6 | 分類邏輯、協定實作 |
| ImageManagerTests | 9 | 圖片格式偵測、ID 生成、統計 |
| MetadataWriterTests | 2 | JSON 編碼、snake_case 鍵值 |

執行測試：

```bash
cd marker-swift && swift test
# Executed 17 tests, with 0 failures
```

---

## 版本歷史

- **v0.1.0** (2025-01-14): 初始版本
  - ImageClassifier 協定
  - PassthroughClassifier 預設實作
  - MarkerWriter 主要 API
  - JSON 元數據輸出
