import htmlgen
import jester

routes:
  get "/":
    resp h1("Hello world")

# http://127.0.0.1:5000/index.html
