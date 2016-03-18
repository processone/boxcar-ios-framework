# Development

This project uses Pods.
Thus it is intended to be used from Boxcar.xcworkspace (and not directly xcodeproj).

Build number can be updated with the command:
/Applications/Xcode.app/Contents/Developer/usr/bin/agvtool -noscm next-version

Updating Marketing version:
/Applications/Xcode.app/Contents/Developer/usr/bin/agvtool new-marketing-version 1.0.7

# Building the framework for delivery

The framework is built from the Framework target.
Make sure active scheme target simulator and not device.

To generate all architecture, we need to build with archive. This is mandatory before we can release, otherwise app cannot be released from simulator.

If successful, a new DMG is generated in the package directory.

Check that the build contain all needed architectures before release:

	$ xcrun --sdk iphoneos lipo -info package/Boxcar.framework/Boxcar
	Architectures in the fat file: package/Boxcar.framework/Boxcar are: armv7 armv7s i386 x86_64 arm64 

# Package for Boxcar demo

Demo can be prepared for delivery with git archive command:
git archive HEAD --format=zip > boxcar-ios-demo-1.0.8.zip

# Troubleshooting
You can put the framework in debug mode (with more debug logging) with the command:
	[[Boxcar sharedInstance] dbm];
