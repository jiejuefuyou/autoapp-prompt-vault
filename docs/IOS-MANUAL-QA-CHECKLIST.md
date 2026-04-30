# iOS Manual QA Checklist — PromptVault before TestFlight

> **目的**: Apple Developer 邮件到达后，CC 在 macOS 跑 TestFlight build 前必须人工跑这套清单一遍。
> **环境**: macOS 14+ + Xcode 16 + iPhone 15+ 真机 / iPhone 16 Pro Simulator。
> **耗时**: 25-35 min 全跑完。
> **失败处理**: 任何 ❌ 都阻止上传 TestFlight，先 fix 再走。

---

## 0. 预检 (build 之前 5 min)

```bash
cd repos/autoapp-prompt-vault

# 1. starter_prompts 必须最新
node scripts/sync_starter_prompts.js --check
# expected: ✅ in sync (160 prompts)

# 2. project.yml 关键字段
grep -E "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption|MARKETING_VERSION|CURRENT_PROJECT_VERSION" project.yml

# 3. fastlane metadata 完整性
ls fastlane/metadata/en-US/ fastlane/metadata/zh-Hans/

# 4. Privacy Manifest
test -f PromptVault/Resources/PrivacyInfo.xcprivacy && echo OK
```

预期全 ✅ 才进 1。

---

## 1. Build & Launch (5 min)

```bash
xcodegen generate    # 重生 .xcodeproj
xcodebuild -scheme PromptVault -destination 'platform=iOS Simulator,name=iPhone 16 Pro' clean build
```

- [ ] 编译 0 warning（Swift 6 strict concurrency 模式）
- [ ] App icon 在 Simulator Home 屏正确显示（紫色 `{{ }}` + sparkle）
- [ ] 冷启动 < 1.5 秒（从黑屏到第 1 条 prompt 渲染）
- [ ] 启动后无 crash（前 30 秒在 App 内随机点 10 次）

---

## 2. First-Launch QuickTour (5 min)

> 只在首次启动看到。退出 App 重装才会再触发。

- [ ] Step 1 出现：「pick a prompt」展示一条样例 prompt 卡片
- [ ] Step 2 出现：「fill the variable」让用户在 `{{text}}` 占位上输入"Hello"
- [ ] Step 3 出现：「copy & paste」点了 Copy 后剪贴板真有内容（切到备忘录粘贴验证）
- [ ] Step 3 完成后 QuickTour 消失，进入主列表
- [ ] 关闭 App 重打开 → QuickTour **不再出现**（不烦用户）

**Critical**: 这是 conversion 决定性 30 秒。崩溃 / 卡顿 / 文字看不懂 = 立即流失。

---

## 3. Prompt Browse + Search (5 min)

- [ ] 主列表显示 **160 条** prompts（不是 113）。打开 settings 或 about 页有 count 字样的话也得是 160。
- [ ] 滑到底，最后 1 条标题不是 placeholder（应该是真 prompt 例如 "AI 副业 ROI 评估" 或类似 2026 加的）
- [ ] 搜索框输 "Sora" → 至少 4 条结果（Sora 2 商用 / Runway / Pika / Veo 等）
- [ ] 搜索框输 "MCP" → 至少 1 条结果（"MCP server 完整骨架"）
- [ ] 搜索框输 "翻译" → 至少 3 条结果
- [ ] 清空搜索框 → 列表恢复 160 条

---

## 4. Detail + Variable Fill (5 min)

- [ ] 点任意 prompt 进 detail：title / body / tags 都正确显示
- [ ] body 中含 `{{variable}}` 的 prompt（例如 "Translate to natural English"）：
  - [ ] 检测到至少 1 个 variable，UI 显示输入框
  - [ ] 输入文本后点 Copy，**剪贴板内容里 `{{text}}` 已被替换**
  - [ ] 不填 variable 直接 Copy → 弹提示"还有变量未填" 或允许 copy 但保留原 placeholder（看产品决策，确认行为是 expected 即可）
- [ ] 中文 prompt detail（例如 "本地部署大模型选型"）显示正常，无乱码
- [ ] 含中文 tag（"翻译" / "本地部署"）显示正常

---

## 5. IAP / Premium Lock (5 min)

> Free tier 看 `freePromptLimit` 条；premium 解锁全 160。

- [ ] 第一次启动是 free tier，列表能看的 prompt 数 = `freePromptLimit`（看代码默认值，通常 30-50）
- [ ] 滑到 free 边界后看到 paywall card
- [ ] 点 "Unlock" 触发 StoreKit purchase flow（Sandbox 账号测）
- [ ] Sandbox 购买成功 → paywall 消失 → 立即解锁全 160
- [ ] Restore Purchases 按钮在 settings 可点，多次点不重复扣费

⚠️ **如果 IAP 流程任何一步失败**：app 会因为 Apple 审核 IAP guideline 被拒。**必须在 TestFlight 前修**。

---

## 6. Review Prompt Trigger (3 min)

- [ ] App 内做 5+ 次成功"Copy prompt to clipboard"操作
- [ ] 第 5 次后下次启动 / 切前台时弹出 SKStoreReviewController（系统星评弹窗）
- [ ] 弹完后在 settings 找"Rate the App"按钮也能再触发（链到 App Store review 页）

---

## 7. Privacy / Crash Sanity (3 min)

- [ ] Settings → Privacy 页能打开，列出 No Tracking / Local-only 等条款
- [ ] 触发以下 5 个常见 crash 路径，全部不 crash：
  - 输入超长 variable（5000+ 字符）
  - prompt body 为空（debugger 注入空 body）
  - tags 为空数组
  - 同时复制 50 条 prompt（连续点 Copy）
  - 网络断开下启动（应该正常，因为是 local-only）

---

## 8. ASC Metadata Final Check (3 min)

提交 ASC 前最后一遍：

- [ ] App Name: `PromptVault — AI Prompt Library`（或最新版）
- [ ] Subtitle: ≤ 30 字
- [ ] Description: ≤ 4000 字，**含 160 prompts** 数字（不是 113）
- [ ] Keywords: ≤ 100 字，无超限（跑 `bash scripts/lint-metadata.sh`）
- [ ] Promotional Text: ≤ 170 字
- [ ] Screenshots: 6 张 + 描述准确
- [ ] What's New (release notes): 提到 "160 prompts" + 哪些类别新增
- [ ] Support URL: GitHub Pages 链接活的（curl 200）
- [ ] Privacy Policy URL: 同上

---

## 失败 → 阻塞 → 修复路径

| 失败位置 | 阻塞 | 应对 |
|---|---|---|
| 0 预检 ❌ | 0% 进度 | 跑 sync 脚本 / 检 metadata |
| 1 build ❌ | 0% 进度 | 看 xcodebuild log，多半是 project.yml 或 SPM 同步 |
| 2 QuickTour ❌ | TestFlight 阻塞 | 这是 conversion 决定性，必修 |
| 3-4 列表/搜索 ❌ | 高优先级 | 数据 / 索引问题 |
| 5 IAP ❌ | App Store 审核必拒 | 必修 |
| 6 review ⚠️ | 低优 | 可 v1.1 修 |
| 7 crash ❌ | TestFlight 阻塞 | 必修 |
| 8 metadata ❌ | ASC 阻塞 | 必修 |

---

## 全 ✅ 后下一步

```bash
# 推 v0.1.0 tag → testflight.yml workflow 自动跑
git tag v0.1.0 && git push origin v0.1.0
```

testflight.yml 会：
1. fastlane match 取 cert
2. xcodebuild archive
3. xcrun altool / fastlane pilot 上传 TestFlight
4. ASC 处理 ~15 min → external testers 收到推送

---

_v1 · 2026-05-01 · 跑这套清单 + 真机过一遍 = 25-35 min 投入换"绝对不会过审被拒"安心_
