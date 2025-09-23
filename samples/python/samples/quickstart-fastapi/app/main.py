from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def read_root():
    return {"message": "Hello, world from FastAPI on Azure Container Apps"}

@app.get("/health")
async def health():
    return {"status": "ok"}