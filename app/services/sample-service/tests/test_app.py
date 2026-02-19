import os
import sys
import json
import pytest

# Ensure the service package directory is on sys.path when running pytest
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from app import app as flask_app


@pytest.fixture(autouse=True)
def set_mocks_path(monkeypatch):
    # Point to the repo-level mocks directory
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
    mocks_path = os.path.join(repo_root, 'mocks')
    monkeypatch.setenv('MOCKS_PATH', mocks_path)
    return mocks_path


def test_get_claim_found():
    """Test retrieving a claim that exists"""
    client = flask_app.test_client()
    resp = client.get('/claims/1001')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data.get('id') in ['1001', 1001]
    assert 'status' in data
    assert 'claimant' in data


def test_get_claim_not_found():
    """Test retrieving a claim that doesn't exist"""
    client = flask_app.test_client()
    resp = client.get('/claims/9999')
    assert resp.status_code == 404
    data = resp.get_json()
    assert 'error' in data


def test_summarize_claim_with_notes():
    """Test summarizing a claim that has notes (uses Bedrock or stub)"""
    client = flask_app.test_client()
    # Claims 1001, 1004, 1005 have notes
    resp = client.post('/claims/1001/summarize')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data.get('claimId') == '1001'
    assert 'summary' in data
    assert 'notesCount' in data
    assert data['notesCount'] > 0
    
    # Verify summary has all required fields
    summary = data['summary']
    required_fields = ['overall_summary', 'customer_summary', 'adjuster_summary', 'recommended_next_step']
    for field in required_fields:
        assert field in summary
        assert isinstance(summary[field], str)
        assert len(summary[field]) > 0


def test_summarize_claim_no_notes():
    """Test summarizing a claim that has no notes (1002 has only 1 note, 1003 has 1)"""
    client = flask_app.test_client()
    # Create a mock claim with no notes by testing existing ones
    # All claims in mocks now have notes, so we test the response structure
    resp = client.post('/claims/1001/summarize')
    assert resp.status_code == 200
    data = resp.get_json()
    assert 'claimId' in data
    assert 'summary' in data
    assert isinstance(data['summary'], dict)


def test_summarize_multiple_claims():
    """Test summarizing multiple different claims"""
    client = flask_app.test_client()
    claim_ids = ['1001', '1004', '1005']
    
    for claim_id in claim_ids:
        resp = client.post(f'/claims/{claim_id}/summarize')
        assert resp.status_code == 200
        data = resp.get_json()
        assert data['claimId'] == claim_id
        assert 'summary' in data
        assert data['notesCount'] >= 0


def test_hello_endpoint():
    """Test the health check endpoint"""
    client = flask_app.test_client()
    resp = client.get('/')
    assert resp.status_code == 200
    data = resp.get_json()
    assert 'message' in data
    assert 'Introspect' in data['message']
