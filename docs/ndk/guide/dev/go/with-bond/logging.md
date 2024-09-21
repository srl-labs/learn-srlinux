# Logging

Application logs are essential for debugging, troubleshooting, and monitoring. NDK apps are no exception. In this section we explain how we set up logging for NDK applications based on the `greeter` example.

There are three different ways how NDK app can log messages:

1. By creating its own log file.
2. By logging to the stdout/stderr.
3. By logging to the syslog.

## Logging to a file

Logging to a file is the most common way to log messages. NDK app can create a file by the `/var/log/<app-name>/<app-name>.log` path and write messages to it.

It is up to the developer to decide what messages to log and how to format them. It is also up to the developer to decide when to rotate the log file to not overflow the disk space and reduce the frequency of the disk writes if the log location is on a flash drive.

## Logging to stdout/stderr

Logging to stdout/stderr is the simplest way to log messages. When NDK app is registered with SR Linux, any `fmt.PrintX()` or `log.XXX` call will write the message to the `/var/log/srlinux/<app-name>.log` file.

Note, that this log file is not managed by SR Linux and is not rotated automatically. Therefore, this log destination is only suitable for debugging and troubleshooting, but not for production.

## Logging to Syslog

Syslog is the default way to log messages in SR Linux. NDK app can write messages to syslog with the needed severity/facility and SR Linux will take care of the rest.

## Setting up logging

In the greeter app the logging is set up in the `main()` function:

```{.go linenums="1" hl_lines="18" title="main.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:pkg-main"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:pkg-main-vars"
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:main"
```

We create and configure the logger instance in the `setupLogger()` function:

```{.go linenums="1" title="main.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:setup-logger"
```

Our logger is implemented by the [zerolog](https://github.com/rs/zerolog) logger library. It is a very powerful and fast logger that supports structured logging and can write messages to different destinations.

We configure our logger to write to two destinations:

1. To a file with log rotation policy in the structured JSON format when the application is running in production mode.
2. To `stdout` with the `console` format when the application is running in debug mode.
3. To syslog facility

With this setup we show the three modes of logging that can be used by the NDK applications.

### Stdout log

To make sure we log to `stdout` only when the app is running in debug mode, we check if `/tmp/.ndk-dev-mode` file exists on a filesystem. If it does, we set the logger to write to stdout. Developers can add this file on a filesystem when they need to see the logs in the console format.

When you run the greeter app using the `run.sh` script, the `/tmp/.ndk-dev-mode` file is created automatically.

Once the lab is running, you can see the logs in the console format by opening the `./logs/srl/stdout/greeter.log` file relative to the apps' repository root:

```
❯ tail -5 logs/srl/stdout/greeter.log
2023-12-05 09:37:13 UTC INF Fetching SR Linux uptime value
2023-12-05 09:37:14 UTC INF GetResponse: notification:{timestamp:1701769034084642836  update:{path:{elem:{name:"system"}  elem:{name:"information"}  elem:{name:"last-booted"}}  val:{string_val:"2023-12-05T09:34:49.769Z"}}}
2023-12-05 09:37:14 UTC INF updating: .greeter: {"name":"me","greeting":"👋 Hi me, I am SR Linux and my uptime is 108h33m7s!"}
2023-12-05 09:37:14 UTC INF Telemetry Request: state:{key:{js_path:".greeter"}  data:{json_content:"{\"name\":\"me\",\"greeting\":\"👋 Hi me, I am SR Linux and my uptime is 108h33m7s!\"}"}}
2023-12-05 09:37:14 UTC INF Telemetry add/update status: kSdkMgrSuccess, error_string: ""
```

### File log

The default and "always-on" logging destination the greeter app uses is the file log. The log file destination is configured with the [lumberjack](https://github.com/natefinch/lumberjack) library that provides log rotation functionality.

The log file location is set to `/var/log/greeter/greeter.log` and log format is set to JSON (default for the `zerolog` library). This format is ideal for use with logtail/fluentd/filebeat and other log collectors to push logs to central log storage.

```
❯ tail -5 logs/greeter/greeter.log
{"level":"info","time":"2023-12-05T09:37:13Z","message":"Fetching SR Linux uptime value"}
{"level":"info","time":"2023-12-05T09:37:14Z","message":"GetResponse: notification:{timestamp:1701769034084642836  update:{path:{elem:{name:\"system\"}  elem:{name:\"information\"}  elem:{name:\"last-booted\"}}  val:{string_val:\"2023-12-05T09:34:49.769Z\"}}}"}
{"level":"info","time":"2023-12-05T09:37:14Z","message":"updating: .greeter: {\"name\":\"me\",\"greeting\":\"👋 Hi me, I am SR Linux and my uptime is 108h33m7s!\"}"}
{"level":"info","time":"2023-12-05T09:37:14Z","message":"Telemetry Request: state:{key:{js_path:\".greeter\"}  data:{json_content:\"{\\\"name\\\":\\\"me\\\",\\\"greeting\\\":\\\"👋 Hi me, I am SR Linux and my uptime is 108h33m7s!\\\"}\"}}"}
{"level":"info","time":"2023-12-05T09:37:14Z","message":"Telemetry add/update status: kSdkMgrSuccess, error_string: \"\""}
```

### Syslog

As mentioned above, syslog is the default way to log messages in SR Linux. NDK app can write messages to syslog with the needed severity/facility/tag and SR Linux will manage those logs via its [logging](https://documentation.nokia.com/srlinux/23-10/books/config-basics/logg.html) subsystem.

To setup syslog logging for the greeter app, we use the `github.com/RackSec/srslog` package in the `setupLogger()` function:

```{.go title="main.go"}
--8<-- "https://raw.githubusercontent.com/srl-labs/ndk-greeter-go/main/main.go:syslog-logger"
```

Our app will write messages to the `local7` facility[^1] with the `ndk-greeter-go` tag. The tag is later used by the logging subsystem to route messages to the correct log file.

Finally, we add our syslog writer to the multiwriter that is used by zerolog logger to write to multiple destinations.

#### SR Linux configuration

Just setting up the syslog writer in the app is not enough to make it work. We also need to configure syslog on SR Linux to accept messages from the app and route them to the correct log file.

First, we need to create a new log filter that will match on the Syslog tag we configured our app to use:

```srl
set / system logging filter greeter-app tag ndk-greeter-go
```

Then we need to create a new log destination that will write "filtered by tag" messages from the app to the log file. Starting from the `/system logging` context:

```srl
--{ + candidate shared default }--[ system logging ]--
A:greeter# file greeter

--{ + candidate shared default }--[ system logging file greeter ]--
A:greeter# rotate 3

--{ +* candidate shared default }--[ system logging file greeter ]--
A:greeter# size 1M

--{ +* candidate shared default }--[ system logging file greeter ]--
A:greeter# filter [ greeter-app ]

--{ +* candidate shared default }--[ system logging file greeter ]--
A:greeter# commit now
All changes have been committed. Leaving candidate mode.
```

We configure a new `file` destination with the `greeter` name and set the log rotation policy to rotate the log file when it reaches 1MB in size and keep no more than 3 files on disk. Then we set the filter to match on the `greeter-app` tag.

/// note | default file directory
When `directory` is not set under `/system logging file <name>` context, the default value of `/var/log/srlinux/file` is used.
///

Finally, we commit the changes and leave the candidate mode.

Now when our app logs anything, besides the `stdout` and manually set up file logs, the messages will be routed to the syslog and via syslog to the `/var/log/srlinux/file/greeter` file. Besides file destination, syslog messages can be routed to the console, remote syslog server, buffer, or any other supported destination.

```bash
❯ tail -5 logs/srl/file/greeter 
2023-12-06T20:42:34.826386+00:00 greeter ndk-greeter-go[9185]: {"level":"info","caller":"/root/srl-labs/ndk-greeter-go/greeter/app.go:128","time":"2023-12-06T20:42:34Z","message":"Received full config"}
2023-12-06T20:42:34.826647+00:00 greeter ndk-greeter-go[9185]: {"level":"info","caller":"/root/srl-labs/ndk-greeter-go/greeter/config.go:123","time":"2023-12-06T20:42:34Z","message":"No name configured, deleting state"}
2023-12-06T20:42:34.827043+00:00 greeter ndk-greeter-go[9185]: {"level":"info","caller":"/root/srl-labs/ndk-greeter-go/greeter/state.go:32","time":"2023-12-06T20:42:34Z","message":"updating: .greeter: {}"}
2023-12-06T20:42:34.827978+00:00 greeter ndk-greeter-go[9185]: {"level":"info","caller":"/root/srl-labs/ndk-greeter-go/greeter/state.go:41","time":"2023-12-06T20:42:34Z","message":"Telemetry Request: state:{key:{js_path:\".greeter\"}  data:{json_content:\"{}\"}}"}
2023-12-06T20:42:34.829257+00:00 greeter ndk-greeter-go[9185]: {"level":"info","caller":"/root/srl-labs/ndk-greeter-go/greeter/state.go:49","time":"2023-12-06T20:42:34Z","message":"Telemetry add/update status: kSdkMgrSuccess, error_string: \"\""}
```

[^1]: Native SR Linux apps write to `local6` facility
