CC=/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/arm-apple-darwin10-gcc-4.0.1
CPP=/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/arm-apple-darwin10-g++-4.0.1
LD=$(CC)

SDKVER=4.2
SDK=/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$(SDKVER).sdk

LICENSE=LICENSED
LDFLAGS= -framework Foundation \
        -framework UIKit \
        -framework CoreFoundation \
        -framework CoreGraphics \
        -framework Preferences \
        -framework GraphicsServices \
        -L../Common \
        -L$(SDK)/usr/lib \
        -F$(SDK)/System/Library/Frameworks \
        -F$(SDK)/System/Library/PrivateFrameworks \
        -lsubstrate \
        -lobjc

CFLAGS= -I$(SDK)/var/include \
  -I/var/include \
  -I/var/include/gcc/darwin/4.0 \
  -I.. \
  -I"$(SDK)/usr/include" \
  -I"/Developer/Platforms/iPhoneOS.platform/Developer/usr/include" \
  -I"/Developer/Platforms/iPhoneOS.platform/Developer/usr/lib/gcc/arm-apple-darwin10/4.0.1/include" \
  -DDEBUG -Diphoneos_version_min=2.0

Name=ClockHide

all:	package

$(Name).dylib:	$(Name).o
		$(LD) $(LDFLAGS) -dynamiclib -init _$(Name)Init -o $@ $^
		ldid -S $@

$(Name)Settings:	$(Name)Settings.o
		$(LD) $(LDFLAGS) -lcommon -bundle -o $@ $^
		ldid -S $@

%.o:	%.mm
		$(CPP) -c $(CFLAGS) $< -o $@

clean:
		rm -f *.o $(Name).dylib $(Name)Settings
		rm -rf package

package:	$(Name).dylib $(Name)Settings
	mkdir -p package/DEBIAN
	mkdir -p package/Library/MobileSubstrate/DynamicLibraries
	mkdir -p package/Library/PreferenceLoader
	mkdir -p package/System/Library/PreferenceBundles
	cp $(Name).dylib package/Library/MobileSubstrate/DynamicLibraries
	cp $(Name).plist package/Library/MobileSubstrate/DynamicLibraries
	cp -r Preferences package/Library/PreferenceLoader/
	cp -r $(Name)Settings.bundle package/System/Library/PreferenceBundles/
	cp $(Name)Settings package/System/Library/PreferenceBundles/$(Name)Settings.bundle
	cp control package/DEBIAN
	find package -name .svn -print0 | xargs -0 rm -rf
	dpkg-deb -b package $(Name)_$(shell grep ^Version: control | cut -d ' ' -f 2).deb

