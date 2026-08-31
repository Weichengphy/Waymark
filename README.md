# Waymark

一个 macOS 地图打卡应用：以地图为中心，记录去过哪些地方、在那里拍了什么、某座城市
探索了百分之多少。纯本地存储，不联网，没有账号。

它是我一个同名 iPhone app（Waypoint）的 Mac 版。**不含徒步功能**——用电脑记录 GPS
轨迹没有意义，所以路线记录 / 后台定位这一整块都没有移植过来，`PlaceCategory` 也相应
去掉了 `hikeSpot`。数据完全独立于 iPhone 端，两边目前不同步（见「已知的下一步」）。

需要 macOS 14 或更高版本。

## 下载安装

从 [Releases](../../releases) 下载 `Waymark.app.zip`，解压后拖进「应用程序」。

首次打开会被 Gatekeeper 拦下，提示无法验证开发者——这个 app 是 ad-hoc 签名、没有经过
苹果公证（公证需要 Apple 开发者账号）。绕过方式是**右键点击 app → 打开**，在弹出的对话
框里再点一次「打开」；此后正常双击即可。或者在终端里：

```bash
xattr -d com.apple.quarantine /Applications/Waymark.app
```

不放心二进制的话，跳过 Release 直接按下面自己构建，源码就是全部内容。

## 从源码构建

```bash
./package.sh --install --run
```

SwiftPM 不产出 app bundle，所以 `package.sh` 负责把 `.build/release/Waymark`
套进 `Waymark.app`（二进制 + Info.plist + 图标），再 ad-hoc 签名——没签名的 bundle
一启动就会被 Gatekeeper 杀掉。**不要只跑 `swift build`**：那样 `Waymark.app` 里还是旧
二进制，看起来像改动没生效。

| 参数 | 作用 |
| --- | --- |
| （无） | 构建 + 打包 + 签名 |
| `--run` | 顺带启动 |
| `--icon` | 先从 `icon.png` 重新生成 `Resources/AppIcon.icns` |
| `--install` | 装到 `/Applications`（不可写时退到 `~/Applications`） |

`--install` 是 Spotlight 能搜到它的前提：只有位于 `/Applications` 或 `~/Applications`
的 bundle 才会被当作*应用程序*索引，放在这个项目目录里的构建产物永远不会出现在 ⌘空格
的结果里。脚本装完会跑 `lsregister` + `mdimport` 强制索引一遍，不用等系统自己扫。
日常使用启动 `/Applications/Waymark.app` 那份。

也可以直接 `swift run`，但那样启动的是无菜单栏的后台进程——`AppDelegate` 里
`setActivationPolicy(.regular)` 就是为了兜住这种情况。

## 界面：侧栏 + 地图 + 检查器

Mac 屏幕宽，所以 iPhone 上「地图 / 城市列表 / 城市地图 / 地点详情」这四层导航在
这里被压平成同屏三栏，选中一个大头针时右侧检查器直接展开，地图不会被盖住。

- **左侧栏**：全部打卡点 + 城市列表，每个城市一条探索度进度条。搜索框同时搜城市和
  地点名，等于「跳转到任意位置」。底部可新建城市。
- **中间地图**：核心。缩放到一定程度以上按城市聚合成一个 pin（阈值 1.5°，和 iPhone
  端一致），放大后展开为单个地点 pin（分类图标 + 名称 + 照片数）。选中某座城市时，
  叠加 1 公里见方的探索度网格：琥珀色 = 去过的区域，压暗 = 还没去过。
- **右侧检查器**：小地图 + 照片网格 + 到访记录 + 分类/备注编辑 + 删除。选中行程而未选中
  地点时，这里显示的是行程单。

## 旅行踪迹

侧栏的「旅行踪迹」列出每一趟行程，点击后地图按顺序把途经城市连成一条虚线，每一站标上
1、2、3，右侧同时展开行程单：每站的城市、日期、以及在那里打卡了哪些地点。点地图上的
编号或行程单里的某一站会缩放到那一段，行程线保持画着；点具体地点则切到该地点的详情。

**行程是从到访日期自动推导的，不需要手工建。** 规则在
`Support/TripBuilder.swift`：相隔不超过 3 天的到访归为同一趟，只有 1 次到访的不算行程。
理由是日期本来就已经录进去了，再让用户单独声明一次行程等于把同一件事问两遍——而且自动
推导意味着以前记过的行程也会一并回溯出现。

3 天这个阈值容得下行程中间休整一天，又能把前后两个独立的周末分开。同一城市连续的几次
到访会合并成一站，所以「北京 → 杭州 → 北京」是三站而不是两站——那才是路线真实的样子。

### 路线为什么是驾车路线而不是铁路

`Services/RouteService.swift` 用 `MKDirections` 取两站之间的真实地面路线画在地图上。

**MapKit 拿不到铁路线。** 实测 `MKDirections` 用 `.transit` 直接失败（`MKError` 5，
directionsNotFound）——苹果只支持把轨道交通查询转交给「地图」App，不通过 API 返回几何。
要画真正的铁轨得接 OpenStreetMap 之类的外部数据，而这个 app 其余部分完全离线。

驾车路线走的是同一批地面走廊——国内高速大体与铁路并行，京杭驾车 1270 km 对高铁里程
1279 km——所以看起来是「走过去的」，而不是一条尺子划的直线。以后要换成铁路几何，只需要
改 `RouteService.fetch` 一个函数，其余部分按段（`TripLeg`）组织，不用动。

线型区分状态：**实线 = 查到的地面路线，虚线 = 直连**（正在查询中，或根本没有地面路线，
比如跨海那一段，行程单里会标「无地面路线 ✈︎」）。查到的路线会抽稀到 400 个点存进
`routes.json`，之后离线也能画，不会重复查询。

## 和 iPhone 端不同的交互

| iPhone | macOS | 为什么 |
| --- | --- | --- |
| 长按地图新建打卡点 | **⌥ 点击**地图 | 单击/双击在 Mac 上已经是选中/缩放，长按没有对应手势 |
| PhotosPicker 导入 | 拖拽文件/文件夹进检查器，或点「导入」开文件面板 | Mac 上照片通常已经在硬盘上，拖一个行程文件夹进来最快 |
| 下钻到城市地图页 | 侧栏选中城市，地图原地聚焦 + 出网格 | 同屏能放下，不需要导航栈 |
| 定位当前位置新建 | 从当前地图中心新建 | Mac 基本不带 GPS，`LocationService` 整个没有移植 |

拖文件夹进来会自动展开成里面的图片；导入前有一步确认，可以逐张改 EXIF 读出的拍摄
时间（读不到就退回文件创建时间）。

## 数据怎么存的

`~/Library/Application Support/Waymark/`（旧版本叫 WaypointMac，`DataStore.appFolder`
里有一次性的目录搬迁，跑过一次后旧路径就不存在了）
- `data.json` —— 全部 `Place`（内嵌 `Visit` / `Photo`），每次修改整体重写
- `Photos/` —— 导入照片的原图 + `_thumb.jpg` 缩略图
- `routes.json` —— 行程各段查到的地面路线，抽稀后缓存，删掉会重新查

iPhone 端用 SwiftData，这边是纯 JSON：Mac 版目前不同步、数据量最多几百个地点、
整个能放进内存，用文件就不用为一个本来就装得下的东西准备 store 迁移方案。模型字段名
特意和 iPhone 端保持一致（`Visit.note` 而不是 `notes` 等），以后要对接不用改字段。

照片导入时原图字节直接拷贝，不重新编码（iPhone 端是从相册拿 `UIImage` 再存 JPEG）；
缩略图走 ImageIO 的 `CGImageSourceCreateThumbnailAtIndex`，不把整张 4000 万像素的图
解码进内存——拖一个文件夹进来时这个区别很明显。

## 探索度是怎么算的

`Support/CityCoverageCalculator.swift`。

把城市切成 **1 公里见方**的格子，**距离任一打卡点 1.5 公里以内**的格子算「已到过」，
占比就是探索度。

几个刻意的选择：

- **按距离判定，不是按格子里有没有点。** 打卡不是一个针尖——你会在那一带走一走，逛
  公园、绕寺院。早先的版本要求大头针正好落在格子里，于是在西湖边走一天只点亮三个孤立
  的小方块，报出 3%。
- **格子是固定物理尺寸，不是固定 10×10。** 固定格数会让北京的格子有 4 公里宽、杭州的
  只有 700 米，两个城市的百分比根本不是同一回事，没法比较。
- **面积下限 10 公里见方。** 分母是打卡点的外接矩形，点越集中矩形越小、百分比越虚高：
  修正前，西湖边 3 个点算出 55%，而常住城市北京的 7 个点只有 6%——越集中反而显得越
  「探索充分」。加了下限之后是北京 6%、上海 9%、杭州 9%。

**这不是精确的面积计算**：没有内置行政区边界数据可以求交，分母仍然是打卡点外接矩形
（含 25% 外扩），所以这个数字读作「我去过的这片范围里，有多少是我走到过的」——同一
座城市纵向比较有意义，紧凑城市和摊大饼的城市之间横向比较仍然不准。以后换成真实边界
多边形只需要替换这一个文件，调用方只认 `CityCoverageSummary`。

配色上「已到过」用琥珀色而不是绿色：苹果地图本身就用绿色画公园、山地和郊野，半透明的
绿色蒙层压在杭州西边的山上完全看不见——偏偏那正是这个功能最该说话的地方。琥珀色是底图
不会用于大面积的色相，在地形、街道和水面上都能读出来，未到过的区域则统一压暗，靠对比
把已到过的部分推出来。

## 项目结构

```
Sources/
  WaymarkApp.swift        入口 + AppDelegate（把 SwiftPM 可执行文件提升为正常 App）
  DesignSystem/               字号/圆角 token + 分类颜色（比 iPhone 端小一号）
  Models/                     Place / Visit / Photo（Codable struct，非 SwiftData）
  Services/
    DataStore.swift           JSON 持久化 + 全部增删改
    PhotoStorage.swift        照片落盘 + ImageIO 缩略图
    PhotoImportService.swift  EXIF 拍摄时间/GPS 解析，文件夹展开
    ReverseGeocodingService.swift  反查地名 / 正查城市坐标（actor + 缓存）
  Support/
    CityCoverageCalculator.swift  探索度网格
    CityAggregate.swift           城市聚合 + 「缩放到全部」的 region
    DateFormatting.swift
  Views/
    ContentView.swift         三栏骨架 + 工具栏
    Sidebar/                  城市列表 + 搜索
    Map/                      地图主视图、新建地点、新建城市、地点搜索
    Detail/                   右侧检查器、照片导入确认、新增到访
    Components/               地点 pin、城市聚合 pin、缩略图、全屏看图
```

## 已知的下一步（有意留白）

- **和 iPhone 端同步**：现在两边各存各的。iPhone 那边是 SwiftData，最省事的路径是
  两边都接 CloudKit；模型字段名已经对齐，主要工作在把这边的 JSON store 换成 SwiftData。
- **照片反向定位**：`Photo` 已经在存 EXIF 里的 GPS，但还没用来在地图上单独标点，
  也还没做「这张照片其实拍在另一个地点」的自动归属建议。
- **真实城市边界**：见上面探索度那节。
- **导出**：`DataStore` 已经是纯 Codable，导出 GeoJSON/CSV 加一个文件就行。
