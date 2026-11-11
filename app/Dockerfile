# Deliberately vulnerable demo app. It runs only on an internal Docker network (no published port).
FROM python:3.13-slim@sha256:09a17cad02668ae61ece136b4fd36ac3849e14f670ebedb637ea3e15580525bc
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --require-hashes -r requirements.txt
COPY app.py .
USER nobody
EXPOSE 5000
CMD ["python", "app.py"]
