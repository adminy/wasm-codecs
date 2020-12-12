### Wasm libde265 and libopus decoders for web

This combines both libopus and libde265 into one wasm file so that they can share 


# Usage

```javascript
const codecs = require('./wasmCodecs')
const WebGLPlayer = require('./webglPlayer')
const WebAudio = require('./webAUdio')

//promise based load because wasm is async (promise based)
codecs.then(({libde265, libopus}) => {

    const video = libde265.decoder()
    const videoOut = WebGLPlayer(canvas)
    video.onDecodedFrame = (y, u, v) => videoOut.renderFrame(y, u, v, video.img.width, video.img.height)
    
    const audio = libopus.decoder()
    const audioOut = WebAudio(sampleRate)
    audio.onDecode = samples => audioOut.play(samples)

    const onVideoInput = chunk => video.push(chunk.buffer)
    const onMicInput = chunk => audio.push(chunk.buffer)
})

```

# Credits

https://github.com/AnthumChris/opus-stream-decoder

https://github.com/strukturag/libde265

https://github.com/strukturag/libde265.js
