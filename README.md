# TranslateTool

一個 macOS 浮動翻譯小工具（SwiftUI + Ollama）。

按快捷鍵叫出視窗，輸入中文或英文後按 `Enter`，自動偵測語言方向並翻譯。

## Features

- Liquid Glass 風格的透明小工具視窗
- 全域快捷鍵呼叫/隱藏
- `Enter` 送出翻譯、`Shift + Enter` 換行
- 自動語言偵測
  - 含中文：`中文 -> 英文`
  - 否則：`英文 -> 繁中`
- 自動檢查 Ollama 執行環境
  - 檢查是否有 `ollama`
  - 若 server 未啟動，自動啟動 `ollama serve`
  - 若模型不存在，自動 `ollama pull`

## Default Settings

- Default model: `translategemma:latest`
- Default server: `http://127.0.0.1:11434`

## Keyboard Shortcuts

- `⌘ + ⌥ + T`: 顯示 / 隱藏翻譯工具
- `⌘ + ⌥ + Q`: 結束 App

## Requirements

- macOS
- Xcode（可編譯 SwiftUI macOS App）
- Ollama（若未安裝會在 App 內提示）

## Run Locally

1. 開啟專案：
   - `TranslateTool.xcodeproj`
2. 使用 Xcode Run（`⌘R`）啟動 App
3. 按 `⌘ + ⌥ + T` 叫出工具視窗
4. 輸入文字後按 `Enter` 翻譯

## Project Structure

- `TranslateTool/ContentView.swift`
  - UI、Enter 送出、IME 組字處理（避免 placeholder 重疊）
- `TranslateTool/TranslationViewModel.swift`
  - 狀態管理與翻譯流程
- `TranslateTool/OllamaService.swift`
  - Ollama API 呼叫與翻譯 prompt
- `TranslateTool/OllamaRuntimeManager.swift`
  - Ollama 安裝/啟動/模型下載檢查
- `TranslateTool/TranslateToolApp.swift`
  - 浮動視窗、全域快捷鍵、app lifecycle

## Notes

- 本工具是桌面浮動小視窗設計，視窗按鈕（紅黃綠）已隱藏。
- 若你要改模型，請修改：
  - `TranslateTool/TranslationViewModel.swift` 內的 `modelName`
- 若你要改快捷鍵，請修改：
  - `TranslateTool/TranslateToolApp.swift` 內 `RegisterEventHotKey` 設定。


