# PhoneScreen

[中文](README.md) | English

A virtual display in the menu bar. It turns one of your Mac's screens into a phone-sized pixel resolution, so the desktop NetEase UU Remote sees matches the phone screen's aspect ratio, with no black bars on the sides or top and bottom.

The virtual display exists only while the PhoneScreen process is running. It disappears when you quit, disconnect, or press the emergency hotkey. The resolution can be changed at any time; it is not hard-coded.

The default preset is iPhone 17e portrait at 1170×2532, landscape 2532×1170, both 460 ppi. Apple's [iPhone 17e tech specs](https://www.apple.com/iphone-17e/specs/) state "2532-by-1170-pixel resolution at 460 ppi", long side first. Held upright, the width is 1170 and the height is 2532. Measured as this rectangle, the diagonal is about 6.06 inches, matching Apple's description of the screen.

## Download

[Download PhoneScreen.dmg](https://github.com/nightwatch-lab/PhoneScreen/releases/latest/download/PhoneScreen.dmg) ([all releases](https://github.com/nightwatch-lab/PhoneScreen/releases))

Open the DMG and drag PhoneScreen into Applications. The app is unsigned; the first time, right-click it → Open.

## Using with UU Remote

1. On the Mac, open PhoneScreen and click iPhone 17e portrait (or switch orientation first, then connect). A green dot next to the menu bar icon means the virtual display is active.
2. Open UU Remote on the Mac, and connect to this Mac from UU Remote on the phone.
3. In UU, switch to the display named PhoneScreen 1170x2532 instead of staying on the Mac's own main display. With the aspect ratios aligned, the image fills the phone instead of shrinking to the middle with black bars.
4. If your version of UU can only capture the main display, go back to PhoneScreen and click Set as Main Display. Tools that only capture the main display will then see this phone-shaped screen. When done, click Restore Original Arrangement or Disconnect.
5. The phone's rounded corners crop the four corners of the image. That is the shape of the screen, not black bars.

Creating the virtual display itself does not require Screen Recording permission. If the phone stays black, go to System Settings → Privacy & Security → Screen Recording, enable UU Remote for Mac, then fully quit and reopen UU.

## Requirements

- macOS 14 or later. Older systems refuse to create the display.
- At launch, the app checks whether the private class CGVirtualDisplay actually exists in CoreGraphics. If not, connecting is disabled with an explanation in the menu; it does not crash.
- No need to disable SIP. This calls a private class from a system framework in-process; it is not a kernel extension.
