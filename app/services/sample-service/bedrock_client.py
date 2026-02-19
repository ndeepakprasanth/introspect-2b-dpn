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

    # For Claude models, use proper message format
    system_prompt = (
        "You are an insurance claims assistant. "
        "Given claim notes, produce a JSON object with these exact fields: "
        "overall_summary, customer_summary, adjuster_summary, recommended_next_step. "
        "Keep summaries concise (1-3 sentences). Return ONLY valid JSON, no extra text."
    )
    
    user_message = f"Summarize these claim notes:\n\n{combined}"

    # Build the request body based on the model
    if 'claude' in model_id.lower():
        # Claude models use messages format
        body = {
            "anthropic_version": "bedrock-2023-06-01",
            "max_tokens": 1024,
            "system": system_prompt,
            "messages": [
                {
                    "role": "user",
                    "content": user_message
                }
            ]
        }
        payload = json.dumps(body).encode('utf-8')
    elif 'nova' in model_id.lower():
        # Amazon Nova models use messages format with content as array
        body = {
            "max_tokens": 1024,
            "messages": [
                {
                    "role": "user",
                    "content": [{"text": system_prompt + "\n\n" + user_message}]
                }
            ]
        }
        payload = json.dumps(body).encode('utf-8')
    elif 'titan' in model_id.lower():
        # Titan models use inputText format (now EOL, but keep for compatibility)
        body = {
            "inputText": system_prompt + "\n\n" + user_message,
            "textGenerationConfig": {
                "maxTokenCount": 1024,
                "temperature": 0.7,
                "topP": 0.9
            }
        }
        payload = json.dumps(body).encode('utf-8')
    else:
        # Fallback for other models
        prompt = system_prompt + "\n\n" + user_message
        payload = prompt.encode('utf-8')

    try:
        response = client.invoke_model(modelId=model_id, contentType='application/json', accept='application/json', body=payload)
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

        # Parse the response based on model
        try:
            parsed_resp = json.loads(text)
            # Claude returns {"content": [...], "stop_reason": "..."}
            if 'content' in parsed_resp and isinstance(parsed_resp['content'], list):
                content = parsed_resp['content'][0].get('text', text)
            # Titan and Nova return {"results": [{"outputText": "..."}]}
            elif 'results' in parsed_resp and isinstance(parsed_resp['results'], list):
                content = parsed_resp['results'][0].get('outputText', text)
            # Nova Lite might return the output directly
            elif 'output' in parsed_resp and isinstance(parsed_resp['output'], dict):
                content = parsed_resp['output'].get('text', text)
            else:
                content = text
            
            # Extract JSON from content
            try:
                parsed = json.loads(content)
            except json.JSONDecodeError:
                # Try to find JSON substring
                start = content.find('{')
                end = content.rfind('}')
                if start != -1 and end != -1 and end > start:
                    parsed = json.loads(content[start:end+1])
                else:
                    raise
        except json.JSONDecodeError as e:
            logger.error(f'Failed to parse Bedrock response as JSON: {text[:200]}')
            raise

        # Ensure required keys exist
        keys = ['overall_summary', 'customer_summary', 'adjuster_summary', 'recommended_next_step']
        return {k: parsed.get(k, '') for k in keys}

    except Exception as e:
        logger.exception(f'Bedrock summarize failed: {e}')
        # Fallback to a safe default
        return {
            'overall_summary': 'Summarization service temporarily unavailable.',
            'customer_summary': 'We are processing your claim. Thank you for your patience.',
            'adjuster_summary': 'Review claim notes manually for detailed assessment.',
            'recommended_next_step': 'Follow up within 2 business days.'
        }
