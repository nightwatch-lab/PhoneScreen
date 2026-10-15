# PhoneScreen

[English](#english)

菜单栏里的虚拟显示器。把 Mac 的一块屏幕做成手机的像素尺寸，这样网易 UU远程 看到的桌面和手机屏幕同比例，不再左右或上下留黑边。

虚拟显示器只在 PhoneScreen 这个进程活着的时候存在。退出、断开、或按紧急热键之后它会消失。分辨率随时可改，不是写死的。

默认预设是 iPhone 17e 竖屏 1170×2532，横屏是 2532×1170，都是 460 ppi。Apple 在 [iPhone 17e 技术规格](https://www.apple.com/iphone-17e/specs/) 里写的是 “2532-by-1170-pixel resolution at 460 ppi”：长边在前。竖着拿手机时，宽是 1170，高是 2532。按这个矩形量，对角线约 6.06 英寸，和 Apple 对这块屏幕的说明一致。

## 下载

[下载 PhoneScreen.dmg](https://github.com/nightwatch-lab/PhoneScreen/releases/latest/download/PhoneScreen.dmg)（[所有版本](https://github.com/nightwatch-lab/PhoneScreen/releases)）

打开 DMG，把 PhoneScreen 拖进「应用程序」。App 未签名，第一次请右键 → 打开。

## 配合 UU远程

1. 在 Mac 上打开 PhoneScreen，点 iPhone 17e 竖屏（或先横竖切换再连接）。菜单栏图标旁出现绿点表示虚拟屏已经在。
2. 打开 UU远程 的 Mac 端，手机上的 UU远程 连上这台 Mac。
3. 在 UU 里切到名为 PhoneScreen 1170x2532 的那块屏幕，不要停在 Mac 自己的主屏上。比例对齐之后，画面会铺满手机，而不是缩在中间留黑边。
4. 如果这版 UU 只能采集主显示器，回到 PhoneScreen 点 设为主显示器。只抓主屏的工具就会看到这块手机比例的屏幕。用完点 恢复原始排列 或 断开。
5. 手机圆角会裁掉画面四个角，那是屏幕形状，不是黑边。

创建虚拟屏本身不需要屏幕录制权限。手机端一直黑屏时，到 系统设置 → 隐私与安全性 → 屏幕录制，勾选 UU远程 的 Mac 端，把 UU 彻底退出再打开。

## 环境

- macOS 14 或更新。更老的系统直接拒绝创建。
- 启动时会检查 CoreGraphics 里是否真的有私有类 CGVirtualDisplay。没有就停用连接，并在菜单里说明，不会崩。
- 不需要关闭 SIP。这是进程内调用系统框架里的私有类，不是内核扩展。

---

## English

A virtual display in the menu bar. It turns one of your Mac's screens into a phone-sized pixel resolution, so the desktop NetEase UU Remote sees matches the phone screen's aspect ratio, with no black bars on the sides or top and bottom.

The virtual display exists only while the PhoneScreen process is running. It disappears when you quit, disconnect, or press the emergency hotkey. The resolution can be changed at any time; it is not hard-coded.

The default preset is iPhone 17e portrait at 1170×2532, landscape 2532×1170, both 460 ppi. Apple's [iPhone 17e tech specs](https://www.apple.com/iphone-17e/specs/) state "2532-by-1170-pixel resolution at 460 ppi", long side first. Held upright, the width is 1170 and the height is 2532. Measured as this rectangle, the diagonal is about 6.06 inches, matching Apple's description of the screen.

### Download

[Download PhoneScreen.dmg](https://github.com/nightwatch-lab/PhoneScreen/releases/latest/download/PhoneScreen.dmg) ([all releases](https://github.com/nightwatch-lab/PhoneScreen/releases))

Open the DMG and drag PhoneScreen into Applications. The app is unsigned; the first time, right-click it → Open.

### Using with UU Remote

1. On the Mac, open PhoneScreen and click iPhone 17e portrait (or switch orientation first, then connect). A green dot next to the menu bar icon means the virtual display is active.
2. Open UU Remote on the Mac, and connect to this Mac from UU Remote on the phone.
3. In UU, switch to the display named PhoneScreen 1170x2532 instead of staying on the Mac's own main display. With the aspect ratios aligned, the image fills the phone instead of shrinking to the middle with black bars.
4. If your version of UU can only capture the main display, go back to PhoneScreen and click Set as Main Display. Tools that only capture the main display will then see this phone-shaped screen. When done, click Restore Original Arrangement or Disconnect.
5. The phone's rounded corners crop the four corners of the image. That is the shape of the screen, not black bars.

Creating the virtual display itself does not require Screen Recording permission. If the phone stays black, go to System Settings → Privacy & Security → Screen Recording, enable UU Remote for Mac, then fully quit and reopen UU.

### Requirements

- macOS 14 or later. Older systems refuse to create the display.
- At launch, the app checks whether the private class CGVirtualDisplay actually exists in CoreGraphics. If not, connecting is disabled with an explanation in the menu; it does not crash.
- No need to disable SIP. This calls a private class from a system framework in-process; it is not a kernel extension.
