dlogg
=====

[![Build Status](https://travis-ci.org/NCrashed/dlogg.svg?branch=master)](https://travis-ci.org/NCrashed/dlogg)

[Docs](http://ncrashed.github.io/dlogg/index.html)

Library that consilidates logging utilites according following goals:
* Scalability
* Nothrow and stable work under high loads and concurrency
* Working with daemons
* Log rotating 
* Lazy logging including buffered loggers
* Customizeable messages and logging levels
* Support for colorful output via [d-colorize](https://github.com/yamadapc/d-colorize) [Optional]

Installing
===========
Add following in your dub package file:
```Json
"dependencies": {
  "dlogg": ">=0.1.0"
}
```

Examples:
========
Each logger in the package implements `dlogg.ILogger` interface and forced to be shared between threads. There are 5 different styles of logg messages:
```D
enum LoggingLevel
{
    Notice,
    Warning,
    Debug,
    Fatal,
    Muted // Used only to mute all writing to console
}
```

So, to put message in log you can use:
```D
  void ILogger.log(lazy string message, LoggingLevel level) shared;
```
Or one of handy wrappers:
```D
  final nothrow shared
  {
    void logDebug(E...)(E args) shared @trusted; // not lazy
    void ILogger.logInfo(lazy string message);
    void ILogger.logWarning(lazy string message);
    void ILogger.logError(lazy string message);
  }
```
Note that major logging funcs are lazy and we don't have overhead while logg call isn't needed but in strict version D performs string concatinations.

And finally full example:
```D
   shared ILogger logger = new StrictLogger("my_awesome_log.log");
   logger.minOutputLevel = LoggingLevel.Warning; // info msgs won't be printed in console 
   logger.logInfo("Info message!");
   logger.logError("Error message!");
   logger.logDebug("Debug message!");
```
Output file:
```
[2014-04-06T19:50:22.8193333]:Notice: Notice msg!
[2014-04-06T19:50:22.819406]:Warning: Warning msg!
[2014-04-06T19:50:22.8194323]:Debug: Debug msg!
[2014-04-06T19:50:22.8194548]:Error: Fatal msg!
```

`minOutputLevel` property controls which message types should be printed in console. `LoggingLevel.Muted` is used to create daemon loggers that don't try to write into stdout.

Buffered logger
===============
In many cases (for instance, unittesting) we don't want log output just in time. Buffered logger adds control when messages would be written into wrapped log. Example:
```D
   auto delayed = new shared BufferedLogger(logger); // wrapping a logger
   scope(exit) delayed.finalize(); // write down information in wrapped logger
   scope(failure) delayed.minOutputLevel = LoggingLevel.Notice; // if failed, spam in console
   delayed.logNotice("Hello!");

   // do something that can fail
```

Log rotating
============
`StrictLogger.reload` function checks if the log file is exists at specified location and if can't find it, recreates the file and continues write into it. Useful for [logrotate](http://linuxcommand.org/man_pages/logrotate8.html) utility. GNU/Linux system checks file identity by inode, that doesn't change while renaming. Thus after renaming the file at location log continues write into the renamed file. The call to the reload method force splitting log into two parts.

Custom styles
=============
Since `v0.2.0` custom styled logs are available. Consider how standart logger is implemented:
```D
alias StrictLogger = StyledStrictLogger!(LoggingLevel
                , LoggingLevel.Debug,   "Debug: %1$s",   "[%2$s]: Debug: %1$s"
                , LoggingLevel.Notice,  "Notice: %1$s",  "[%2$s]: Notice: %1$s"
                , LoggingLevel.Warning, "Warning: %1$s", "[%2$s]: Warning: %1$s"
                , LoggingLevel.Fatal,   "Fatal: %1$s",   "[%2$s]: Fatal: %1$s"
                , LoggingLevel.Muted,   "",              ""
                );
```

`StyledStrictLogger(StyleEnum, US...)` is template class that implements `IStyledLogger!StyleEnum` interface. First template parameter is used to define your logging level enum (also `StyleEnum` values ordering is important for muting features).

Last template parameters have format of list of triples (`StyleEnum` value, `string`, `string`). Style value
defines for which logging level following format strings are. First format string is used
for console output, the second one is for file output.

Format strings could use two arguments: `'%1$s'` is message that is passed to a logger and
`'%2$s'` is current time string. Formatting is handled by [std.format](http://dlang.org/phobos/std_format.html) module. 

Now example of custom logger:
```D
enum MyLevel
{
    Error,
    Debug
}

mixin generateStyle!(MyLevel
            , MyLevel.Debug,   "Debug: %1$s",   "[%2$s] Debug: %1$s"
            , MyLevel.Error,   "Fatal: %1$s",   "[%2$s] Fatal: %1$s"
            );
```

Colored output
===============
You can use [d-colorize](https://github.com/yamadapc/d-colorize) package to color your styled logger:
```D
        alias StrictLogger = StyledStrictLogger!(LoggingLevel
                        , LoggingLevel.Debug,   "Debug:".color(fg.light_magenta) ~ " %1$s",   "[%2$s]: Debug: %1$s"
                        , LoggingLevel.Notice,  "Notice:".color(fg.light_green) ~ " %1$s",  "[%2$s]: Notice: %1$s"
                        , LoggingLevel.Warning, "Warning:".color(fg.light_yellow) ~ " %1$s", "[%2$s]: Warning: %1$s"
                        , LoggingLevel.Fatal,   "Fatal:".color(fg.light_red) ~ " %1$s",   "[%2$s]: Fatal: %1$s"
                        , LoggingLevel.Muted,   "",              ""
                        );
```

And to use colorized version of default loggers add following to your `dub.json`:
```JSON
{
	...
	"dependencies": {
		"dlogg": ">=0.3.2"
	},
	"subConfigurations": {
		"dlogg": "colorized"
	}
}
```
