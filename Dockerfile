# The action runs inside the pinned mermaid-cli image, which already provides
# mmdc + system Chromium; we only bake in the Node driver from src/.
# This FROM is the single source of truth for the mermaid-cli version.
FROM minlag/mermaid-cli:11.16.0

COPY src/ /action/src/

# The base image runs as a non-root user; GitHub runs Docker actions as root
# and mounts the workspace as root, so switch to root. (Local previews
# override the user back to the host uid.)
USER root

ENTRYPOINT ["node", "/action/src/main.mjs"]
