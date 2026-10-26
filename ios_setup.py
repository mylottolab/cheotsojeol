# 첫소절 iOS — Codemagic 이 "npx cap add ios" 로 만든 아이폰 폴더에 우리 설정을 끼워 넣습니다.
# (PaperLotto 와 같은 방식: 폴더는 빌드 때 만들고, 파일만 저장소에 둡니다)
import plistlib, shutil, json
A = 'ios/App/App/'
CFG = json.load(open('capacitor.config.json', encoding='utf-8'))
APP_ID = CFG['appId']
APP_NAME = CFG.get('appName', '첫소절')

shutil.copy('AppDelegate.swift', A + 'AppDelegate.swift')
shutil.copy('App.entitlements', A + 'App.entitlements')
shutil.copy('AppIcon.png', A + 'Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png')
for n in ['splash-2732x2732.png', 'splash-2732x2732-1.png', 'splash-2732x2732-2.png']:
    shutil.copy('Splash.png', A + 'Assets.xcassets/Splash.imageset/' + n)

p = A + 'Info.plist'
d = plistlib.load(open(p, 'rb'))
d['CFBundleDevelopmentRegion'] = 'ko'
d['CFBundleLocalizations'] = ['ko', 'en']
d['CFBundleDisplayName'] = APP_NAME
d['UIRequiredDeviceCapabilities'] = ['arm64']
d['UISupportedInterfaceOrientations'] = ['UIInterfaceOrientationPortrait']
d.pop('UISupportedInterfaceOrientations~ipad', None)
# 곡 등록 화면의 "파일 고르기"에 아이폰이 카메라 · 사진 메뉴를 함께 띄웁니다 — 설명이 없으면 앱이 멈추므로 넣어 둡니다
d['NSCameraUsageDescription'] = '곡 등록 때 저작권 증빙 서류를 사진으로 찍어 올릴 때 카메라를 씁니다.'
d['NSPhotoLibraryUsageDescription'] = '곡 등록 때 저작권 증빙 이미지를 골라 올릴 때 사진 보관함을 엽니다.'
d['NSMicrophoneUsageDescription'] = '파일 고르기 메뉴에서 동영상을 찍을 때 마이크를 씁니다. 첫소절은 녹음하지 않습니다.'
d['ITSAppUsesNonExemptEncryption'] = False      # 일반 HTTPS 만 씁니다 — 수출 규정 질문을 매번 건너뜁니다
plistlib.dump(d, open(p, 'wb'))

p = 'ios/App/App.xcodeproj/project.pbxproj'
s = open(p).read()
key = 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n'
if 'CODE_SIGN_ENTITLEMENTS' not in s:
    assert s.count(key) == 2, 'pbxproj 모양이 예상과 다릅니다'
    s = s.replace(key, key + '\t\t\t\tCODE_SIGN_ENTITLEMENTS = App/App.entitlements;\n')
s = s.replace('TARGETED_DEVICE_FAMILY = "1,2";', 'TARGETED_DEVICE_FAMILY = 1;')
open(p, 'w').write(s)
print(APP_NAME + ' iOS 설정을 넣었습니다 (' + APP_ID + ')')
