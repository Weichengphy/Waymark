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
  叠加 10×10 的探索度网格：绿色 = 去过的格子，灰色 = 还没去过。
- **右侧检查器**：小地图 + 照片网格 + 到访记录 + 分类/备注编辑 + 删除。

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

iPhone 端用 SwiftData，这边是纯 JSON：Mac 版目前不同步、数据量最多几百个地点、
整个能放进内存，用文件就不用为一个本来就装得下的东西准备 store 迁移方案。模型字段名
特意和 iPhone 端保持一致（`Visit.note` 而不是 `notes` 等），以后要对接不用改字段。

照片导入时原图字节直接拷贝，不重新编码（iPhone 端是从相册拿 `UIImage` 再存 JPEG）；
缩略图走 ImageIO 的 `CGImageSourceCreateThumbnailAtIndex`，不把整张 4000 万像素的图
解码进内存——拖一个文件夹进来时这个区别很明显。

## 探索度是怎么算的

`Support/CityCoverageCalculator.swift`，从 iPhone 端整体搬过来：取该城市所有打卡点的
外接矩形（外扩 25%，最小 ~3km 防止单点退化成一个点），切成 10×10 网格，落进格子的
算「去过」，去过的格子数 / 100 就是百分比。

这不是精确的面积计算——没有内置的行政区边界数据可以求交。Mac 版比 iPhone 端多画了
未访问的格子（浅灰），因为屏幕够大，「还剩多少没去」和「去过多少」一样值得看见。
以后换成真实边界多边形只需要替换这一个文件，调用方只认 `CityCoverageSummary`。

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
