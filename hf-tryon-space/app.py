import os
import io
import base64
import json
import random
import string
import tempfile
from pathlib import Path

import requests as http_req
from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image

app = FastAPI(title="Alafif Virtual Try-On Proxy")

PUBLIC_SPACE_URL = "https://yisol-idm-vton.hf.space"
HF_TOKEN = os.environ.get("HF_TOKEN", "")


def _gen_session_hash():
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=10))


@app.get("/health")
async def health():
    return {"status": "ok", "mode": "proxy", "upstream": PUBLIC_SPACE_URL}


@app.post("/tryon")
async def virtual_tryon(
    person_image: UploadFile = File(...),
    garment_image_url: str = Form(...),
    category: str = Form("upper_body"),
    denoising_steps: int = Form(30, ge=1, le=100),
    seed: int = Form(42),
    auto_mask: bool = Form(True),
    crop: bool = Form(False),
):
    """
    Proxies try-on request to public IDM-VTON Space using Gradio 4.x SSE.
    One REST call: upload image → queue → poll → return base64.
    """
    try:
        # Save person image to temp file
        person_bytes = await person_image.read()
        suffix = Path(person_image.filename or "person.jpg").suffix or ".jpg"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            tmp.write(person_bytes)
            tmp_path = tmp.name

        print(f"📸 Person: {len(person_bytes)} bytes, category={category}")

        # Step 1: Upload person image
        with open(tmp_path, "rb") as f:
            upload_resp = http_req.post(
                f"{PUBLIC_SPACE_URL}/upload",
                files={"files": (Path(tmp_path).name, f, "image/jpeg")},
                timeout=30,
            )
        if upload_resp.status_code != 200:
            raise Exception(f"Upload failed: {upload_resp.status_code}")
        uploaded = upload_resp.json()
        person_path = uploaded[0] if uploaded else None
        if not person_path:
            raise Exception("No upload path returned")
        print(f"📤 Uploaded: {person_path}")

        # Step 2: Join queue
        session_hash = _gen_session_hash()
        headers = {"Content-Type": "application/json"}
        if HF_TOKEN:
            headers["Authorization"] = f"Bearer {HF_TOKEN}"

        join_payload = {
            "data": [
                {
                    "background": {"path": person_path, "meta": {"_type": "gradio.FileData"}},
                    "layers": [],
                    "composite": None,
                },
                garment_image_url,
                category,
                auto_mask,
                crop,
                denoising_steps,
                seed,
            ],
            "fn_index": 2,
            "trigger_id": 25,
            "session_hash": session_hash,
        }

        join_resp = http_req.post(
            f"{PUBLIC_SPACE_URL}/queue/join",
            headers=headers,
            json=join_payload,
            timeout=30,
        )
        if join_resp.status_code != 200:
            raise Exception(f"Queue join failed: {join_resp.status_code}")

        print(f"🔑 Queue joined: session={session_hash}")

        # Step 3: Poll SSE
        sse_url = f"{PUBLIC_SPACE_URL}/queue/data?session_hash={session_hash}"
        sse_resp = http_req.get(sse_url, headers=headers, stream=True, timeout=600)

        result_image = None
        for raw_line in sse_resp.iter_lines(decode_unicode=True):
            if not raw_line:
                continue
            if raw_line.startswith("data: "):
                json_str = raw_line[6:]
                try:
                    data = json.loads(json_str)
                except json.JSONDecodeError:
                    continue

                msg = data.get("msg", "")
                if msg == "process_completed":
                    output = data.get("output", {})
                    success = data.get("success", False)
                    if success and output:
                        result_data = output.get("data", [])
                        if result_data:
                            img = result_data[0]
                            url = None
                            if isinstance(img, dict):
                                url = img.get("url") or img.get("path", "")
                                if url and url.startswith("/"):
                                    url = f"{PUBLIC_SPACE_URL}{url}"
                            elif isinstance(img, str):
                                url = img
                                if not url.startswith("http"):
                                    url = f"{PUBLIC_SPACE_URL}/file={url}"

                            if url:
                                img_resp = http_req.get(url, timeout=30)
                                result_image = Image.open(io.BytesIO(img_resp.content))
                                break

                    if not success:
                        error = output.get("error", "") if output else ""
                        raise Exception(error or "Processing failed")

                elif msg == "process_starts":
                    print("⏳ Processing...")

        # Cleanup
        try:
            os.unlink(tmp_path)
        except:
            pass

        if result_image:
            buf = io.BytesIO()
            result_image.save(buf, format="PNG")
            b64 = base64.b64encode(buf.getvalue()).decode()
            return JSONResponse({
                "status": "success",
                "output": f"data:image/png;base64,{b64}",
            })

        raise Exception("No result received from model")

    except Exception as e:
        print(f"❌ Error: {e}")
        try:
            os.unlink(tmp_path)
        except:
            pass
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    return {
        "name": "Alafif Virtual Try-On Proxy",
        "description": "FastAPI proxy to public IDM-VTON Space via Gradio 4.x SSE",
        "version": "2.0.0",
        "endpoints": {
            "POST /tryon": "One-call try-on: person_image + garment_image_url + category → base64 PNG",
            "GET /health": "Health check",
        },
        "upstream": PUBLIC_SPACE_URL,
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 7860))
    uvicorn.run(app, host="0.0.0.0", port=port)
