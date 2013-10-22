express = require 'express'
path = require 'path'
http = require 'http'


app = express()
app.use express.static '/.public'
app.set 'port', (process.env.PORT or 3000)
app.set 'views', __dirname + '/views'
app.set 'view engine', 'ejs'
app.use express.logger 'dev'
app.use express.bodyParser()
app.use express.methodOverride()
app.use app.router

app.use express.favicon()

app.use '/public', express.static __dirname + '/public'
app.use '/javascript', express.static 'public/javascript'


app.get '/', (req, res) -> res.render 'home/index', {title: ''}
app.use '/home/javascript', express.static 'views/home/javascript'
app.use '/home/style', express.static 'views/home/style'


_ <- http.createServer(app).listen app.get('port')
console.log "express started at port " + app.get('port')
