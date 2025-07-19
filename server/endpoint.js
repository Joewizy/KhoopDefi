import express from 'express'
import path, {dirname} from 'path'
import { fileURLToPath } from 'url'

// TODO: Create endpoints that routes your users request from the client side to the backend.
const app = express()
const PORT = process.env.PORT || 3000

// Middleware
app.use(express.json())

app.get('/', (req, res) => {
    console.log("app.get file")
})

app.listen(PORT, () => {
    console.log(`Server running on port: ${PORT}`)
})
