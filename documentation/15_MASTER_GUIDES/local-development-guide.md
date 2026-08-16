# MetalCraft — Local Development Guide

## 1. Running Backend & Web Companion Locally
```bash
# 1. Navigate to project root
cd /path/to/MetalCraft

# 2. Activate virtual environment
source agent_backend/venv/bin/activate

# 3. Start FastAPI server with live reload
uvicorn backend.app.main:app --host 0.0.0.0 --port 8080 --reload
```
Once started, the Web Companion will be available in your browser at:
`http://localhost:8080`

---

## 2. Running Backend Pytest Suite
```bash
pytest backend/tests/test_backend.py -v
```

---

## 3. Running iOS Unit Tests
```bash
xcodebuild test -scheme MetalCraft -destination 'platform=iOS Simulator,name=iPhone 17'
```

---

## 4. Building and Installing on Physical iPhone
```bash
xcodebuild -scheme MetalCraft -destination 'id=<device_udid>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <device_udid> /path/to/MetalCraft.app
```
