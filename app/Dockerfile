# Deliberately vulnerable demo app. It runs only on an internal Docker network (no published port).
FROM python:3.15-slim@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --require-hashes -r requirements.txt
COPY app.py .
USER nobody
EXPOSE 5000
CMD ["python", "app.py"]
