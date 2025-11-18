from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import httpx
import asyncio

app = FastAPI(title="Network Policy Test API")

# Allow CORS for Streamlit
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

async def check_website(url: str) -> str:
    """Check if a website is reachable"""
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            response = await client.get(url, follow_redirects=True)
            return "OK" if response.status_code == 200 else f"Status: {response.status_code}"
    except Exception as e:
        return "Failed"

@app.get("/")
async def root():
    return {"message": "FastAPI Backend is running"}

@app.get("/allow")
async def allow_route():
    # Check connectivity to external sites
    results = await asyncio.gather(
        check_website("https://microsoft.com"),
        check_website("https://google.com"),
        check_website("https://amazon.com")
    )
    
    return {
        "message": "This request should be allowed",
        "connectivity": {
            "microsoft": results[0],
            "google": results[1],
            "amazon": results[2]
        }
    }

@app.get("/deny")
async def deny_route():
    return {"message": "This request should be denied"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
