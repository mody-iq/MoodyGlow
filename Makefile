ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MoodyGlow
MoodyGlow_FILES = Tweak.x MoodyGlowOutline.m MoodyGlowColorExtractor.m MoodyGlowPrefs.m
MoodyGlow_CFLAGS = -fobjc-arc
MoodyGlow_FRAMEWORKS = UIKit CoreImage

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = MoodyGlowPrefs
MoodyGlowPrefs_FILES = MoodyGlowPrefsRootListController.m MoodyGlowPrefsAnimationsController.m
MoodyGlowPrefs_INSTALL_PATH = /Library/PreferenceBundles
MoodyGlowPrefs_CFLAGS = -fobjc-arc
MoodyGlowPrefs_LDFLAGS = -weak_framework Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard"
