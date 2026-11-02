module app;

import dlogg.buffered : BufferedLogger;
import dlogg.log : ILogger, LoggingLevel, logError, logInfo;
import dlogg.strict : StrictLogger;
import std.file : exists, remove, tempDir;
import std.path : buildPath;
import std.uuid : randomUUID;

void main()
{
    const path = buildPath(tempDir, "dlogg-api-" ~ randomUUID.toString);
    shared ILogger logger = new shared StrictLogger(path, StrictLogger.Mode.Append);
    auto delayed = new shared BufferedLogger(logger);
    scope(exit)
    {
        delayed.finalize();
        logger.finalize();
        if(exists(path)) remove(path);
    }

    logger.minOutputLevel = LoggingLevel.Muted;
    logger.logInfo("strict message");
    logger.logError("strict error");
    delayed.logInfo("buffered message");
}
