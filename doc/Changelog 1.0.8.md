
# Boxcar iOS SDK Changelog - v1.0.8
Boxcar Framework introduces a few changes to improve flexibility and limit the number of request to the server.

## Dynamic logging
You can now start the framework with a new option boolean: *kBXC\_LOGGING*. Set it to *@NO* for the production AppStore version. This is the default value.
Set it to *@YES* to get informations in logs during develoment phase.

## Uploading application version on server on device registration
The application version is send to server on device registration. It will server in the future to target push to a given version of the application.

## Send changes to server when you are done
This is a new call now needed to let the framework now you are ready to perform the server update. It means you set up all your parameters and are ready to send the data to the server. You can call it during app startup or in another place (for example in your settings controller) as update is only performed, if data have changed since the last update.
	[[Boxcar sharedInstance] sendDeviceParameters];