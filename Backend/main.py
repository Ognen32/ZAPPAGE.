from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import time

app = FastAPI(title="ZAPPAGE API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/testConnection")
async def test_connection():
    return {
        "status": "ok",
        "message": "ZAPPAGE backend is alive",
        "timestamp": time.time(),
    }
