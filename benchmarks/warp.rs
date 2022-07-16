use warp::Filter;

#[tokio::main]
async fn main() {
    let indexp = warp::get()
        .and(warp::path::end())
        .and(warp::fs::file("./index.html"));

    let routes = indexp;

    warp::serve(routes).run(([127, 0, 0, 1], 3003)).await;
}

// http://127.0.0.1:3003/
