"""Caching utilities for API responses"""

from functools import lru_cache, wraps
from typing import Optional, Callable
import hashlib
import json
import time


class SimpleCache:
    """Simple in-memory cache with TTL support"""

    def __init__(self, ttl: int = 300):
        """
        Initialize cache.

        Args:
            ttl: Time to live in seconds (default: 5 minutes)
        """
        self.ttl = ttl
        self._cache = {}

    def get(self, key: str) -> Optional[any]:
        """Get cached value"""
        if key in self._cache:
            value, timestamp = self._cache[key]
            if time.time() - timestamp < self.ttl:
                return value
            else:
                del self._cache[key]
        return None

    def set(self, key: str, value: any):
        """Set cached value"""
        self._cache[key] = (value, time.time())

    def clear(self):
        """Clear all cached values"""
        self._cache.clear()

    def delete(self, key: str):
        """Delete specific cached value"""
        if key in self._cache:
            del self._cache[key]


# Global cache instance
_cache = SimpleCache(ttl=300)


def cache_response(ttl: int = 300):
    """
    Decorator to cache function responses.

    Args:
        ttl: Time to live in seconds
    """
    def decorator(func: Callable):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Create cache key from function name and arguments
            cache_key = _create_cache_key(func.__name__, args, kwargs)

            # Check cache
            cached_value = _cache.get(cache_key)
            if cached_value is not None:
                return cached_value

            # Execute function
            result = await func(*args, **kwargs)

            # Cache result
            _cache.set(cache_key, result)

            return result

        return wrapper
    return decorator


def _create_cache_key(func_name: str, args: tuple, kwargs: dict) -> str:
    """Create cache key from function name and arguments"""
    key_data = {
        "func": func_name,
        "args": str(args),
        "kwargs": sorted(kwargs.items())
    }
    key_str = json.dumps(key_data, sort_keys=True)
    return hashlib.md5(key_str.encode()).hexdigest()


def clear_cache():
    """Clear all cached values"""
    _cache.clear()


def invalidate_cache(pattern: str):
    """Invalidate cache entries matching pattern"""
    # For simple implementation, just clear all
    _cache.clear()
