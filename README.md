# Louis Manutsawee（露易丝·曼莎薇）DST 角色模组 Wiki

> **Louis Manutsawee** 是一个《Don't Starve Together》角色模组，围绕自定义角色「露易丝·曼莎薇」、武士刀、剑术连段与 Mind Power（󰀈）资源展开。
>
> 本文档以 Wiki 方式整理模组内容，方便玩家、服务器管理员与后续维护者快速理解玩法、配置和代码结构。

---

## 目录

- [基本信息](#基本信息)
- [安装与依赖](#安装与依赖)
- [角色概览](#角色概览)
- [核心系统：Kenjutsu 剑术](#核心系统kenjutsu-剑术)
- [Mind Power（󰀈）系统](#mind-power-系统)
- [等级成长](#等级成长)
- [技能与按键](#技能与按键)
- [闪避与战斗手感](#闪避与战斗手感)
- [武器与装备](#武器与装备)
- [外观、皮肤与自定义](#外观皮肤与自定义)
- [模组配置项](#模组配置项)
- [目录结构](#目录结构)
- [开发者参考](#开发者参考)
- [兼容性与注意事项](#兼容性与注意事项)

---

## 基本信息

| 项目 | 内容 |
| --- | --- |
| 模组名称 | Louis Manutsawee / 露易丝 曼莎薇 |
| 类型 | Don't Starve Together 角色模组 |
| 当前版本 | 3.0 |
| 作者 | Sydney |
| API 版本 | DST `api_version = 10` |
| 联机要求 | 所有客户端都需要启用该模组 |
| 核心依赖 | Glassic API（`workshop-2521851770`） |
| 主要玩法 | 自定义角色、武士刀、Kenjutsu 剑术、Mind Power、等级成长、闪避、皮肤与发型自定义 |

---

## 安装与依赖

### 必需依赖

本模组依赖 **Glassic API**：

```lua
workshop-2521851770
```

如果依赖缺失，部分资源注册、皮肤系统、配方排序或其他工具接口可能无法正常工作。

### 推荐安装方式

1. 在 Steam 创意工坊订阅本模组。
2. 同时订阅并启用 **Glassic API**。
3. 创建或编辑服务器世界时，在服务器模组列表中启用本模组。
4. 进入角色选择界面，选择 **Louis Manutsawee / 露易丝 曼莎薇**。

### 开发环境安装

如果你正在本地开发：

1. 将仓库放入 DST 的 `mods/` 目录中。
2. 确保文件夹名在开发环境下可被 DST 识别。
3. 保留 `modinfo.lua`、`modmain.lua`、`scripts/`、`anim/`、`images/` 等资源目录。
4. 同步安装 Glassic API 的开发版或工坊版。

---

## 角色概览

Louis Manutsawee 是一个以剑术为核心的角色。她拥有比普通角色更偏技巧向的战斗节奏：先通过按键选择剑技，再通过攻击目标释放技能。

### 基础数值

| 属性 | 数值 |
| --- | ---: |
| 生命值 | 125 |
| 饥饿值 | 150 |
| 理智值 | 233 |
| 饥饿速度 | Wilson 的 1.3 倍 |
| 默认攻击倍率 | 1.0 |
| 默认工作效率 | 使用 Wes 的较低工作倍率，后续等级可改善 |

### 角色标签与特性

角色初始化时会获得多个玩法标签：

- `kenjutsuka`：剑术使用者，是技能系统识别角色的关键标签。
- `dodger`：允许使用闪避动作。
- `stronggrip`：更稳定地持有武器。
- `expertchef`、`pinetreepioneer`、`slingshot_sharpshooter`、`pebblemaker`：赋予部分角色兼容或互动能力。
- 可根据其他模组环境启用 `surfer` / `msurfer` 等标签。

### 食物偏好

角色对部分食物有额外亲和，例如：

- 培根煎蛋
- 鳗鱼料理
- 熟海带
- 纯蛋料理
- 榴莲与熟榴莲
- 加州卷
- 鱼子酱
- 其他兼容模组食物

---

## 核心系统：Kenjutsu 剑术

Kenjutsu 是本模组最重要的战斗系统。它由三个组件共同构成：

1. **`kenjutsuka`**：负责等级、经验、Mind Power、升级奖励和资源保存。
2. **`playerskillcontroller`**：负责技能路由、释放条件、冷却、Mind Power 消耗和实际释放。
3. **`playerkeyhandler`**：负责监听玩家按键，并将按键动作转发到服务器 RPC。

### 基本流程

1. 装备符合条件的武器，通常是带有 `katana` 标签的刀。
2. 按下技能键，例如默认 `V`、`B`、`N`、`H`。
3. 角色进入对应的技能准备状态。
4. 对目标发起攻击。
5. 技能释放，消耗 Mind Power，并进入冷却。

### 释放限制

技能一般会受到以下条件限制：

- 角色必须拥有 `kenjutsuka` 标签。
- 武器不能是远程武器、投射物或鞭类武器。
- 多数剑技需要装备武士刀。
- 部分技能需要达到指定等级。
- 未解除限制器时，需要足够 Mind Power。
- 未解除限制器时，技能会受到冷却限制。
- 不能对鸟、蝴蝶、小猎物等无效目标释放部分技能。

---

## Mind Power 系统

Mind Power 使用图标 **󰀈** 表示，是释放 Kenjutsu 技能的资源。

### 获取方式

| 来源 | 说明 |
| --- | --- |
| 使用武士刀命中目标 | 命中后获得 Kenjutsu 经验，并按配置累计 Mind Power 回复次数 |
| 命中次数回复 | 默认每 10 次符合条件的攻击触发 1 点 Mind Power 回复 |
| 自动回复 | 等级 4 后解锁自动回复；回复间隔由配置控制 |
| 限制器 | 启用 Limiter / Tatsujin 时，角色会直接达到最大等级，并绕过常规资源压力 |

### 最大值成长

- 初始最大 Mind Power 由配置 `max_mindpower` 决定。
- 每次升级会提升最大 Mind Power。
- 默认上限成长与角色等级系统绑定。

### 消耗方式

释放技能时，如果未解除限制器，将扣除技能所需 Mind Power。

| 技能 | Mind Power 消耗 |
| --- | ---: |
| Ichimonji / 一文字 | 3 |
| Flip / 翻斩 | 4 |
| Thrust / 突刺 | 4 |
| Heavenly Strike / 天翔龙闪 | 5 |
| Isshin / 一心 | 7 |
| Ryusen / 龙闪 | 8 |
| Susanoo / 须佐 | 10 |
| Soryuha / 苍龙破 | 50 |

---

## 等级成长

角色通过使用武士刀攻击目标获得 Kenjutsu 经验。默认每次有效命中获得经验，实际倍率可通过配置 `kenjutsu_exp_multiple` 调整。

### 等级表

| 等级 | 所需经验 | 主要效果 |
| ---: | ---: | --- |
| 1 | 250 | 解锁基础输入门槛 |
| 2 | 500 | 添加 `kenjutsu` 标签；快速收拔刀最低等级需求为 2 |
| 3 | 750 | 解锁 Flip 输入门槛 |
| 4 | 1000 | 解锁 Thrust 输入门槛；开启 Mind Power 自动回复 |
| 5 | 1250 | 解锁 Heavenly Strike |
| 6 | 1500 | 解锁 Isshin；获得幽灵相关理智保护与负面光环减免 |
| 7 | 1750 | 解锁 Ryusen；改善砍树、挖矿、锤击、攻击等效率倍率 |
| 8 | 2000 | 解锁 Susanoo |
| 9 | 2250 | 继续成长 |
| 10 | 2500 | 解锁 Soryuha，达到当前最大等级 |

### Limiter / Tatsujin

配置项 **Limiter** 默认启用。启用后，角色在初始化时会按最大等级经验进行初始化，相当于释放限制器，主要用于更强力或更自由的玩法体验。

关闭 Limiter 后，角色需要通过战斗逐步升级，技能消耗、冷却和成长节奏会更接近常规体验。

---

## 技能与按键

### 默认按键

| 动作 | 默认按键 | 说明 |
| --- | --- | --- |
| Ichimonji / 一文字 | `V` | 基础剑技输入 |
| Flip / 翻斩 | `B` | 基础剑技输入 |
| Thrust / 突刺 | `N` | 基础剑技输入 |
| Soryuha / 苍龙破 | `H` | 满级奥义输入 |
| Counter Attack / 反击 | `Z` | 进入反击准备 |
| Quick Sheath / 快速收拔刀 | `X` | 快速切换收刀/拔刀动作 |
| Skill Cancel / 技能取消 | `C` | 取消当前准备中的技能 |
| EyeGlasses / 眼镜 | `O` | 切换或佩戴眼镜 |
| Change Hair Style / 改变发型 | `L` | 切换发型 |
| Show Level / 查看等级 | `K` | 查看当前角色等级信息 |

所有按键都可以在 `modinfo.lua` 的模组配置中调整。

### 技能列表

| 技能 | 解锁等级 | 默认输入 | 消耗 | 默认冷却 | 简述 |
| --- | ---: | --- | ---: | ---: | --- |
| Ichimonji / 一文字 | 0 / 输入等级 1 | `V` | 3 | 45s | 基础斩击，准备后攻击目标释放。 |
| Flip / 翻斩 | 输入等级 3 | `B` | 4 | 45s | 翻斩型技能；收刀状态下可进入特殊拔刀动作。 |
| Thrust / 突刺 | 输入等级 4 | `N` | 4 | 45s | 突进/刺击型技能；收刀状态下可衔接 Heavenly Strike 事件。 |
| Heavenly Strike / 天翔龙闪 | 5 | `B → N` 路由 | 5 | 与 Isshin 共用 90s 档位 | 范围斩击与多段特效。 |
| Isshin / 一心 | 6 | `B → V` 路由 | 7 | 90s | 多段斩击与范围攻击。 |
| Ryusen / 龙闪 | 7 | `V → B` 路由 | 8 | 210s | 远距离锁定目标的多段斩击。 |
| Susanoo / 须佐 | 8 | `N → B` 路由 | 10 | 与 Ryusen 共用 210s 档位 | 多段范围打击，偏爆发。 |
| Soryuha / 苍龙破 | 10 | `H` | 50 | 45s | 满级奥义，需要满级才能释放；部分武器可作为更稳定的承载体。 |

> 注：组合技能不是传统意义上的同时按下，而是由技能路由决定的“前置技能状态 + 后续输入”。例如先按 `B` 激活 Flip 路由，再按 `V` 可进入 Isshin 路由。

### 技能释放小贴士

- 按下技能键只是“准备技能”，真正释放通常发生在下一次攻击目标时。
- 如果当前技能无法释放，会提示等级不足、Mind Power 不足、冷却中或目标无效。
- 切换武器、骑乘、死亡、卸下手部装备等行为会清理当前技能状态。
- 使用 `C` 可以主动取消当前准备中的技能。

---

## 闪避与战斗手感

角色拥有闪避能力，默认启用。

### 使用方式

- 在地面目标点执行特殊动作时，可向鼠标方向闪避。
- 闪避依赖 `dodger` 标签与 `dodger` 组件。
- 默认闪避冷却约为 1.2 秒，闪避窗口约为 0.25 秒。
- 骑乘、坐椅子等状态下不能闪避。

### 战斗风格建议

- 前期使用 Shinai 或基础 Katana 积累等级。
- 中期围绕 `V / B / N` 形成基础剑技循环。
- 高等级后通过 `B → V`、`B → N`、`V → B`、`N → B` 使用更高阶技能。
- Soryuha 消耗极高，更适合作为满级爆发或奥义使用。

---

## 武器与装备

### 起始武器配置

服务器可以在模组配置中选择起始武器：

| 选项 | prefab / 数据 | 说明 |
| --- | --- | --- |
| Nothing | `false` | 无额外起始武器，仅保留基础起始物逻辑。 |
| Shinai / 竹刀 | `shinai` | 木质练习刀。 |
| Raikiri / 雷切 | `raikiri` | 基础武士刀。 |
| Yasha / 夜叉 | `shirasaya` | 基础武士刀。 |
| Sakakura / 阪仓 | `koshirae` | 基础武士刀。 |
| Hitokiri / 人斩 | `hitokiri` | 基础武士刀。 |
| True Raikiri | `true_raikiri` | 强化雷切。 |
| True Yasha | `true_shirasaya` | 强化夜叉。 |
| True Sakakura | `true_koshirae` | 强化阪仓。 |
| True Nihiru | `true_hitokiri` | 强化人斩。 |
| Mortal Blade / 不死斩 | `mortalblade` | 特殊刀。 |
| Shusui / 秋水 | `shusui` | 特殊刀。 |
| Kage / 影 | `kage` | 特殊刀。 |

无论是否选择额外起始武器，角色默认起始物逻辑中会包含 `tokijin`。

### 可制作物品

| 物品 | 配方 | 科技 | 分类 |
| --- | --- | --- | --- |
| `mingot` | 月岩 ×8、月亮碎片 ×8、铥矿 ×4 | Science II | 精炼 |
| `harakiri` | 燧石 ×2、木头 ×2 | Science I | 角色 / 武器 |
| `mmiko_armor` | 蜘蛛丝 ×4、木板 ×2、绳子 ×2 | Science II | 角色 / 护甲 / 服装 |
| `shinai` | 绳子 ×1、木板 ×1 | Science I | 角色 / 武器 |
| `yari` | 长矛 ×1、金块 ×2 | Science II | 角色 / 武器 |
| `katanablade` | 绳子 ×1、刀身 ×1、石砖 ×1 | Science II | 角色 / 武器 |
| `shirasaya` | 手杖 ×1、刀刃 ×1、绳子 ×2、金块 ×2 | Science II | 角色 / 武器 |
| `koshirae` | 手杖 ×1、刀刃 ×1、绳子 ×2、金块 ×2 | Science II | 角色 / 武器 |
| `hitokiri` | 手杖 ×1、刀刃 ×1、绳子 ×2、金块 ×2 | Science II | 角色 / 武器 |
| `raikiri` | 手杖 ×1、刀刃 ×1、绳子 ×2、金块 ×2 | Science II | 角色 / 武器 |
| `shusui` | 刀刃 ×1、手杖 ×1、铥矿 ×20、噩梦燃料 ×20 | Ancient IV | 角色 / 武器 |
| `kage` | 刀刃 ×1、噩梦燃料 ×80 | Lost | 角色 / 武器 |

### 武器通用特征

多数 Katana 使用统一工厂函数生成，并具有以下特征：

- `katana` 标签：用于剑术系统识别。
- `sharp`、`weapon` 等标签：作为武器和锐器参与系统判断。
- 通常具有耐久。
- 部分刀具有拔刀、收刀、特效、额外伤害或阵营伤害加成。

### 特殊刀简述

- **Tokijin**：角色核心武器之一，拥有 `tokijin` 与 `onikiba` 标签，可作为某些高级技能的承载体。
- **True Raikiri**：与雷雨、雷击和电击特效相关。
- **True Hitokiri**：偏暗影主题，攻击可吸血。
- **True Shirasaya**：对暗影/月亮阵营目标有额外互动。
- **True Koshirae**：对史诗目标有额外伤害互动。
- **Mortal Blade / Shusui / Kage / Bakusaiga / Tenseiga**：特殊刀组，拥有各自攻击逻辑或特殊用途。

---

## 外观、皮肤与自定义

本模组包含大量外观资源，包括角色皮肤、发型、眼镜、头饰、头像、地图图标与加载图。

### 角色皮肤

已注册的角色皮肤包括：

- `manutsawee_none`
- `manutsawee_sailor`
- `manutsawee_yukata`
- `manutsawee_yukatalong`
- `manutsawee_miko`
- `manutsawee_qipao`
- `manutsawee_fuka`
- `manutsawee_maid`
- `manutsawee_jinbei`
- `manutsawee_shinsengumi`
- `manutsawee_taohuu`
- `manutsawee_uniform_black`
- `manutsawee_bocchi`
- `manutsawee_lycoris`

### 发型

角色支持多类发型资源：

- 短发 / 中发 / 长发
- 马尾
- 双马尾
- 高双马尾
- 妖刀风格
- 浪人风格
- 丸子头风格

可通过默认 `L` 键切换发型。

### 眼镜

支持多种眼镜资源：

- 普通眼镜
- 墨镜
- 星星眼镜

可通过默认 `O` 键切换或佩戴。

### Idle 动画

Idle 动画支持三种模式：

| 模式 | 说明 |
| --- | --- |
| Default | 不同皮肤使用各自设定的待机动画。 |
| Random | 随机播放待机动画。 |
| Disable | 禁用自定义待机动画。 |

---

## 模组配置项

### 常规设置

| 配置 | 默认值 | 说明 |
| --- | --- | --- |
| Translation | Auto | 语言选择；中英文为主要支持，其他语言多为机翻。 |
| Start Weapon | Nothing | 选择额外起始武器。 |
| Idle Animation | Default | 自定义待机动画模式。 |
| Dodge Ability | Enabled | 是否启用闪避。 |
| Limiter | Enabled | 是否解除限制器。 |

### Kenjutsu 设置

| 配置 | 默认值 | 说明 |
| --- | ---: | --- |
| Set Mind 󰀈 | 0 | 初始/基础 Mind Power 配置。 |
| Mind Regen Rate | 1 | 自动回复间隔；等级 4 后生效。 |
| Mind Regen / Hit | 10 | 默认每 10 次武士刀攻击回复 1 点 Mind Power。 |
| Kenjutsu EXP Multiple | x1 | 剑术经验获取倍率。 |

### 技能开关与冷却

| 配置 | 默认值 | 说明 |
| --- | ---: | --- |
| Skill 󰀈 | Enabled | 是否启用角色技能。 |
| Counter Cooldown | 0.63s | 反击冷却。 |
| Ichimonji Cooldown | 45s | 一文字冷却。 |
| Flip Cooldown | 45s | 翻斩冷却。 |
| Thrust Cooldown | 45s | 突刺冷却。 |
| Soryuha Cooldown | 45s | 苍龙破冷却。 |
| Isshin / Heavenly Strike Cooldown | 90s | 二阶技能冷却档位。 |
| Ryusen / Susanoo Cooldown | 210s | 三阶技能冷却档位。 |

---

## 目录结构

```text
.
├── modinfo.lua                  # 模组元数据、依赖、配置项与按键配置
├── modmain.lua                  # 主入口，按顺序导入 main/ 下的模块
├── modclientmain.lua            # 客户端入口
├── modservercreationmain.lua    # 世界创建相关入口
├── main/                        # 主加载模块：配置、资源、配方、RPC、角色、皮肤等
├── scripts/
│   ├── components/              # 自定义组件，如 kenjutsuka、playerskillcontroller、playerkeyhandler
│   ├── prefabs/                 # 角色、武器、装备、特效和物品 prefab
│   ├── utils/                   # 工具函数
│   ├── behaviours/              # 行为树扩展
│   └── map/                     # 地图布局与房间
├── postinit/                    # 对原版组件、prefab、stategraph、screen、widget 的注入
├── anim/                        # 动画资源 zip
├── images/                      # 头像、图标、物品栏贴图、加载图等
├── bigportraits/                # 角色大头像
├── strings/                     # 台词和文本
└── exported/                    # 导出资源或开发资源
```

---

## 开发者参考

### 加载顺序

`modmain.lua` 会依次加载：

1. `main/config.lua`
2. `main/util.lua`
3. `main/constants.lua`
4. `main/recipes.lua`
5. `main/assets.lua`
6. `main/strings.lua`
7. `main/fx.lua`
8. `main/tuning.lua`
9. `main/actions.lua`
10. `main/postinit.lua`
11. `main/containers.lua`
12. `main/RPC.lua`
13. `main/characters.lua`
14. `main/prefabskin.lua`
15. `main/commands.lua`
16. `main/loadingtips.lua`

修改功能时，请注意模块加载顺序。例如：

- 新配置应先在 `modinfo.lua` 中定义，再由 `main/config.lua` 读取。
- 新常量可放在 `main/constants.lua`。
- 新 prefab 需要加入 `main/assets.lua` 的 `PrefabFiles`。
- 新配方应加入 `main/recipes.lua`。
- 新角色技能通常需要同时修改 `scripts/prefabs/manutsawee.lua`、`scripts/components/playerskillcontroller.lua` 和相关 stategraph。

### 关键组件

| 组件 | 文件 | 责任 |
| --- | --- | --- |
| `kenjutsuka` | `scripts/components/kenjutsuka.lua` | 等级、经验、Mind Power、升级回调、保存读取。 |
| `playerskillcontroller` | `scripts/components/playerskillcontroller.lua` | 技能注册、输入路由、冷却、资源消耗、释放技能。 |
| `playerkeyhandler` | `scripts/components/playerkeyhandler.lua` | 按键监听、HUD 输入过滤、RPC 转发。 |
| `dodger` | `scripts/components/dodger.lua` | 闪避动作与冷却。 |
| `hair` | `scripts/components/hair.lua` | 发型切换。 |
| `glasses` | `scripts/components/glasses.lua` | 眼镜切换。 |

### 代码风格

- 变量和字段优先使用 `snake_case`。
- 常量使用 `UPPER_SNAKE_CASE`。
- 模块级函数、方法和类可使用 `PascalCase` 或 `CamelCase`。
- 缩进使用 4 个空格。
- `postinit/` 中覆盖原版方法时，应缓存原方法并做非破坏式包装。
- 注入逻辑应尽量通过标签限制作用范围，避免影响原版实体。

---

## 兼容性与注意事项

### 已知依赖

- 必须启用 Glassic API。
- 模组内含对 Island Adventure、Porkland、Uncompromising Mode、Heap of Foods 等模组的部分兼容检测或预留逻辑，但不是所有兼容逻辑都默认启用。

### 服务器平衡建议

如果希望角色更接近成长型体验：

- 关闭 **Limiter**。
- 保持经验倍率 `x1` 或 `x2`。
- 将 Mind Power 自动回复间隔调高。
- 保持高阶技能冷却为默认值。

如果希望偏爽快或单人体验：

- 开启 **Limiter**。
- 提高经验倍率。
- 降低 Mind Power 回复间隔。
- 选择强力起始武器。

### 输入注意事项

技能按键只应在 HUD 正常游戏状态下触发。文本输入场景，例如聊天、命名、建造栏搜索等，不应触发技能。若新增按键监听逻辑，请继续遵守这一设计，避免玩家打字时误触技能或 RPC。

---

## 快速上手流程

1. 启用本模组和 Glassic API。
2. 进入世界前按服务器需求调整 Limiter、起始武器、冷却和按键。
3. 选择 Louis Manutsawee。
4. 装备 `tokijin` 或其他 Katana。
5. 使用 `V / B / N` 练习基础剑技。
6. 通过战斗积累经验与 Mind Power。
7. 达到高等级后尝试 `B → V`、`B → N`、`V → B`、`N → B` 等高阶路由。
8. 满级后使用 `H` 尝试 Soryuha。

---

## 维护备忘

- README 主要描述当前代码中的实际机制；如果后续修改技能、配方、数值或按键，请同步更新本文档。
- 若新增语言，请同时检查 `strings/`、`scripts/languages/` 与 `modinfo.lua` 的配置展示。
- 若新增皮肤，请同步注册 `bigportraits/`、`anim/`、`images/` 资源，并更新 `main/prefabskin.lua`。
