# Use a slim Python base image
FROM python:3.11-slim

# Install system dependencies needed for FFmpeg, macvlan creation, DHCP, and PyTorch (libgomp1).
# ca-certificates: system trust store MediaMTX uses to verify RTSPS cameras.
RUN apt-get update && apt-get install -y \
    ca-certificates \
    ffmpeg \
    iproute2 \
    isc-dhcp-client \
    procps \
    sudo \
    curl \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Detect host architecture at build time and download the correct MediaMTX v1.18.2.
# This places it directly in the working directory so MediaMTXManager skips downloading it at runtime.
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        MEDIAMTX_ARCH="amd64"; \
    elif [ "$ARCH" = "arm64" ]; then \
        MEDIAMTX_ARCH="arm64"; \
    elif [ "$ARCH" = "armhf" ]; then \
        MEDIAMTX_ARCH="armv7"; \
    else \
        MEDIAMTX_ARCH="amd64"; \
    fi && \
    curl -L -o mediamtx.tar.gz "https://github.com/bluenviron/mediamtx/releases/download/v1.18.2/mediamtx_v1.18.2_linux_${MEDIAMTX_ARCH}.tar.gz" && \
    tar -xzf mediamtx.tar.gz mediamtx && \
    rm mediamtx.tar.gz && \
    chmod +x mediamtx

# Install core Python dependencies
RUN pip install --no-cache-dir \
    flask \
    flask-cors \
    requests \
    pyyaml \
    psutil \
    onvif-zeep \
    apprise \
    paramiko \
    cryptography

# Optional local AI object detection (CPU-only PyTorch + ultralytics/YOLO + headless OpenCV).
# These add several GB to the image. Build with INSTALL_AI=false to leave them out;
# the app runs without them and AI detection simply reports that it is not installed.
ARG INSTALL_AI=true
RUN if [ "$INSTALL_AI" = "true" ]; then \
        pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu && \
        pip install --no-cache-dir ultralytics opencv-python-headless && \
        python -c "from ultralytics import YOLO; YOLO('yolov8n.pt')"; \
    else \
        echo "Skipping AI dependencies (INSTALL_AI=$INSTALL_AI)"; \
    fi

# Copy the rest of the application
COPY . .

# Default Web UI port. Override at build/run time with the WEB_UI_PORT env var.
# (With network_mode: host this is informational; the app binds this port on the host.)
ENV WEB_UI_PORT=5552
EXPOSE ${WEB_UI_PORT}

# Run the app
CMD ["python", "run.py"]
