const winston = require('winston');
require('winston-daily-rotate-file');

const { combine, timestamp, errors, json, colorize, printf } = winston.format;

const devFormat = printf(({ level, message, timestamp: ts, stack }) => {
  return `${ts} [${level}] ${stack || message}`;
});

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: combine(
    timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    errors({ stack: true }),
    process.env.NODE_ENV === 'production' ? json() : combine(colorize(), devFormat)
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.DailyRotateFile({
      filename:    'logs/error-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      level:       'error',
      maxFiles:    '14d',
      zippedArchive: true,
    }),
    new winston.transports.DailyRotateFile({
      filename:    'logs/combined-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxFiles:    '7d',
      zippedArchive: true,
    }),
  ],
  // Tangkap uncaught exception & unhandled rejection
  exceptionHandlers: [
    new winston.transports.DailyRotateFile({
      filename:    'logs/exceptions-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxFiles:    '14d',
    }),
  ],
  rejectionHandlers: [
    new winston.transports.DailyRotateFile({
      filename:    'logs/rejections-%DATE%.log',
      datePattern: 'YYYY-MM-DD',
      maxFiles:    '14d',
    }),
  ],
});

module.exports = logger;
