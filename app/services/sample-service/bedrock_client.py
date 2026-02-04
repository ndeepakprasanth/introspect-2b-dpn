import os
import json
import logging
import boto3

logger = logging.getLogger(__name__)

BEDROCK_MODEL_ENV = 'BEDROCK_MODEL_ID'
AWS_PROFILE_ENV = 'AWS_PROFILE'
AWS_REGION_ENV = 'AWS_REGION'
BEDROCK_AUTH_ENV = 'BEDROCK_AUTH_MODE'  # 'auto'|'profile'|'role'


def _choose_client(region):
    """Choose a boto3 Bedrock client based on auth mode and environment.

    - If BEDROCK_AUTH_MODE == 'profile', use boto3.Session(profile_name=...) (defaults to 'Deepak')
    - If BEDROCK_AUTH_MODE == 'role', use boto3.client(...) (IAM role / env creds)
    - If 'auto' (default) prefer profile when AWS_PROFILE is set, otherwise use role
    """
    auth_mode = os.environ.get(BEDROCK_AUTH_ENV, 'auto').lower()
    aws_profile = os.environ.get(AWS_PROFILE_ENV)

    # Resolve effective auth mode
    if auth_mode == 'auto':
        mode = 'profile' if aws_profile else 'role'
    elif auth_mode in ('profile', 'role'):
        mode = auth_mode
    else:
        mode = 'role'

    logger.info('Bedrock auth mode resolved to %s (env=%s, profile=%s)', mode, auth_mode, aws_profile)

    if mode == 'profile':
        profile_name = aws_profile or 'Deepak'
        session = boto3.Session(profile_name=profile_name)
        return session.client('bedrock-runtime', region_name=region)

    # role mode or fallback
    return boto3.client('bedrock-runtime', region_name=region)


def summarize_notes(notes):
    """Call Amazon Bedrock to summarize claim notes.

    Environment variables:
      - BEDROCK_MODEL_ID: the model id to invoke (required)
      - BEDROCK_AUTH_MODE: 'auto'|'profile'|'role' (optional)
      - AWS_PROFILE: AWS profile name (optional; defaults to 'Deepak' if profile mode used)
      - AWS_REGION: AWS region (defaults to 'us-east-1')

    Returns a dict with keys: overall_summary, customer_summary, adjuster_summary, recommended_next_step
    """

    model_id = os.environ.get(BEDROCK_MODEL_ENV)
    if not model_id:
        raise ValueError(f"{BEDROCK_MODEL_ENV} environment variable must be set to a valid Bedrock model id")

    region = os.environ.get(AWS_REGION_ENV, 'us-east-1')

    client = _choose_client(region)

    combined = "\n".join([n.get('text', '') for n in notes])

    prompt = (
        "You are an insurance claims assistant. Given the following claim notes, produce a JSON object with the "
        "following fields: overall_summary, customer_summary, adjuster_summary, recommended_next_step. "
        "Keep the summaries concise (1-3 sentences). Return only valid JSON. Notes: \n" + combined
    )

    payload = prompt.encode('utf-8')

    try:
        response = client.invoke_model(modelId=model_id, contentType='text/plain', accept='application/json', body=payload)
        # Response may contain body as bytes-like
        body = response.get('body')
        if isinstance(body, (bytes, bytearray)):
            text = body.decode('utf-8')
        else:
            # some SDKs return streaming or io-like bodies
            try:
                text = body.read().decode('utf-8')
            except Exception:
                text = str(body)

        # The model should return JSON; guard against extra text
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            # Try to find JSON substring
            start = text.find('{')
            end = text.rfind('}')
            if start != -1 and end != -1 and end > start:
                parsed = json.loads(text[start:end+1])
            else:
                raise

        # Ensure required keys exist
        keys = ['overall_summary', 'customer_summary', 'adjuster_summary', 'recommended_next_step']
        return {k: parsed.get(k, '') for k in keys}

    except Exception:
        logger.exception('Bedrock summarize failed')
        # Fallback to a safe default
        return {
            'overall_summary': 'Bedrock summarization failed.',
            'customer_summary': 'Bedrock summarization failed.',
            'adjuster_summary': 'Bedrock summarization failed.',
            'recommended_next_step': 'Review notes manually.'
        }
