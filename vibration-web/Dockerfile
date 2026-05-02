FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com -r requirements.txt
COPY . .
EXPOSE 8050
CMD ["gunicorn", "app:server", "-b", "0.0.0.0:8050", "-w", "1", "--timeout", "120"]
