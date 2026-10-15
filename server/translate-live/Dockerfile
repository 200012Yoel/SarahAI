FROM python:3.11-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 HF_HOME=/models
WORKDIR /service
RUN pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch==2.6.0 && \
    pip install --no-cache-dir transformers==4.49.0 sentencepiece==0.2.0 sacremoses==0.1.1
COPY app.py /service/app.py
EXPOSE 5000
CMD ["python", "/service/app.py"]
