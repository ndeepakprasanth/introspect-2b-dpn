import os
import json
from flask import Flask, jsonify, request

app = Flask(__name__)

# Determine mocks path via environment variable or default to repo-level ./mocks
DEFAULT_MOCKS = os.environ.get('MOCKS_PATH') or os.path.join(os.path.dirname(__file__), '..', '..', 'mocks')


def _load_json_file(path):
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        return None


@app.route('/')
def hello():
    return {'message': 'Hello from Introspect sample service'}


@app.route('/claims/<claim_id>', methods=['GET'])
def get_claim(claim_id):
    mocks_dir = os.environ.get('MOCKS_PATH') or DEFAULT_MOCKS
    claims = _load_json_file(os.path.join(mocks_dir, 'claims.json')) or []
    for c in claims:
        if str(c.get('id')) == str(claim_id):
            return jsonify(c)
    return jsonify({'error': 'claim not found'}), 404


@app.route('/claims/<claim_id>/summarize', methods=['POST'])
def summarize_claim(claim_id):
    mocks_dir = os.environ.get('MOCKS_PATH') or DEFAULT_MOCKS
    notes = _load_json_file(os.path.join(mocks_dir, 'notes.json')) or {}
    claim_notes = notes.get(str(claim_id)) or []

    # Pluggable Bedrock adapter - prefer real Bedrock client, fallback to stub, then safe default
    try:
        from bedrock_client import summarize_notes
    except Exception:
        try:
            from bedrock_stub import summarize_notes
        except Exception:
            def summarize_notes(n):
                return {
                    'overall_summary': 'No adapter available',
                    'customer_summary': 'No adapter available',
                    'adjuster_summary': 'No adapter available',
                    'recommended_next_step': 'Contact support.'
                }

    try:
        result = summarize_notes(claim_notes)
    except Exception:
        # If the preferred Bedrock client fails at runtime (e.g., missing model env),
        # attempt to fallback to the local stub implementation, then to safe defaults.
        try:
            from bedrock_stub import summarize_notes as stub_summarize
            result = stub_summarize(claim_notes)
        except Exception:
            result = {
                'overall_summary': 'No adapter available',
                'customer_summary': 'No adapter available',
                'adjuster_summary': 'No adapter available',
                'recommended_next_step': 'Contact support.'
            }

    return jsonify({
        'claimId': claim_id,
        'notesCount': len(claim_notes),
        'summary': result
    })


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
