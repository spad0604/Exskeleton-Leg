use backend::{bootstrap, bootstrap::config::Config};

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_target(false)
        .compact()
        .init();

    let config = Config::from_env().expect("invalid backend configuration");
    let address = config.bind_address;
    let app = bootstrap::build_app(config)
        .await
        .expect("failed to initialize backend");
    let listener = tokio::net::TcpListener::bind(address)
        .await
        .expect("failed to bind server");

    tracing::info!(%address, "backend listening");

    axum::serve(listener, app).await.expect("server failed");
}
