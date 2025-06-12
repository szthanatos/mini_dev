FROM python:3.12
LABEL maintainer="sz <zhan.su@greatdb.com>"
LABEL description="BIRD-bench mini_dev"
LABEL version="20250601"

RUN cat > /etc/apt/sources.list <<EOF 
deb https://mirrors.aliyun.com/debian/ bullseye main non-free contrib
deb https://mirrors.aliyun.com/debian-security/ bullseye-security main
deb https://mirrors.aliyun.com/debian/ bullseye-updates main non-free contrib
deb https://mirrors.aliyun.com/debian/ bullseye-backports main non-free contrib
EOF

RUN apt-get update && \
    apt-get install unzip

ENV UV_DEFAULT_INDEX=https://mirrors.aliyun.com/pypi/simple
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple && \
    pip config set install.trusted-host mirrors.aliyun.com && \
    pip install uv

WORKDIR /app
COPY pyproject.toml uv.lock .
RUN uv sync

COPY . .
