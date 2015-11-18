
# Boxcar iOS SDK Changelog - v1.0.10
Boxcar Framework v.1.0.10 fixes a minor bug where the push ID could not always be send when opening a notification.
The server would then extrapolate and add the tracking on the last push send, but that could lead to inconsistent statistics on that last push.