FROM microsoft/powershell:6.0.2-ubuntu-xenial
LABEL maintainer="Matthew Kelly (Badgerati)"
RUN mkdir -p /usr/local/share/powershell/Modules/Pode
COPY ./src/ /usr/local/share/powershell/Modules/Pode