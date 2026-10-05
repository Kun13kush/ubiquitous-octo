FROM python:3.13-alpine@sha256:2d9aefe2fef018a7eb2c13064c89c71929800fd2e5dccdbf52ea5da5bb8d929a
ARG APP_VERSION=local
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 APP_VERSION=$APP_VERSION APP_ENV=development PORT=8080
# Apply available distribution security updates; refresh the pinned base regularly.
RUN apk upgrade --no-cache
# The stdlib-only runtime needs no package manager, bundled wheels or build tooling.
RUN python -c "import pathlib, shutil, sysconfig; shutil.rmtree(sysconfig.get_path('purelib')); shutil.rmtree(pathlib.Path(sysconfig.get_path('stdlib')) / 'ensurepip')"
WORKDIR /app
COPY --chown=10001:10001 app/server.py ./server.py
USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2)"
CMD ["python", "server.py"]
