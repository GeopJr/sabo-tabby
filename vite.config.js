import { splitVendorChunkPlugin } from 'vite'
import Icons from 'unplugin-icons/vite'
import postcssNested from 'postcss-nested';

/** @type {import('vite').UserConfig} */
const config = {
  build: {
    cssCodeSplit: true
  },
  plugins: [
    Icons({ compiler: 'raw', }),
    splitVendorChunkPlugin()
  ],
  css: {
    postcss: {
      plugins: [
        postcssNested()
      ],
    },
  },
}

export default config;