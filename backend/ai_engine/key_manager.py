"""
key_manager.py — Multi-Key Load Balancer for Groq API

Implements round-robin key rotation across GROQ_API_KEY_1, _2, and _3
to bypass rate limits and enable high-concurrency 50-agent simulation.
"""

import os
import threading
from typing import Optional


class KeyManager:
    """
    Thread-safe round-robin key manager for Groq API keys.
    
    Automatically loads GROQ_API_KEY_1, GROQ_API_KEY_2, GROQ_API_KEY_3 from environment
    and provides get_next_key() method for load balancing across keys.
    """
    
    def __init__(self):
        self._keys = []
        self._current_index = 0
        self._lock = threading.Lock()
        
        # Load all available keys from environment
        for i in range(1, 4):  # Keys 1, 2, 3
            key = os.getenv(f"GROQ_API_KEY_{i}")
            if key:
                self._keys.append(key)
        
        if not self._keys:
            # Fallback to single key for backward compatibility
            fallback_key = os.getenv("GROQ_API_KEY")
            if fallback_key:
                self._keys.append(fallback_key)
        
        if not self._keys:
            raise ValueError(
                "No Groq API keys found. Please set GROQ_API_KEY_1, GROQ_API_KEY_2, "
                "and GROQ_API_KEY_3 in your environment variables."
            )
    
    def get_next_key(self) -> str:
        """
        Get the next API key in round-robin fashion.
        Thread-safe for concurrent access.
        
        Returns:
            str: The next Groq API key to use
        """
        with self._lock:
            key = self._keys[self._current_index]
            self._current_index = (self._current_index + 1) % len(self._keys)
            return key
    
    def get_key_count(self) -> int:
        """Get the total number of available keys."""
        return len(self._keys)
    
    def get_all_keys(self) -> list[str]:
        """Get all available keys (for debugging/monitoring)."""
        return self._keys.copy()