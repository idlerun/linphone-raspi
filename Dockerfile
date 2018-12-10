FROM raspbian/stretch as build
ENV DEBIAN_FRONTEND=noninteractive
ENV PKG_CONFIG_PATH="/target/lib/pkgconfig"
ENV PATH=/target:/target/bin:$PATH
RUN mkdir -p /src /target/lib/pkgconfig
RUN apt-get update
RUN apt-get install -y \
    wget git libtool autoconf \
    cmake build-essential pkg-config unzip\
    libasound2-dev patchelf
# upgrade to latest cmake
RUN wget -qO- https://cmake.org/files/v3.13/cmake-3.13.0-rc3.tar.gz | tar xz -C /src
WORKDIR /src/cmake-3.13.0-rc3
RUN cmake .
RUN make -j4
RUN make install
RUN apt-get remove -y cmake
WORKDIR /src

# project shared deps
RUN apt-get install -y \
    libasound2-dev libsqlite3-dev libxml2-dev \
    openjdk-9-jdk-headless openjdk-9-jdk-headless \
    zlib1g-dev python2.7-minimal gettext \
    libv4l-dev
RUN apt-get install -y antlr3

ENV CMAKE_OPTS="-DCMAKE_INSTALL_PREFIX:PATH=/target -DCMAKE_PREFIX_PATH=/target"
ENV CONFIGURE_OPTS="--prefix=/target"



# antlr C bindings
FROM build as dep-antlr
RUN wget -qO- https://github.com/antlr/antlr3/archive/release-3.4.tar.gz | tar xz -C /src
WORKDIR /src/antlr3-release-3.4/runtime/C
RUN sed -e "s/^ACLOCAL_AMFLAGS/AUTOMAKE_OPTIONS = subdir-objects\nACLOCAL_AMFLAGS/" -i Makefile.am
RUN autoreconf -i
RUN ./configure $CONFIGURE_OPTS --disable-abiflags
RUN make -j4
RUN make install



FROM build as dep-openssl
RUN wget -qO- https://www.openssl.org/source/openssl-1.1.1.tar.gz | tar xz -C /src
WORKDIR /src/openssl-1.1.1
RUN ./config $CMAKE_OPTS
RUN make -j4
RUN make install



FROM build as dep-mbedtls
RUN wget -qO- https://github.com/ARMmbed/mbedtls/archive/mbedtls-2.13.0.tar.gz | tar xz -C /src
WORKDIR /src/mbedtls-mbedtls-2.13.0
RUN cmake $CMAKE_OPTS -DENABLE_TESTING=Off .
RUN make -j4
RUN make install



FROM build as dep-bctoolbox
COPY --from=dep-antlr /target/ /target/
COPY --from=dep-mbedtls /target/ /target/
RUN git clone https://github.com/BelledonneCommunications/bctoolbox.git /src/bctoolbox
WORKDIR /src/bctoolbox
RUN cmake $CMAKE_OPTS -DENABLE_TESTS=NO -DENABLE_TESTS_COMPONENT=NO .
RUN make -j4
RUN make install



FROM build as dep-belle-sip
COPY --from=dep-bctoolbox /target/ /target/
RUN git clone https://github.com/BelledonneCommunications/belle-sip.git /src/belle-sip
WORKDIR /src/belle-sip
RUN cmake $CMAKE_OPTS -DENABLE_TESTS=NO .
RUN make -j4
RUN make install



FROM build as dep-ortp
COPY --from=dep-bctoolbox /target/ /target/
RUN git clone https://github.com/BelledonneCommunications/ortp.git /src/ortp
WORKDIR /src/ortp
RUN cmake $CMAKE_OPTS -DENABLE_TESTS=NO -DENABLE_DEBUG_LOGS=YES -DENABLE_DOC=NO .
RUN make -j4
RUN make install



FROM build as dep-bzrtp
COPY --from=dep-bctoolbox /target/ /target/
RUN git clone https://github.com/BelledonneCommunications/bzrtp.git /src/bzrtp
WORKDIR /src/bzrtp
RUN cmake $CMAKE_OPTS -DENABLE_TESTS=NO -DENABLE_DEBUG_LOGS=YES -DENABLE_DOC=NO .
RUN make -j4
RUN make install



FROM build as dep-belr
COPY --from=dep-bctoolbox /target/ /target/
RUN git clone https://github.com/BelledonneCommunications/belr.git /src/belr
WORKDIR /src/belr
RUN cmake $CMAKE_OPTS
RUN make -j4
RUN make install



FROM build as dep-belcard
COPY --from=dep-bctoolbox /target/ /target/
COPY --from=dep-belr /target/ /target/
RUN git clone https://github.com/BelledonneCommunications/belcard.git /src/belcard
WORKDIR /src/belcard
RUN cmake $CMAKE_OPTS -ENABLE_UNIT_TESTS=NO .
RUN make -j4
RUN make install



FROM build as dep-libsrtp
RUN wget -qO- https://github.com/cisco/libsrtp/archive/v1.6.0.tar.gz | tar xz -C /src
WORKDIR /src/libsrtp-1.6.0
RUN ./configure $CONFIGURE_OPTS
RUN make -j4
RUN make install



FROM build as dep-speex
RUN wget -qO- https://github.com/xiph/speex/archive/Speex-1.2.0.tar.gz | tar xz -C /src
WORKDIR /src/speex-Speex-1.2.0
RUN autoreconf -i
RUN ./configure $CONFIGURE_OPTS
RUN make -j4
RUN make install



FROM build as dep-speexdsp
RUN wget -qO- https://github.com/xiph/speexdsp/archive/SpeexDSP-1.2rc3.tar.gz | tar xz -C /src
WORKDIR /src/speexdsp-SpeexDSP-1.2rc3
RUN autoreconf -i
RUN ./configure $CONFIGURE_OPTS
RUN make -j4
RUN make install



FROM build as dep-x264
RUN git clone --depth 1 --branch stable https://git.videolan.org/git/x264 /src/x264
WORKDIR /src/x264
RUN ./configure $CONFIGURE_OPTS --enable-shared --disable-opencl --enable-pic
RUN make -j4
RUN make install



# require for enable-omx h264 hardware decoding
FROM build as dep-libomxil
RUN wget -qO- https://ayera.dl.sourceforge.net/project/omxil/omxil/Bellagio%200.9.3/libomxil-bellagio-0.9.3.tar.gz | tar xz -C /src
WORKDIR /src/libomxil-bellagio-0.9.3
# avoids error:  case value 2130706435 not in enumerated type OMX_INDEXTYPE [-Werror=switch]
RUN sed -e "s/-Wall -Werror//" -i configure
RUN ./configure $CONFIGURE_OPTS
RUN make
RUN make install



FROM build as dep-ffmpeg
RUN wget -qO- https://ffmpeg.org/releases/ffmpeg-4.1.tar.bz2 | tar xj -C /src
WORKDIR /src/ffmpeg-4.1
COPY --from=dep-x264 /target/ /target/
COPY --from=dep-openssl /target/ /target/
COPY --from=dep-libomxil /target/ /target/
RUN mkdir -p /opt/vc/lib
COPY lib/*.so* /opt/vc/lib/
ENV LD_LIBRARY_PATH=/opt/vc/lib
RUN ./configure \
    $CONFIGURE_OPTS \
    --arch=armel --target-os=linux \
    --extra-cflags="-I$TARGET_DIR/include" \
    --extra-ldflags="-L$TARGET_DIR/lib" \
    --enable-shared \
    \
    --enable-pic \
    --enable-neon \
    --disable-debug \
    \
    --enable-gpl \
    --enable-nonfree \
    \
    --enable-indev=alsa --enable-outdev=alsa \
    --enable-libx264 \
    --enable-omx \
    --enable-omx-rpi \
    --enable-encoder=h264_omx \
    --enable-encoder=h264_omx
RUN make -j4
RUN make install



FROM build as dep-mediastreamer
COPY --from=dep-libsrtp /target /target
COPY --from=dep-bzrtp /target /target
COPY --from=dep-ortp /target /target
COPY --from=dep-speex /target /target
COPY --from=dep-speexdsp /target /target
COPY --from=dep-ffmpeg /target /target
RUN git clone https://github.com/BelledonneCommunications/mediastreamer2.git /src/mediastreamer2
WORKDIR /src/mediastreamer2
RUN cmake $CMAKE_OPTS -DENABLE_NON_FREE_CODECS=YES -DENABLE_V4L=YES -DENABLE_SRTP=YES -DENABLE_ZRTP=YES -ENABLE_UNIT_TESTS=NO -ENABLE_DEBUG_LOGS=NO -DENABLE_DOC=NO -DENABLE_X11=NO -DENABLE_GLX=NO -DENABLE_XV=NO .
RUN make -j4
RUN make install



FROM build as dep-soci
RUN git clone https://github.com/SOCI/soci.git /src/soci
WORKDIR /src/soci
RUN cmake $CMAKE_OPTS
RUN make -j4
RUN make install



FROM build
RUN apt-get install -y doxygen python-six python-pystache graphviz libxerces-c-dev xsdcxx
COPY --from=dep-belle-sip /target /target
COPY --from=dep-belcard /target /target
COPY --from=dep-mediastreamer /target /target
COPY --from=dep-soci /target /target
RUN git clone https://github.com/BelledonneCommunications/linphone.git /src/linphone
WORKDIR /src/linphone
RUN cmake $CMAKE_OPTS -DENABLE_UNIT_TESTS=NO -DENABLE_DOC=NO -DENABLE_VCARD=NO .
RUN make -j4
RUN make install

