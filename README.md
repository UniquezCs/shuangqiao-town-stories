# Shuangqiao Town Stories

`Shuangqiao Town Stories`（《双桥镇往事》）是一个使用 Godot 4.6 开发的 2D 像素风经营模拟游戏项目。

游戏背景设定在 20 世纪 80 到 90 年代的中国乡镇。玩家扮演一名中年人，在市场经济刚刚活跃起来的时期从小规模摆摊开始，通过劳作、进货、定价、售卖和再投资，逐步把生意做大。

## 游戏背景

游戏发生在“双桥镇”。这里有住宅、学校、工厂、商店、道路和公共建筑，人流会随时间、建筑类型和人群结构变化。

项目想表达的核心不是快速暴富，而是小人物在现金流压力、经营风险和生活责任中一点点积累：今天种下或买来的货，能不能在合适的时间、地点和价格卖出去，决定了明天还能做什么。

## 核心玩法

- 劳作或进货获得商品，例如种植苹果、梨、香蕉、葡萄等农产品。
- 管理背包和快捷栏，选择工具、种子和可售商品。
- 在镇上合适区域摆摊，把背包商品拖到摊位格子中并设置价格。
- NPC 会根据年龄、性别、预算、喜好、人流路径和当前摊位商品决定是否停留、购买或离开。
- 顾客决定购买后会进入等待状态，玩家需要在倒计时结束前互动完成交易。
- 城管会从警察局出发巡逻，发现摆摊后追赶玩家，追到后触发罚款和强制收摊。
- 每天睡觉或到午夜后进入第二天，展示昨日收入、销量、顾客和处罚等总结，并自动存档。

当前原型已围绕“获得商品 -> 摆摊售卖 -> 赚钱 -> 再生产”形成可玩的经营闭环。

## 技术方案

- 引擎：Godot 4.6。
- 语言：GDScript。
- 画面：2D 像素风，基准尺寸为 `32x32` tile、`48x64` 角色/NPC 帧、`32x32` 小道具。
- 场景结构：
  - `TitleScreen`：标题界面、新游戏、读档、退出。
  - `Main`：游戏入口，管理玩家、HUD、场景切换、时间和 UI。
  - `HouseScene`、`HomeScene`、`TownScene`、`BackMountainScene`：主要地图场景。
  - `Player`、`Customer`、`Chengguan`、`NpcEndpoint`、`Stall`、`FarmPlot` 等负责具体玩法对象。
- 数据驱动：
  - `configs/items.json` 管理商品基础属性。
  - `configs/crops.json` 管理作物成长和产出。
  - `configs/upgrades.json` 管理背包和摊位升级。
  - `configs/customer_preferences.json`、`configs/flow_preferences.json` 管理顾客喜好和人流偏好。
- 架构原则：
  - 用 Autoload 管理全局状态，例如 `GameState`、`Inventory`、`Hotbar`、`SaveManager`、`PopulationFlow`。
  - 跨系统沟通优先使用 `SignalBus`。
  - 地图使用视觉层和逻辑层分离：视觉可使用大图或 TileMapLayer，玩法读取道路、摆摊区、碰撞和端点等逻辑节点/图层。
  - 优先使用 Godot 节点、Area2D、StaticBody2D、CollisionShape2D、Timer 和信号实现玩法规则，避免不必要的逐帧扫描。

## 项目结构

```text
assets/      游戏素材
configs/     商品、作物、升级、人流和素材注册配置
docs/        设计文档、开发准则和资源注册表
scenes/      Godot 场景
scripts/     GDScript 逻辑
tests/       Godot headless 测试场景
tools/       本地辅助脚本
```

## 运行与测试

用 Godot 4.6 打开项目根目录即可运行。

本地测试入口：

```bash
tools/run_godot_headless_tests.sh
```

如果 Godot 不在 `PATH`，可以指定：

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/run_godot_headless_tests.sh
```

## 当前状态

项目仍处于原型开发阶段，重点系统包括种植、背包、快捷栏、摆摊、多商品售卖、顾客购买判断、人流模拟、城管巡逻、日结、自动存档和标题界面。

后续重点会继续围绕摆摊经营手感、NPC 人流可信度、商品经济平衡、地图交互和美术资源规范化推进。
