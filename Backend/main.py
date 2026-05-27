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


async def fetch(url: str) -> BeautifulSoup:
    try:
        async with httpx.AsyncClient(headers=HEADERS, follow_redirects=True, timeout=15) as client:
            response = await client.get(url)
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Failed to reach page: {e}")
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Page returned an error")
    return BeautifulSoup(response.text, "html.parser")


def parse_comics(soup: BeautifulSoup) -> list:
    comics = []
    post_list = soup.find("div", class_="post-list-posts")
    if not post_list:
        return comics

    for article in post_list.find_all("article"):
        # Skip news/announcement articles
        if any("category-news" in c for c in article.get("class", [])):
            continue

        comic_url = cover_image = None
        img_div = article.find("div", class_="post-header-image")
        if img_div:
            a = img_div.find("a")
            if a:
                comic_url = a.get("href")
            img = img_div.find("img")
            if img:
                cover_image = img.get("src")

        title_el = article.find("h1", class_="post-title")
        title = title_el.get_text(strip=True) if title_el else None

        category_el = article.find("a", class_="post-category")
        publisher = category_el.get_text(strip=True) if category_el else None

        year = size = None
        for p in article.find_all("p"):
            text = p.get_text(" ", strip=True)
            if "Year" in text or "Size" in text:
                m = re.search(r'Year\s*:\s*([^|]+)', text)
                if m:
                    year = m.group(1).strip()
                m = re.search(r'Size\s*:\s*([\d.]+\s*(?:MB|GB|KB))', text, re.IGNORECASE)
                if m:
                    size = m.group(1).strip()
                break

        time_el = article.find("time")
        date = time_el.get("datetime") if time_el else None

        comics.append({
            "title": title,
            "publisher": publisher,
            "url": comic_url,
            "cover_image": cover_image,
            "year": year,
            "size": size,
            "date": date,
        })

    return comics


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/testConnection")
async def test_connection():
    return {
        "status": "ok",
        "message": "ZAPPAGE backend is alive",
        "timestamp": time.time(),
    }


@app.get("/comics/all")
async def list_all_comics(page: int = Query(1, ge=1)):
    url = f"{COMICS_BASE_URL}/" if page == 1 else f"{COMICS_BASE_URL}/page/{page}/"
    soup = await fetch(url)
    return {"page": page, "comics": parse_comics(soup)}


@app.get("/comics/dc")
async def list_dc_comics(page: int = Query(1, ge=1)):
    url = f"{COMICS_BASE_URL}/cat/dc/" if page == 1 else f"{COMICS_BASE_URL}/cat/dc/page/{page}/"
    soup = await fetch(url)
    return {"page": page, "comics": parse_comics(soup)}


@app.get("/comics/marvel")
async def list_marvel_comics(page: int = Query(1, ge=1)):
    url = f"{COMICS_BASE_URL}/cat/marvel/" if page == 1 else f"{COMICS_BASE_URL}/cat/marvel/page/{page}/"
    soup = await fetch(url)
    return {"page": page, "comics": parse_comics(soup)}


@app.get("/comic/scrape")
async def scrape_comic(url: str = Query(..., description="Full getcomics.org page URL")):
    soup = await fetch(url)

    # Title
    title = None
    h1 = soup.find("h1", class_="post-title") or soup.find("h1")
    if h1:
        title = h1.get_text(strip=True)
    elif soup.title:
        title = soup.title.get_text(strip=True).split(" - ")[0].strip()

    # Cover image
    cover_image = None
    cover_div = soup.find("div", class_="cover-background")
    if cover_div:
        style = cover_div.get("style", "")
        m = re.search(r"url\(['\"]?(https?://[^'\")\s]+)['\"]?\)", style)
        if m:
            cover_image = m.group(1)

    # Description
    description = None
    post_contents = soup.find("section", class_="post-contents")
    if post_contents:
        p = post_contents.find("p", style=lambda s: s and "justify" in s)
        if p:
            description = p.get_text(strip=True)

    # Metadata
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

    # Download link
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
