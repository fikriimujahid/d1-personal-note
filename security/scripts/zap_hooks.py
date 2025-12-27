import os
import sys
import json
import traceback
import requests

def zap_started(zap, target):
    """
    Called when ZAP is starting.
    Used to perform authentication and set up the session.
    """
    auth_user = os.environ.get('ZAP_AUTH_USER')
    auth_pass = os.environ.get('ZAP_AUTH_PASS')
    auth_url = os.environ.get('ZAP_AUTH_LOGIN_URL') # Endpoint that returns tokens
    
    # Optional: Direct Cognito Parameters if not using a proxy login endpoint
    cognito_client_id = os.environ.get('ZAP_COGNITO_CLIENT_ID')
    # Default to direct cognito if client ID is provided, otherwise specific login url
    
    token = None

    if not (auth_user and auth_pass):
        print("Hook: No credentials provided. Skipping authentication.")
        return

    print(f"Hook: Starting authentication for user: {auth_user}")

    try:
        # Strategy 1: Direct Cognito User Pools (USER_PASSWORD_AUTH flow)
        # Requires ZAP_COGNITO_CLIENT_ID and ZAP_COGNITO_REGION (or inferred from URL)
        if cognito_client_id:
            print("Hook: Attempting Direct Cognito Auth...")
            # Infer region from default or env, currently assuming us-east-1 if not specified
            # But better to just ask for the URL.
            # AWS Cognito IDP Header
            headers = {
                'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
                'Content-Type': 'application/x-amz-json-1.1'
            }
            payload = {
                "ClientId": cognito_client_id,
                "AuthFlow": "USER_PASSWORD_AUTH",
                "AuthParameters": {
                    "USERNAME": auth_user,
                    "PASSWORD": auth_pass
                }
            }
            # Default IDP URL
            idp_url = auth_url if auth_url else "https://cognito-idp.ap-southeast-1.amazonaws.com/"
            
            response = requests.post(idp_url, headers=headers, json=payload, timeout=15)
            response.raise_for_status()
            data = response.json()
            
            # Extract idToken or accessToken
            auth_result = data.get('AuthenticationResult', {})
            token = auth_result.get('IdToken') or auth_result.get('AccessToken')

        # Strategy 2: Generic Login Endpoint (POST json)
        elif auth_url:
            print(f"Hook: Attempting Generic Login to {auth_url}...")
            payload = {'username': auth_user, 'password': auth_pass}
            response = requests.post(auth_url, json=payload, timeout=15)
            response.raise_for_status()
            data = response.json()
            
            # Common token fields
            token = data.get('token') or data.get('idToken') or data.get('accessToken') or data.get('jwt')

        if token:
            print("Hook: Authentication successful.")
            print("Hook: Injecting Authorization header...")
            
            # Remove existing Authorization headers to avoid duplication
            zap.replacer.remove_rule('AuthHeader')
            
            # Add Authorization: Bearer <token> to ALL requests (Scanner & Spider)
            zap.replacer.add_rule(
                description='AuthHeader',
                enabled=True,
                matchtype='REQ_HEADER',
                matchregex=False,
                matchstring='Authorization',
                replacement=f'Bearer {token}'
            )
            
            # Also set it as a global script (optional, but replacer is usually enough)
            
            # Load and visit URLs from seed file (if provided)
            load_seed_urls(zap)
        else:
            print("Hook: Authentication failed - No token found in response.")
            print(f"Hook: Response: {data}")

    except Exception as e:
        print(f"Hook: Authentication Error: {e}")
        traceback.print_exc()
    
    # Load seed URLs even if auth fails (for scanning public pages)
    load_seed_urls(zap)

def load_seed_urls(zap):
    """
    Load URLs from seed file and add them to ZAP for scanning.
    """
    seed_file = '/zap/wrk/urls.txt'
    
    if not os.path.exists(seed_file):
        print("Hook: No URL seed file found. Skipping.")
        return
    
    print(f"Hook: Loading URLs from seed file: {seed_file}")
    
    try:
        with open(seed_file, 'r') as f:
            urls = [line.strip() for line in f if line.strip() and not line.strip().startswith('#')]
        
        print(f"Hook: Found {len(urls)} URLs to scan")
        
        # Access each URL to add them to ZAP's site tree
        for url in urls:
            try:
                print(f"Hook: Accessing {url}")
                zap.urlopen(url)
            except Exception as e:
                print(f"Hook: Warning - Could not access {url}: {e}")
        
        print("Hook: Finished loading seed URLs")
    
    except Exception as e:
        print(f"Hook: Error loading seed file: {e}")
        traceback.print_exc()

def zap_pre_shutdown(zap):
    """
    Called before ZAP shuts down.
    """
    print("Hook: ZAP is shutting down.")
