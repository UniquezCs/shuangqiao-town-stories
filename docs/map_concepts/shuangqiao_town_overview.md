# 双桥镇总览平面图概念

## 用途

本图用于《双桥镇往事》的镇区总览参考，目标是帮助后续拆分
`TileMapLayer`、道路、建筑位置、NPC 路线、摆摊区域和场景出口。

当前阶段是美术和关卡规划参考图，不直接作为最终可运行地图。

参考图文件：`docs/map_concepts/shuangqiao_town_overview.png`

## 核心空间结构

- 地点：双桥镇。
- 年代：八九十年代中国乡镇。
- 视角：俯视或轻微 3/4 俯视像素风。
- 关键地标：西侧老石桥、东侧新水泥桥。
- 河流：横向穿过地图下三分之一，河滩可承载摸鱼、捡螺、采集和早市前冒险玩法。
- 主路：东西向穿过镇中心，连接两座桥、老街、市场、粮仓和外部道路。
- 集市路：南北向穿过中心，与东西主路形成主要市场路口。

## 区域布局

| 区域 | 建议位置 | 玩法用途 |
| --- | --- | --- |
| 老街市场 | 地图中心，东西主路与南北集市路交会处 | 摆摊、定价、顾客购买、早市倒计时 |
| 玩家目标门面 | 老街市场路口附近 | 长期目标：从临时摊位升级到固定店面 |
| 供销社/杂货铺 | 中心老街一侧 | 买基础工具、日用品、种子、饲料 |
| 种子铺/农资铺 | 市场附近 | 作物与生产系统入口 |
| 粮站/仓库 | 东侧靠近新桥 | 大宗收购、仓储、批发订单 |
| 工厂门口 | 西北侧 | 工人客流、下岗背景、午后销售点 |
| 学校门口 | 东北侧 | 学生客流、小额高频消费 |
| 汽车站 | 南中部靠近主路 | 外来客流、跨村进货、远行路线 |
| 住宅巷 | 西南与东南 | 人情关系、赊账、邻里事件 |
| 家和小农场 | 地图南缘 | 种植、养殖、初始生产、每日出发点 |
| 河滩 | 河流两岸 | 高随机性采集、雨后资源、时间风险 |

## 道路方向

- 东西主路：从西侧老石桥进入，穿过老街市场，通往东侧新水泥桥和粮站。
- 南北集市路：从北侧学校/厂区方向下行，穿过市场路口，连接汽车站、住宅巷和玩家家。
- 河滩小路：沿河两岸横向延伸，连接两个桥头和南侧农宅。
- 住宅巷：从主路和集市路分出多条短巷，适合做 NPC 家、邻里任务和小额交易点。
- 田间土路：从玩家家通向菜地、鸡舍、猪圈、河滩和镇中心。

## 后续 TileMap 拆分建议

- `GroundLayer`：泥地、草地、田地、河滩、广场底面。
- `RoadLayer`：主路、集市路、桥面、巷道、田间土路。
- `WaterLayer`：河流与浅滩。
- `BuildingLayer`：不可穿越建筑基底。
- `DecorationLayer`：树、墙、招牌、摊位小物、车辆、竹篮。
- `StallAreaLayer`：允许摆摊的位置标记。
- `NpcEndpointLayer`：学校、工厂、住宅、汽车站、市场、粮站等 NPC 路线端点。

## 生成提示词

```text
Create a top-down panoramic pixel-art town plan for a 2D management sim set in a Chinese township in the late 1980s and early 1990s. The town is called Shuangqiao Town, but do not draw any text labels. Use a clean readable retro pixel-art style, orthographic top-down / slight 3/4 top-down planning view, 16:9 wide map, warm daylight, clear roads and building placement.

Map requirements:
- A small Chinese township with two bridges as the key landmark: one old stone bridge in the west, one newer concrete bridge in the east.
- A river runs horizontally across the lower third of the map, with riverbank paths and small fishing / foraging spots.
- Main road runs west-east through the middle of town, connecting both bridges and the old street.
- A north-south market road crosses the main road near the center, forming the main market intersection.
- Old Street market area near the center: roadside stalls, cloth mats, bamboo baskets, small awnings, crowded but still readable.
- Supply cooperative / small general store on the central old street.
- Seed shop and farm supply shop near the market.
- Grain depot and warehouse area on the east side.
- Small factory gate and workers' dormitory in the northwest.
- School gate in the northeast with a small courtyard.
- Bus stop / rural bus station near the south central road.
- Residential lanes with brick houses and small courtyards in the southwest and southeast.
- Home/farm area at the southern edge: small vegetable plots, chicken coop, pig pen, tool shed.
- Future player shopfront target on the old street near the market intersection, visibly placed as a small storefront among other shops.
- Dirt paths connect farm, riverbank, residential lanes, and market.
- Clear walkable roads, alleys, bridge crossings, and open stall spaces.
- Include 1980s/1990s Chinese township details: brick houses, tiled roofs, dirt roads, concrete road patches, bicycle stands, tricycle, handcart, bamboo baskets, enamel-sign style storefronts without readable text, utility poles, low walls, trees.

Composition requirements:
- No modern cars, no smartphones, no fantasy elements, no neon city visuals.
- No UI overlay, no arrows, no labels, no numbers, no legend, no written text.
- Buildings should be visually distinct by shape and context.
- Roads must be easy to read from above.
- Keep the map usable as a game development planning reference, not a decorative poster.
- Pixel art should be crisp, tile-friendly, readable at small scale, with a balanced color palette and no excessive clutter.
```
