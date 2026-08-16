"""
Demonstration Video Streaming and Metadata API (/api/v1/demo).
Provides official Google Drive demo video metadata, HTTP Byte-Range video streaming for Safari/iOS/Chrome,
and fallback playback support for the Liquid Glass presentation modal and Simulator.
"""

import os
from pathlib import Path
from fastapi import APIRouter, Request, HTTPException, status
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from app.config import DEMO_VIDEO_URL

demo_router = APIRouter(prefix="/demo", tags=["Demonstration Video"])

# Path to the locally cached high-quality official demo video
backend_root = Path(__file__).resolve().parent.parent.parent
workspace_root = backend_root.parent

POSSIBLE_DEMO_PATHS = [
    workspace_root / "web" / "assets" / "metalcraft_demo.mp4",
    backend_root / "web" / "assets" / "metalcraft_demo.mp4",
    Path("web/assets/metalcraft_demo.mp4").resolve(),
]


def get_demo_video_path() -> Path:
    for p in POSSIBLE_DEMO_PATHS:
        if p.exists():
            return p
    return POSSIBLE_DEMO_PATHS[0]


@demo_router.get("/info")
async def get_demo_info():
    """Returns canonical demonstration video metadata and playable endpoints."""
    demo_path = get_demo_video_path()
    exists = demo_path.exists()
    size = demo_path.stat().st_size if exists else 0
    return {
        "title": "MetalCraft: AI Directs. Metal Crafts.",
        "tagline": "iOS + Apple Metal GPU Media Production Platform",
        "demoVideoUrl": DEMO_VIDEO_URL,
        "playableStreamUrl": "/api/v1/demo/stream",
        "staticUrl": "/static/assets/metalcraft_demo.mp4",
        "available": exists,
        "fileSizeBytes": size,
        "format": "mp4",
        "codec": "H.264 / AAC",
        "aspectRatio": "9:16"
    }


@demo_router.get("/stream")
@demo_router.get("/video")
async def stream_demo_video(request: Request):
    """
    Streams the official MetalCraft demonstration video with full HTTP Byte Range support
    (206 Partial Content) to ensure smooth scrubbing, seeking, and audio playback on
    macOS Safari, iPad Safari, iPhone Safari, and Chrome.
    """
    demo_path = get_demo_video_path()
    if not demo_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Demonstration video file is currently unavailable."
        )

    file_size = demo_path.stat().st_size
    range_header = request.headers.get("Range")

    if not range_header:
        return FileResponse(
            str(demo_path),
            media_type="video/mp4",
            headers={
                "Accept-Ranges": "bytes",
                "Content-Length": str(file_size),
                "Cache-Control": "public, max-age=86400",
                "Content-Disposition": "inline; filename=\"metalcraft_demo.mp4\""
            }
        )

    # Parse byte range header, e.g. "bytes=0-1048575"
    try:
        byte_range = range_header.replace("bytes=", "").split("-")
        start = int(byte_range[0])
        end = int(byte_range[1]) if len(byte_range) > 1 and byte_range[1] else file_size - 1
    except Exception:
        start = 0
        end = file_size - 1

    if start >= file_size or end >= file_size:
        return JSONResponse(
            status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
            content={"detail": "Requested range not satisfiable"}
        )

    chunk_size = (end - start) + 1

    def iter_file():
        with open(DEMO_VIDEO_PATH, "rb") as f:
            f.seek(start)
            bytes_left = chunk_size
            while bytes_left > 0:
                read_size = min(65536, bytes_left)
                data = f.read(read_size)
                if not data:
                    break
                bytes_left -= len(data)
                yield data

    headers = {
        "Content-Range": f"bytes {start}-{end}/{file_size}",
        "Accept-Ranges": "bytes",
        "Content-Length": str(chunk_size),
        "Content-Type": "video/mp4",
        "Cache-Control": "public, max-age=86400"
    }

    return StreamingResponse(iter_file(), status_code=206, headers=headers)
