# brew install automake autogen
WASM_MODULE=dist/codecs.js
WASM_LIB=tmp/lib.bc
LIBDE265=src/libde265/libde265/.libs/libde265.a
OGG_CONFIG_TYPES=src/ogg/include/ogg/config_types.h
CONFIGURE_LIBOPUS=src/opus/configure
CONFIGURE_LIBOGG=src/ogg/configure
CONFIGURE_LIBOPUSFILE=src/opusfile/configure

default: dist

clean: dist-clean wasmlib-clean configures-clean

dist: wasm

dist-clean:
	rm -rf dist/*

wasm: wasmlib libde265 $(WASM_MODULE)

libde265:
	cd src/libde265; ./autogen.sh
	cd src/libde265; emconfigure ./configure --disable-sse --disable-dec265 --disable-sherlock265 --disable-encoder --disable-arm
	cd src/libde265; emmake make

wasmlib: configures $(OGG_CONFIG_TYPES) $(WASM_LIB)
wasmlib-clean: dist-clean
	rm -rf $(WASM_LIB)

configures: $(CONFIGURE_LIBOGG) $(CONFIGURE_LIBOPUS) $(CONFIGURE_LIBOPUSFILE)
configures-clean: wasmlib-clean
	rm -rf $(CONFIGURE_LIBOPUSFILE)
	rm -rf $(CONFIGURE_LIBOPUS)
	rm -rf $(CONFIGURE_LIBOGG)

define WASM_EMCC_OPTS
-O3 \
-s NO_DYNAMIC_EXECUTION=1 \
-s NO_FILESYSTEM=1 \
	-s TOTAL_MEMORY=67108864 \
	-s ALLOW_MEMORY_GROWTH=0 \
	-s ASSERTIONS=0 \
	-s INVOKE_RUN=0 \
	-s DISABLE_EXCEPTION_CATCHING=1 \
-s EXPORTED_FUNCTIONS="[ \
  '_free', '_malloc', \
  '_opus_chunkdecoder_create', \
  '_opus_chunkdecoder_free', \
  '_opus_chunkdecoder_enqueue', \
  '_opus_chunkdecoder_decode_float_stereo', \
  '_de265_get_error_text', \
  '_de265_isOK', \
  '_de265_get_image_width', \
  '_de265_get_image_height', \
  '_de265_get_chroma_format', \
  '_de265_get_bits_per_pixel', \
  '_de265_get_image_plane', \
  '_de265_new_decoder', \
  '_de265_push_data', \
  '_de265_decode', \
  '_de265_get_next_picture', \
  '_de265_set_framerate_ratio', \
  '_de265_set_parameter_bool', \
  '_de265_free_decoder', \
  '_de265_flush_data', \
  '_de265_reset' \
]" \
--pre-js 'pre.js' \
--post-js 'post.js' \
-I src/opusfile/include \
-I "src/ogg/include" \
-I "src/opus/include" \
src/opus_chunkdecoder.c
endef #-s EXTRA_EXPORTED_RUNTIME_METHODS="['cwrap']"   MORE Exported functions: , '_opus_get_version_string' \  '_opus_chunkdecoder_version', \ ... 	-s MAXIMUM_MEMORY=-1 \ -s BINARYEN_ASYNC_COMPILATION=0 \ -s SINGLE_FILE=1 \    '_de265_peek_next_picture', \ 


$(WASM_MODULE):
	@ mkdir -p dist
	@ echo "Building Emscripten WebAssembly module $(WASM_MODULE)..."
	@ emcc \
		-o "$(WASM_MODULE)" \
	  $(WASM_EMCC_OPTS) \
	  $(WASM_LIB) \
	  $(LIBDE265)
	@ echo "+-------------------------------------------------------------------------------"
	@ echo "|"
	@ echo "|  Successfully built JS Module: $(WASM_MODULE)"
	@ echo "|"
	@ echo "+-------------------------------------------------------------------------------"

$(WASM_LIB):
	@ mkdir -p tmp
	@ echo "Building Ogg/Opus Emscripten Library $(WASM_LIB)..."
	@ emcc \
	  -o "$(WASM_LIB)" \
	  -O0 \
	  -D VAR_ARRAYS \
	  -D OPUS_BUILD \
	  --llvm-lto 1 \
	  -s NO_DYNAMIC_EXECUTION=1 \
	  -s NO_FILESYSTEM=1 \
	  -s EXPORTED_FUNCTIONS="[ \
		 '_op_read_float_stereo' \
	  ]" \
	  -I "src/opusfile/" \
	  -I "src/opusfile/include" \
	  -I "src/opusfile/src" \
	  -I "src/ogg/include" \
	  -I "src/opus/include" \
	  -I "src/opus/celt" \
	  -I "src/opus/celt/arm" \
	  -I "src/opus/celt/dump_modes" \
	  -I "src/opus/celt/mips" \
	  -I "src/opus/celt/x86" \
	  -I "src/opus/silk" \
	  -I "src/opus/silk/arm" \
	  -I "src/opus/silk/fixed" \
	  -I "src/opus/silk/float" \
	  -I "src/opus/silk/mips" \
	  -I "src/opus/silk/x86" \
	  src/opus/src/opus.c \
	  src/opus/src/opus_multistream.c \
	  src/opus/src/opus_multistream_decoder.c \
	  src/opus/src/opus_decoder.c \
	  src/opus/silk/*.c \
	  src/opus/celt/*.c \
	  src/ogg/src/*.c \
	  src/opusfile/src/*.c
	@ echo "+-------------------------------------------------------------------------------"
	@ echo "|"
	@ echo "|  Successfully built: $(WASM_LIB)"
	@ echo "|"
	@ echo "+-------------------------------------------------------------------------------"

$(CONFIGURE_LIBOPUSFILE):
	cd src/opusfile; ./autogen.sh
$(CONFIGURE_LIBOPUS):
	cd src/opus; ./autogen.sh
$(CONFIGURE_LIBOGG):
	cd src/ogg; ./autogen.sh

$(OGG_CONFIG_TYPES):
	cd src/ogg; emconfigure ./configure
	# Remove a.out* files created by emconfigure
	cd src/ogg; rm a.out*

