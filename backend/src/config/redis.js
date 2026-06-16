const logger = require('./logger');

let redisClient;
let useMemoryCache = true;
const memoryCache = new Map();

try {
  const Redis = require('ioredis');
  const host = process.env.REDIS_HOST || '127.0.0.1';
  const port = process.env.REDIS_PORT || 6379;
  
  redisClient = new Redis({
    host,
    port,
    lazyConnect: true,
    maxRetriesPerRequest: 1,
  });

  redisClient.on('connect', () => {
    logger.info(`[Redis] Terhubung ke Redis server ${host}:${port}`);
    useMemoryCache = false;
  });

  redisClient.on('error', (err) => {
    logger.warn('[Redis] Gagal terhubung ke Redis. Menggunakan in-memory cache.');
    useMemoryCache = true;
  });

  redisClient.connect().catch(() => {
    useMemoryCache = true;
  });
} catch (e) {
  logger.warn('[Redis] package ioredis tidak tersedia atau gagal setup. Menggunakan in-memory cache.');
  useMemoryCache = true;
}

const get = async (key) => {
  if (useMemoryCache) {
    const val = memoryCache.get(key);
    if (!val) return null;
    if (val.expireAt && Date.now() > val.expireAt) {
      memoryCache.delete(key);
      return null;
    }
    return val.data;
  }
  try {
    return await redisClient.get(key);
  } catch (err) {
    return null;
  }
};

const set = async (key, value, ttlSeconds = 3600) => {
  if (useMemoryCache) {
    memoryCache.set(key, {
      data: value,
      expireAt: Date.now() + (ttlSeconds * 1000),
    });
    return;
  }
  try {
    await redisClient.set(key, value, 'EX', ttlSeconds);
  } catch (err) {
    // ignore
  }
};

const del = async (key) => {
  if (useMemoryCache) {
    memoryCache.delete(key);
    return;
  }
  try {
    await redisClient.del(key);
  } catch (err) {
    // ignore
  }
};

module.exports = { get, set, del };
