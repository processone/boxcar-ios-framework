
# Boxcar iOS SDK Changelog - v1.0.11
Boxcar Framework v.1.0.11 change the timing at which the method isPushEnabled is called on registration.
The goal is to make sure it is retrieved at a time where iOS has consistently set the push settings for the applications.