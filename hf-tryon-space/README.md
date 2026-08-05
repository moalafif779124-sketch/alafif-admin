---
title: Alafif Virtual Try-On Proxy
emoji: 👔
colorFrom: indigo
colorTo: blue
sdk: docker
pinned: false
---

# Alafif Virtual Try-On Proxy

FastAPI proxy to public IDM-VTON Space. One REST call to `/tryon` → base64 result.

**Endpoint:** `POST /tryon` (multipart: person_image + garment_image_url + category)

Set `HF_TOKEN` as Space secret for queue priority on the public Space.
