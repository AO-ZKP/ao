FROM emscripten/emsdk:3.1.59
LABEL maintainer="tom wilson <tom@hyper.io>"

# The working directory used by the base image is /src, so we can mount volumes to there
# to expose files on the host to the ao container
# 
# https://github.com/emscripten-core/emsdk/blob/9b0db91883452051aca8deddc932363aab29060b/docker/Dockerfile#L120

RUN apt-get update --fix-missing -qq -y
RUN apt-get install -y curl vim make gcc libreadline6-dev libssl-dev zlib1g-dev zip unzip ccache

ENV LUA_VERSION=5.3.4
ENV LUAROCKS_VERSION=2.4.4
ENV PYTHON_VERSION=3.6.6

# install deno
# RUN curl -fsSL https://deno.land/x/install/install.sh | sh
# RUN echo 'export DENO_INSTALL="/root/.deno"' >> $HOME/.bashrc
# RUN echo 'export PATH="$DENO_INSTALL/bin:$PATH"' >> $HOME/.bashrc

# Intall yaml
RUN pip3 install pyyaml

# Install lua runtime
RUN cd / && \
  curl -L http://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz | tar xzf - && \
  cd /lua-${LUA_VERSION} && \
  make linux test && \
  make install

# Install luarocks
RUN cd / && \
  curl -L https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz | tar xzf - && \
  cd /luarocks-${LUAROCKS_VERSION} && \
  ./configure && \
  make build && \
  make install

# Install NodeJS
ENV NODE_VERSION=18.17.0
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"
RUN node --version
RUN npm --version

# Make a copy of the lua runtime for 32-bit
RUN cp -r /lua-${LUA_VERSION} /lua-${LUA_VERSION}-32

# And, re-compile lua with "generic WASM"
RUN cd /lua-${LUA_VERSION} && \
  make clean && \
  make generic CC='emcc -s WASM=1 -s MEMORY64=1 -s SUPPORT_LONGJMP=1' 

# And, re-compile lua with "generic WASM 32-bit"
RUN cd /lua-${LUA_VERSION}-32 && \
  make clean && \
  make generic CC='emcc -s WASM=1 -s SUPPORT_LONGJMP=1' 


#############################
##### Install Commands ######
#############################

# NOTE: Some commands do not require additional work
# when building the image, but are still commented
# here for posterity

###############
#### Init #####
###############
# The init command currently does not require running
# within the ao container, and so requires no additional setup

###############
#### Repl #####
###############
# The repl command simply fires up lua repl, which is installed
# as part of lua runtime above, and so requires no additional setup

###############
#### Build ####
###############
COPY ./src/ao-build-module /usr/local/bin/ao-build-module
COPY ./src/ao_module_lib /usr/local/ao-module/ao_module_lib

COPY ./src/core/ /opt/

COPY ./src/sqlite/lsqlite3.c /opt/lsqlite3.c
COPY ./src/sqlite/lsqlite3.h /opt/lsqlite3.h
COPY ./src/sqlite/sqlite3.c /opt/sqlite3.c
COPY ./src/sqlite/sqlite3.h /opt/sqlite3.h

RUN mkdir -p /opt/src
COPY ./src/json.lua /opt/src/json.lua
# COPY ./src/ao.lua /opt/src/ao.lua
# COPY ./src/pack.lua /opt/pack.lua

RUN chmod +x /usr/local/bin/ao-build-module

###################################
# BUILD WeaveDrive Extension Helper
###################################
COPY ./src/aolibc /opt/aolibc
## Build aolibc for 32-bit and rename to aolibc32
RUN cd /opt/aolibc && make CC="emcc -s WASM=1 -s SUPPORT_LONGJMP=1 /lua-5.3.4-32/src/liblua.a -I/lua-5.3.4-32/src" && cp ./aolibc.a ./aolibc32.a
RUN rm /opt/aolibc/aolibc.a
RUN rm /opt/aolibc/aostdio.o
# Build aolibc for 64-bit
RUN cd /opt/aolibc && make CC="emcc -s WASM=1 -s MEMORY64=1 -s SUPPORT_LONGJMP=1 /lua-5.3.4/src/liblua.a -I/lua-5.3.4/src"

ENV CC='emcc -s WASM=1'
ENV NM='/emsdk/upstream/bin/llvm-nm'

###########################################
### Publish, Bundler, Process, Contract ###
###########################################
# We first create a directory for the node impls to be placed
# and dependencies installed
# 
# By running npm link, we allow any commands exposed by
# the node module to be ran globally within the container
RUN mkdir -p /opt/node
COPY ./src/node /opt/node
RUN cd /opt/node && \
  npm install --omit="dev" && \
  npm link

# Copy the updated wrapper script into the image
COPY src/wasm-opt-wrapper.sh /emsdk/upstream/bin/wasm-opt-wrapper.sh

# Rename the original wasm-opt and set the wrapper as the default
RUN mv /emsdk/upstream/bin/wasm-opt /emsdk/upstream/bin/wasm-opt-original && \
    cp /emsdk/upstream/bin/wasm-opt-wrapper.sh /emsdk/upstream/bin/wasm-opt && \
    chmod +x /emsdk/upstream/bin/wasm-opt

# Tell Emscripten to use the wrapper
ENV EMCC_WASM_OPT=/emsdk/upstream/bin/wasm-opt-wrapper.sh