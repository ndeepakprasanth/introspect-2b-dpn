import os
import sys
import json
from unittest import mock

import pytest

# Ensure module can be imported when running tests
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from bedrock_client import summarize_notes


def test_missing_model_env(monkeypatch):
    monkeypatch.delenv('BEDROCK_MODEL_ID', raising=False)
    with pytest.raises(ValueError):
        summarize_notes([])


def test_summarize_notes_success(monkeypatch):
    fake_response_body = json.dumps({
        'overall_summary': 'Overall summary text',
        'customer_summary': 'Customer summary text',
        'adjuster_summary': 'Adjuster summary text',
        'recommended_next_step': 'Next step text'
    }).encode('utf-8')

    class DummyClient:
        def invoke_model(self, modelId, contentType, accept, body):
            return {'body': fake_response_body}

    class DummySession:
        def client(self, service, region_name=None):
            return DummyClient()

    monkeypatch.setenv('BEDROCK_MODEL_ID', 'dummy-model')
    monkeypatch.setenv('AWS_PROFILE', 'Deepak')
    monkeypatch.setenv('AWS_REGION', 'us-east-1')

    monkeypatch.setattr('boto3.Session', lambda profile_name=None: DummySession())

    res = summarize_notes([{'text': 'note1'}, {'text': 'note2'}])
    assert res['overall_summary'].startswith('Overall')
    assert res['recommended_next_step'] == 'Next step text'
