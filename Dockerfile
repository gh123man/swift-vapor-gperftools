# ================================
# Build image
# ================================
FROM swift:6.0-noble AS build

# Install OS updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y \
    libgoogle-perftools-dev \
    google-perftools

# setup build for jemalloc 
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    devscripts \
    fakeroot \
    dpkg-dev \
    git \
    wget \
    sudo \
    vim && \
    sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get update

# Get jemalloc source and install build dependencies
RUN apt-get source libjemalloc-dev && \
apt-get build-dep -y libjemalloc-dev

RUN cd jemalloc-* && \
    sed -i 's|dh_auto_configure --.*|dh_auto_configure -- --enable-debug --enable-fill --enable-prof --enable-stat|' debian/rules

RUN cd jemalloc-* && \
    dpkg-buildpackage -us -uc -b

# Install the newly built jemalloc package
RUN dpkg -i /libjemalloc2*.deb 
RUN dpkg -i /libjemalloc-dev*.deb 

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve \
        $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

# Copy entire repo into container
COPY . .

# Build the application, with optimizations, with static linking, and using jemalloc
# N.B.: The static version of jemalloc is incompatible with the static Swift runtime.
RUN swift build -c release \
        --product App \
        --static-swift-stdlib \
        -Xlinker -lprofiler \
        -Xlinker -ljemalloc \
        -Xswiftc -g

# Switch to the staging area
WORKDIR /staging

RUN cp /libjemalloc*.deb ./

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/App" ./

# # Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# # Copy resources bundled by SPM to staging area
RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# # Copy any resources from the public directory and views directory if the directories exist
# # Ensure that by default, neither the directory nor any of its contents are writable.
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM ubuntu:noble

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      ca-certificates \
      tzdata \
      libgoogle-perftools4 \
      google-perftools \
    && rm -r /var/lib/apt/lists/*

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

# Copy built executable and any staged resources from builder
COPY --from=build --chown=vapor:vapor /staging /app

# Install the newly built jemalloc package
RUN dpkg -i libjemalloc2*.deb 
RUN dpkg -i libjemalloc-dev*.deb 

# Provide configuration needed by the built-in crash reporter and some sensible default behaviors.
ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static
ENV MALLOC_CONF=prof:true,prof_active:true

# Ensure all further commands run as the vapor user
# USER vapor:vapor

# Let Docker bind to port 8080
EXPOSE 8080

# Start the Vapor service when the image is run, default to listening on 8080 in production environment
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
