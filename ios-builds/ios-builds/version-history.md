# 📱 iOS Build Version History

## Current Status
- **Active Build**: v1.5.0 (build 18)
- **Distribution Method**: Updraft (wireless)
- **Last Updated**: July 28, 2025

---

## Build History

### v1.5.0 (Build 18) - July 28, 2025 ✅
- **Status**: Active and Working
- **Updraft Link**: `https://app.getupdraft.com/getapp/6ba7059b128646c39e92f71eb225dd5f`
- **Distribution**: Successfully uploaded to Updraft
- **Family Testing**: Working wirelessly via Safari
- **Changes**: 
  - Fixed TestFlight installation issues
  - Set up Updraft distribution system
  - Resolved "Removed from Sale" blocking
  - Added encryption compliance to Info.plist
  - Cleaned up iOS project configuration

### Previous Builds (Pre-Updraft)
- **v1.5.0 (Build 17)**: TestFlight (expired/failing)
- **v1.5.0 (Build 16)**: TestFlight (expired/failing) 
- **Earlier builds**: Various TestFlight attempts with 90-day expiration issues

---

## Distribution Notes

### Updraft Configuration
- ✅ **"App is public"** setting enabled
- ✅ **Over-the-air installation** manifest included
- ✅ **No account required** for family installation
- ✅ **No expiration** (unlike TestFlight's 90-day limit)

### Build Process
- **Flutter**: 3.24.x
- **Xcode**: 16.x
- **Distribution**: Release Testing (Ad Hoc)
- **Signing**: Automatic (Development Team: 7G6BL76L64)
- **Bundle ID**: com.saifalafeefi.pantrybot

### Family Testing Status
- ✅ **Installation**: Working via Safari link
- ✅ **Device Compatibility**: iPhone/iPad iOS 12.0+
- ✅ **User Experience**: No account signup required
- ✅ **Update Method**: New Updraft links for updates

---

## Next Version Planning

### v1.5.1 (Build 19) - TBD
- **Planned Changes**: TBD based on main branch updates
- **Process**: 
  1. Sync from main: `./sync-from-main.sh`
  2. Update version in pubspec.yaml
  3. Build and archive in Xcode
  4. Export for Updraft distribution
  5. Upload and test with family

---

## Build Checklist Template

For each new build:
- [ ] Sync from main branch (`./sync-from-main.sh`)
- [ ] Update version number in `pubspec.yaml`
- [ ] Clean Flutter build (`flutter clean && flutter pub get`)
- [ ] Build iOS release (`flutter build ios --release`)
- [ ] Archive in Xcode (Product → Archive)
- [ ] Export with "Release Testing" + manifest
- [ ] Save IPA to `ios-builds/releases/`
- [ ] Upload to Updraft dashboard
- [ ] Verify "App is public" setting
- [ ] Test installation on personal device
- [ ] Share link with family
- [ ] Update this version history

---

**Last Updated**: July 28, 2025 by iOS Distribution Branch Setup 