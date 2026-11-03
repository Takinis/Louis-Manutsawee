# Speech Completion

检查并补全 Manutsawee 和 Kiritzuka 的台词。只读取指定的本地游戏脚本，不联网，不执行 Lua 文件，也不会自动采用威尔逊的台词。

需要 Node.js 20 或更新版本。以下命令在模组根目录执行。

## 安装

```sh
npm ci --prefix tools/speech
```

依赖版本由 `package-lock.json` 固定。安装依赖需要网络，检查与导入不需要网络。

## 使用

游戏更新后，先将新的游戏脚本解包到本地目录，再导出补写清单：

```sh
node tools/speech/cli.cjs scan \
    --source "/Users/sydney/Desktop/scripts" \
    --output "/tmp/speech-draft.json"
```

`--source` 必须包含 `speech_wilson.lua`。如果同时存在 `languages/chinese_s.po`，清单会包含对应的原版中文参考。

清单只允许编辑 `text` 和 `translation`：

- `text` 填角色英文台词，`translation` 填对应的简体中文。繁体中文 `scripts/languages/chinese_t.po` 由简体生成，改完简体后运行 `python3 tools/speech/sync_traditional.py`（需要 `pip install opencc-python-reimplemented`）。台湾用语替换表也在这个脚本里，不要直接改生成结果。
- `reference` 和 `referenceTranslation` 只用于理解触发情境。
- `reason: "catalog"` 表示已有台词的翻译或 POT 需要同步，保留 `text`，填写 `translation`。
- `previousText` 和 `previousTranslation` 保留旧翻译记录，供复核时参考，不要修改。
- 保留 `%s`、`%d`、`{winner}` 等占位符；位置型格式占位符的顺序也须保持。
- 暂时不补的条目保持空白。新英文台词有内容时，必须同时填写中文翻译。
- 不要删除条目、修改路径或改动清单中的校验值。

工具拒绝覆盖已存在的清单。再次扫描时使用新的输出文件名，避免丢失已经填写的内容。

预览变更：

```sh
node tools/speech/cli.cjs apply --input "/tmp/speech-draft.json"
```

确认后写入：

```sh
node tools/speech/cli.cjs apply --input "/tmp/speech-draft.json" --write
```

写入后重新检查：

```sh
node tools/speech/cli.cjs check --source "/Users/sydney/Desktop/scripts"
```

只检查一个角色时，添加 `--character manutsawee` 或 `--character kiritzuka`。默认处理两位角色。

## 检查范围

- `check` 还会全量对照 `strings/` 与 PO/POT：英文改了但翻译没跟上（`STALE`）、缺条目（`MISSING`）、多余条目（`EXTRA`）、占位符不一致（`PLACEHOLDER`）、繁体未同步（`UNSYNCED`）。
- 缺失台词、空白台词以及误用的 `only_used_by_*` 占位文本。
- 原版从单句改成多状态表的条目：保留旧句到 `GENERIC`，同步迁移 PO/POT 键。
- 随机台词数组按下标补齐，保留角色已有的额外台词，不重复追加。
- 已有英文台词对应的中文翻译和 POT 是否缺失或过期。
- Lua 重复键、PO 重复上下文、无法自动迁移的类型冲突。

原版其他角色专用的 `only_used_by_*` 项不要求补写。单句无法迁移到 `GENERIC` 时会报告冲突，需要检查后手动调整角色文件并重新扫描。

## 文件保护

导入默认只预览。写入前会重新校验清单对应的游戏脚本、角色台词及翻译文件；任何文件发生变化，都需要重新扫描，并将已填写的台词核对后转入新清单。

工具不替换现有非空台词，保留未修改的源代码、注释和翻译条目。紧凑单行 Lua 表需要插入新键时，会展开为多行；新数组项使用显式数字下标。可处理的 Lua 文件必须只包含返回字面量表的语句。复杂内联布局会在预览阶段报错，需先调整为每个字段独占一行。

写入前的原文件保存在：

```text
tools/speech/backups/<timestamp>/strings/...
tools/speech/backups/<timestamp>/scripts/languages/...
```

工具不会自动清理备份。多个文件的替换不构成一个原子事务；若磁盘写入或重命名失败，应检查报错中的备份目录、目标文件及 `.speech-*.tmp` 临时文件，再决定恢复哪些文件。不要在导入期间同时编辑目标文件。

`check` 的退出码：`0` 表示检查通过，`1` 表示仍有待补条目或类型迁移，`2` 表示参数、文件或解析错误。`apply` 支持部分导入，因此成功后仍应执行 `check`。

## 测试

```sh
npm test --prefix tools/speech
lua tests/speech_coverage.lua "/Users/sydney/Desktop/scripts"
```

测试使用系统临时目录保留独立测试文件，不修改实际角色台词，也不自动删除目录。
