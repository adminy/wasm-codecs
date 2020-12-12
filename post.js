// self defined
const _DE265_DECODER_PARAM_DISABLE_DEBLOCKING = 7
const _DE265_DECODER_PARAM_DISABLE_SAO = 8
const _DE265_ERROR_WAITING_FOR_INPUT_DATA = 13

const createOutputArray = length => {
    const pointer = _malloc(Float32Array.BYTES_PER_ELEMENT * length)
    const array = new Float32Array(HEAPU8.buffer, pointer, length)
    return [pointer, array]
}

// api from here
const libopus = {}
libopus.decoder = () => {
    //const sampleRate = 48e3
    const pcmSize = 120 * 48 * 2
    const sendMax = 16 * 1024
    libopus.onDecode = () => {}
    const decoder = _opus_chunkdecoder_create()
    libopus.push = buffer => {
        const srcLen = buffer.byteLength
        const src = _malloc(buffer.BYTES_PER_ELEMENT * sendMax)           
    
        const [interleavedPtr, pcm] = createOutputArray(pcmSize)
        let sendStart = 0
        while (sendStart < srcLen) {
            const sendSize = sendMax > srcLen - sendStart ? srcLen - sendStart : sendMax
            HEAPU8.set(buffer.subarray(sendStart, sendStart + sendSize), src)
            sendStart += sendSize
            if (_opus_chunkdecoder_enqueue(decoder, src, sendSize)) {
                let samples
                while (samples = _opus_chunkdecoder_decode_float_stereo(decoder, interleavedPtr, pcmSize))
                    libopus.onDecode(pcm.slice(0, samples), samples)
            } else return console.error('Could not enqueue bytes for decoding.  You may also have invalid Ogg Opus file.')
        }
        _free(src)
        _free(interleavedPtr)
    }
    libopus.free = () => _opus_chunkdecoder_free(decoder)
    // libopus.decoderVersion = _opus_chunkdecoder_version
    // libopus.libOpusVersion = _opus_get_version_string
    return libopus
}
const libde265 = {}
let libde265_decoding = false
let libde265_ready = false
const getImageData = img => {
    if (!libde265_ready) {
        libde265_ready = true
        libde265.img.width = _de265_get_image_width(img, 0)
        libde265.img.height = _de265_get_image_height(img, 0)
        libde265.img.chroma = _de265_get_chroma_format(img)
    }
    const stride = _malloc(4)
    const y = _de265_get_image_plane(img, 0, stride)
    const stridey = getValue(stride, 'i32')
    const bppy = _de265_get_bits_per_pixel(img, 0)
    const u = _de265_get_image_plane(img, 1, stride)
    const strideu = getValue(stride, 'i32')
    const bppu = _de265_get_bits_per_pixel(img, 1)
    const v = _de265_get_image_plane(img, 2, stride)
    const stridev = getValue(stride, 'i32')
    const bppv = _de265_get_bits_per_pixel(img, 2)
    _free(stride)
    // bppu: 8, bppv: 8, bppy: 8, chroma: 1, w: 1280, h: 720, strideu: 640, stridev: 640, stridey: 1280, u: 60524512, v: 6423296, y: 72044800
    return [
        HEAPU8.subarray(y, y + libde265.img.height * stridey),
        HEAPU8.subarray(u, u + libde265.img.height * strideu),
        HEAPU8.subarray(v, v + libde265.img.height * stridev)
    ]
}
const libde265_decode = decoder => {
    libde265_decoding = true
    while (1) {
        const more = _malloc(2)
        const errorCode = _de265_decode(decoder, more)
        _free(more) // if(getValue(more, 'i16') !== 0) {}
        if(errorCode == _DE265_ERROR_WAITING_FOR_INPUT_DATA)
            return libde265_decoding = false
        else if(!_de265_isOK(errorCode)) 
            return console.error(_de265_get_error_text(errorCode), libde265_decoding = false)
        const img = _de265_get_next_picture(decoder)
        // const img = _de265_peek_next_picture(decoder)
        img && libde265.onDecodedFrame(...getImageData(img))
    }
}

libde265.decoder = () => {
    libde265.img = {}
    libde265.onDecodedFrame = () => {}

    const decoder = _de265_new_decoder()
    // disable filters
    _de265_set_parameter_bool(decoder, _DE265_DECODER_PARAM_DISABLE_DEBLOCKING, true)
    _de265_set_parameter_bool(decoder, _DE265_DECODER_PARAM_DISABLE_SAO, true)
    // _de265_set_framerate_ratio(decoder, ratio)

    libde265.push = buffer => {
        const u8 = new Uint8Array(buffer)
        const inputPointer = _malloc(u8.length)
        HEAPU8.set(u8, inputPointer)
        !_de265_isOK(_de265_push_data(decoder, inputPointer, u8.length, 0, 0)) && console.error('@_input push error_@');
        _free(inputPointer)
        !libde265_decoding && libde265_decode(decoder)
    }

    libde265.free = () => {
        _de265_flush_data(decoder)
        // _de265_reset(decoder)
        _de265_free_decoder(decoder)
    }
    return libde265
}
module.exports = new Promise(whenReady => Module.onRuntimeInitialized = () => whenReady({libde265, libopus}))
