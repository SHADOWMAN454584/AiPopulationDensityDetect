"""
CrowdSense AI — Vercel Serverless Entry Point
This file re-exports the FastAPI app for Vercel's Python runtime.
"""

import sys
import os

# Ensure the parent directory is in the path so main.py can be imported
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app

# Vercel expects a variable called `app` or `handler`
# FastAPI/Starlette apps work natively with Vercel's Python runtime
