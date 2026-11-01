dlogg
=====

[![CI](https://github.com/NCrashed/dlogg/actions/workflows/ci.yml/badge.svg)](https://github.com/NCrashed/dlogg/actions/workflows/ci.yml)

[API modules](source/dlogg/)

Library that consolidates logging utilities with the following goals:
* Scalability
* Nothrow operation under high loads and concurrency
* Working with daemons
* Log rotation
* Lazy logging including buffered loggers
* Customizable messages and logging levels
* Optional colorful output via [d-colorize](https://github.com/yamadapc/d-colorize)

Installing
===========
Add following in your dub package file:
```Json
"dependencies": {
  "dlogg": "~>0.4.2"
}
```

Development with Nix
====================

The repository includes a pinned development shell and reproducible build:

```console
nix develop
dub test --config=default
dub test --config=colorized
nix flake check
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
The single-message wrappers are lazy. The message expression is evaluated at
most once, and only when either console or file output accepts its level.

And finally full example:
```D
   shared ILogger logger = new shared StrictLogger("my_awesome_log.log");
   scope(exit) logger.finalize();
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
[2014-04-06T19:50:22.8194548]:Fatal: Fatal msg!
```

`minOutputLevel` property controls which message types should be printed in console. `LoggingLevel.Muted` is used to create daemon loggers that don't try to write into stdout.

`StrictLogger` uses `Mode.Rewrite` by default. Pass `StrictLogger.Mode.Append`
when existing log contents must survive application restarts.

Buffered logger
===============
In many cases (for instance, unittesting) we don't want log output just in time. Buffered logger adds control when messages would be written into wrapped log. Example:
```D
   auto delayed = new shared BufferedLogger(logger); // wrapping a logger
   scope(exit) delayed.finalize(); // write down information in wrapped logger
   scope(failure) delayed.minOutputLevel = LoggingLevel.Notice; // if failed, spam in console
   delayed.logInfo("Hello!");

   // do something that can fail
```

Log rotating
============
`StrictLogger.reload()` always reopens the configured path in append mode. This
switches output to the replacement file whether logrotate only renamed the old
file or also created the replacement before notifying the application.

`reload()` opens files, allocates memory, and locks the logger, so it must not be
called directly from a POSIX signal handler. The handler should only set an
atomic flag; normal application flow can then perform the reload safely:

```D
version (Posix)
{
    import core.atomic : atomicLoad, atomicStore;
    import core.stdc.signal : sig_atomic_t, signal;
    import core.sys.posix.signal : SIGUSR1;

    shared sig_atomic_t reloadRequested;

    extern(C) void requestReload(int) nothrow @nogc
    {
        atomicStore(reloadRequested, 1);
    }

    void installReloadHandler()
    {
        signal(SIGUSR1, &requestReload);
    }

    void processReload(shared ILogger logger)
    {
        if (atomicLoad(reloadRequested) != 0)
        {
            atomicStore(reloadRequested, 0);
            logger.reload();
        }
    }
}
```

Custom styles
=============
Since `v0.2.0` custom styled logs are available. Consider how the standard logger is implemented:
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
		"dlogg": "~>0.4.2"
	},
	"subConfigurations": {
		"dlogg": "colorized"
	}
}
```

Custom time formatting
======================

You can pass function or delegate to logger style to control how time is formatted. The function should have
`string` return type and parameters of `(DistType t, SysTime time)` where `t` refers to distination (file or console)
where message is printed to and `time` is a time value that should be converted to string by your function.

Example of usage:
```D
    import dlogg.strict;
    import dlogg.style;
    import std.datetime;
    
    string myTimeFormatting(DistType t, SysTime time)
    {
        final switch(t)
        {
            case(DistType.Console): return time.toSimpleString();
            case(DistType.File): return time.toISOExtString();
        }
    }
    
    alias MyLogger = StyledStrictLogger!(LoggingLevel, myTimeFormatting
                    , LoggingLevel.Debug,   "Debug: %1$s",   "[%2$s]: Debug: %1$s"
                    , LoggingLevel.Notice,  "Notice: %1$s",  "[%2$s]: Notice: %1$s"
                    , LoggingLevel.Warning, "Warning: %1$s", "[%2$s]: Warning: %1$s"
                    , LoggingLevel.Fatal,   "Fatal: %1$s",   "[%2$s]: Fatal: %1$s"
                    , LoggingLevel.Muted,   "",              ""
                    );
    
    auto logger = new shared MyLogger("TimeFormatTestLog");
    scope(exit) logger.finalize();
    
    logger.logInfo("Msg1");
    logger.logWarning("Msg2");
    logger.logError("Msg2");
```
