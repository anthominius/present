# Developer Tooling Notes

## What is `plutil`?

`plutil` is Apple's command-line tool for checking and converting property list files. Xcode projects use property lists for files like `Info.plist`, entitlements, and parts of `.xcodeproj` metadata.

In this project, `plutil -lint` is useful as a quick syntax check. It does not prove the app will run, but it does catch malformed XML or project metadata before Xcode tries to open or build it.
