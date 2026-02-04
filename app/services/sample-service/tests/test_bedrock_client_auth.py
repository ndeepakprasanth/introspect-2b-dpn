import os
import sys
import json

# Ensure module import works
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import pytest

import bedrock_client


class DummyClient:
    def __init__(self, body_bytes):
        self._body = body_bytes

    def invoke_model(self, **kwargs):
        return {'body': self._body}


class DummySession:
    def __init__(self, profile_name=None):
        self.profile_name = profile_name

    def client(self, service, region_name=None):
        return DummyClient(b'{"overall_summary":"ok","customer_summary":"ok","adjuster_summary":"ok","recommended_next_step":"do it"}')


def test_auto_uses_profile_when_aws_profile_present(monkeypatch):
    monkeypatch.setenv('AWS_PROFILE', 'Deepak')
    monkeypatch.setenv('BEDROCK_MODEL_ID', 'dummy')
    monkeypatch.delenv('BEDROCK_AUTH_MODE', raising=False)

    # Patch boto3.Session so we can verify profile_name is passed
    monkeypatch.setattr('boto3.Session', lambda profile_name=None: DummySession(profile_name))

    res = bedrock_client.summarize_notes([{'text': 'hello'}])
    assert res['overall_summary'] == 'ok'


def test_auto_uses_role_when_no_profile(monkeypatch):
    monkeypatch.delenv('AWS_PROFILE', raising=False)
    monkeypatch.setenv('BEDROCK_MODEL_ID', 'dummy')
    monkeypatch.delenv('BEDROCK_AUTH_MODE', raising=False)

    # Patch boto3.client directly for role-based flow
    def fake_client(service, region_name=None):
        return DummyClient(b'{"overall_summary":"role-ok","customer_summary":"c","adjuster_summary":"a","recommended_next_step":"n"}')

    monkeypatch.setattr('boto3.client', fake_client)

    res = bedrock_client.summarize_notes([{'text': 'hi'}])
    assert res['overall_summary'] == 'role-ok'


def test_profile_mode_forces_profile(monkeypatch):
    monkeypatch.delenv('AWS_PROFILE', raising=False)
    monkeypatch.setenv('BEDROCK_MODEL_ID', 'dummy')
    monkeypatch.setenv('BEDROCK_AUTH_MODE', 'profile')

    # Even when AWS_PROFILE not set, profile mode should use default 'Deepak' via Session
    captured = {}

    def fake_session(profile_name=None):
        captured['profile'] = profile_name
        return DummySession(profile_name)

    monkeypatch.setattr('boto3.Session', fake_session)

    res = bedrock_client.summarize_notes([{'text': 'x'}])
    assert captured.get('profile') == 'Deepak'
    assert res['overall_summary'] == 'ok'


def test_role_mode_forces_role_even_with_profile(monkeypatch):
    monkeypatch.setenv('AWS_PROFILE', 'Deepak')
    monkeypatch.setenv('BEDROCK_MODEL_ID', 'dummy')
    monkeypatch.setenv('BEDROCK_AUTH_MODE', 'role')

    def fake_client(service, region_name=None):
        return DummyClient(b'{"overall_summary":"forced-role","customer_summary":"c","adjuster_summary":"a","recommended_next_step":"n"}')

    monkeypatch.setattr('boto3.client', fake_client)

    res = bedrock_client.summarize_notes([{'text': 'y'}])
    assert res['overall_summary'] == 'forced-role'
