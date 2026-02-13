from fastapi import FastAPI

app = FastAPI()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/message")
def message():
    return {"message": "Hello from MiniShop API"}
