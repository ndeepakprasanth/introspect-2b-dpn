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


def test_get_claim_found(client=None):
    client = flask_app.test_client()
    resp = client.get('/claims/1001')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data.get('id') == '1001' or data.get('id') == 1001


def test_get_claim_not_found():
    client = flask_app.test_client()
    resp = client.get('/claims/9999')
    assert resp.status_code == 404


def test_summarize_claim():
    client = flask_app.test_client()
    resp = client.post('/claims/1001/summarize')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data.get('claimId') == '1001'
    assert 'summary' in data
    assert 'notesCount' in data


def test_summarize_no_notes():
    client = flask_app.test_client()
    # ID 1004 has no notes in mocks
    resp = client.post('/claims/1004/summarize')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data['notesCount'] == 0
    assert data['summary']['overall_summary'].startswith('No notes')
