from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os
import time
import re
import httpx
from bs4 import BeautifulSoup

load_dotenv()
COMICS_BASE_URL = os.getenv("COMICS_BASE_URL")

app = FastAPI(title="ZAPPAGE API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    )
}


@app.get("/testConnection")
async def test_connection():
    return {
        "status": "ok",
        "message": "ZAPPAGE backend is alive",
        "timestamp": time.time(),
    }


@app.get("/comic/scrape")
async def scrape_comic(url: str = Query(..., description="Full getcomics.org page URL")):
    try:
        async with httpx.AsyncClient(headers=HEADERS, follow_redirects=True, timeout=15) as client:
            response = await client.get(url)
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Failed to reach page: {e}")

    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Page returned an error")

    soup = BeautifulSoup(response.text, "html.parser")

    # --- Title ---
    title = None
    h1 = soup.find("h1", class_="post-title") or soup.find("h1")
    if h1:
        title = h1.get_text(strip=True)
    elif soup.title:
        title = soup.title.get_text(strip=True).split(" - ")[0].strip()

    # --- Cover image ---
    cover_image = None
    cover_div = soup.find("div", class_="cover-background")
    if cover_div:
        style = cover_div.get("style", "")
        m = re.search(r"url\(['\"]?(https?://[^'\")\s]+)['\"]?\)", style)
        if m:
            cover_image = m.group(1)

    # --- Description (first justified paragraph inside post-contents) ---
    description = None
    post_contents = soup.find("section", class_="post-contents")
    if post_contents:
        p = post_contents.find("p", style=lambda s: s and "justify" in s)
        if p:
            description = p.get_text(strip=True)

    # --- Metadata (Language, Format, Year, Size) ---
    size = language = year = image_format = None
    for p in soup.find_all("p"):
        text = p.get_text(" ", strip=True)
        if "Size" in text:
            m = re.search(r'Size\s*:\s*([\d.]+\s*(?:MB|GB|KB))', text, re.IGNORECASE)
            if m:
                size = m.group(1).strip()
            m = re.search(r'Language\s*:\s*([^|]+)', text)
            if m:
                language = m.group(1).strip()
            m = re.search(r'Year\s*:\s*([^|]+)', text)
            if m:
                year = m.group(1).strip()
            m = re.search(r'Image Format\s*:\s*([^|]+)', text)
            if m:
                image_format = m.group(1).strip()
            break

    # --- Download link (main "DOWNLOAD NOW" button only) ---
    download_url = None
    btn_center = soup.find("div", class_="aio-button-center")
    if btn_center:
        a = btn_center.find("a", class_="aio-red")
        if a and a.get("href"):
            download_url = a["href"]

    return {
        "title": title,
        "cover_image": cover_image,
        "description": description,
        "size": size,
        "language": language,
        "year": year,
        "image_format": image_format,
        "download_url": download_url,
        "downloadable": download_url is not None,
        "message": None if download_url else "No download available for this comic.",
    }
