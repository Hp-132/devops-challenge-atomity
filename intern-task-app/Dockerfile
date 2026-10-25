FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PORT=8080

RUN useradd --system --uid 10001 --no-create-home app

WORKDIR /app

COPY app/app.py .

USER 10001

EXPOSE 8080

CMD ["python", "app.py"]