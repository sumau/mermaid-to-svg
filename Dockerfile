# The action runs inside the pinned mermaid-cli image, which already provides
# mmdc + system Chromium; we only bake in our extraction/orchestration scripts.
# This FROM is the single source of truth for the mermaid-cli version.
FROM minlag/mermaid-cli:11.16.0

COPY src/ /action/src/
COPY entrypoint.sh /action/entrypoint.sh

# The base image runs as a non-root user; GitHub runs Docker actions as root and
# mounts the workspace as root, so switch to root and make the entrypoint
# executable. (Local previews override the user back to the host uid.)
USER root
# The base image is Alpine (busybox sh only); the entrypoint uses bash arrays.
RUN apk add --no-cache bash \
  && chmod +x /action/entrypoint.sh

ENTRYPOINT ["/action/entrypoint.sh"]
