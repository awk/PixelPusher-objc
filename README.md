PixelPusher-objc
================

Objective C library to interact with PixelPushers

This is a port of the java library for talking to PixelPushers - https://github.com/robot-head/PixelPusher-java

It follows fairly closely the architecture & design of the java library. Utilizing threads for detection and pixel pushing.
Minor changes have been made to the API to support iOS/Mac OS X types for such things as colors, and to interact better with run loops as opposed to java threads.
