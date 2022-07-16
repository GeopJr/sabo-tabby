
const express = require('express')
const path = require('path')
const app = express()
const port = 3001

app.use(express.static(path.join(__dirname, './')))

app.listen(port, () => {
    console.log(`Example app listening on port http://localhost:${port}`)
})

// http://127.0.0.1:3001/index.html
