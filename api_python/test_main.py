from main import app

def test_app_initialization():
    # Verifica se a app iniciou e tem rotas registradas
    assert app.title == "FinAI Backend" or "FinAI" in app.title
    routes = [route.path for route in app.routes]
    assert "/auth/url" in routes or any("/auth" in r for r in routes)
    assert "/finance/upload" in routes or any("/finance" in r for r in routes)
