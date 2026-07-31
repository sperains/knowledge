# 用户图形尺寸调整方案

## 1. 目标

调整 `shape.type = 'user'` 的尺寸语义，使头像始终保持正方形，同时允许用户通过手动调整图形尺寸显示完整文本。

本方案以简单、稳定和容易维护为优先，不增加用户图形专用数据模型。

## 2. 尺寸模型

用户图形继续只使用 `shape.width` 和 `shape.height`：

```text
shape.width  = 头像边长，同时也是文本区域宽度
shape.height = 头像区域、固定间隔和文本区域的总高度
```

布局规则：

```text
头像区域：x = 0，y = 0，width = shape.width，height = shape.width
文本区域：x = 0，y = shape.width + 固定间隔
          width = shape.width
          height = shape.height - shape.width - 固定间隔
```

固定间隔只表达头像和文本之间的距离，不再把文本预留高度和间隔混为一个常量。

建议常量：

```ts
export const USER_AVATAR_TEXT_GAP = 4;
export const USER_DEFAULT_TEXT_HEIGHT = 36;
```

默认创建高度为：

```ts
shape.width + USER_AVATAR_TEXT_GAP + USER_DEFAULT_TEXT_HEIGHT
```

## 3. 缩放规则

用户手动调整尺寸时：

- `width` 变化时，头像按新的宽度等比例缩放，文本区域宽度同步变化；
- `height` 变化时，头像尺寸不变，只调整文本区域高度；
- 不根据文本内容自动修改图形高度；
- 不区分边角控制点和边中控制点，不增加额外缩放模式；
- 仅保留最小尺寸约束，避免头像或图形出现零尺寸。

用户文本超出当前文本区域时，暂时保持裁剪或隐藏状态。用户手动增加宽度或高度后，文本区域随图形扩大并显示更多内容。

## 4. 渲染约束

所有涉及用户图形区域的模块统一使用相同的几何计算：

- 头像使用 `shape.width × shape.width`，禁止使用 `shape.height` 拉伸头像；
- 富文本起点使用 `shape.width + USER_AVATAR_TEXT_GAP`；
- 富文本宽度使用 `shape.width`；
- 富文本高度使用整体高度减去头像高度和固定间隔；
- 选中框、工具栏位置、预览和连线继续使用整体 `shape` 包围盒。

不使用整体图形缩放实现头像调整，避免文本也被同步缩放。

## 5. 兼容性

现有用户图形已经使用 `shape.width` 作为头像尺寸，因此不需要新增字段或数据迁移。

历史数据只需要继续保证：

```ts
shape.height >= shape.width + USER_AVATAR_TEXT_GAP + USER_DEFAULT_TEXT_HEIGHT
```

当历史数据高度不足时，按默认文本区域高度补足为：

```ts
shape.width + USER_AVATAR_TEXT_GAP + USER_DEFAULT_TEXT_HEIGHT
```

## 6. 实施范围

1. 统一领域层和界面层的用户图形几何常量与文本区域计算。
2. 移除缩放规则中“头像尺寸决定整体高度”的强绑定。
3. 调整用户图形默认尺寸和历史数据高度归一化逻辑。
4. 保持文本编辑、协作同步、连线端点、选中框和删除逻辑不变。
5. 在 `icce/tests` 下使用 Vitest 验证几何计算、默认尺寸和缩放约束。

## 7. 非目标

- 不新增 `data.userLayout` 或其他用户图形布局字段。
- 不在文本编辑完成后自动调整图形高度。
- 不实现文本自动适应、自动缩放字体或自动扩展宽度。
- 不拆分头像和文本为两个独立图形。
