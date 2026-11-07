"""Checks that a connecting build machine is one of this repo's own standby
machines, from the identity token GitHub gives each Actions job (OIDC): a
JWT signed by GitHub. The coordinator's address is public (workflow inputs
are, in a public repo), so this, not a secret, is what keeps strangers out.

A token passes when GitHub's published key verifies its RS256 signature, it
was issued by GitHub's token service for AUDIENCE, it hasn't expired, and
its repository and run match what the coordinator expects. Pure Python, so
it runs in any session.
"""
import base64
import hashlib
import json
import time
import urllib.request

ISSUER = "https://token.actions.githubusercontent.com"
JWKS_URL = f"{ISSUER}/.well-known/jwks"
AUDIENCE = "scrap-heist-coordinator"
# DER prefix of a PKCS#1 v1.5 SHA-256 DigestInfo.
SHA256_PREFIX = bytes.fromhex("3031300d060960864801650304020105000420")

_keys = {}
_fetched = 0.0


def _b64(text):
	return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def _key(kid):
	global _fetched
	if kid not in _keys and time.time() - _fetched > 60:
		with urllib.request.urlopen(JWKS_URL, timeout=20) as response:
			for key in json.load(response)["keys"]:
				if key.get("kty") == "RSA":
					_keys[key["kid"]] = (int.from_bytes(_b64(key["n"]), "big"), int.from_bytes(_b64(key["e"]), "big"))
		_fetched = time.time()
	return _keys.get(kid)


def _rs256(message, signature, key):
	n, e = key
	size = (n.bit_length() + 7) // 8
	if len(signature) != size:
		return False
	decoded = pow(int.from_bytes(signature, "big"), e, n).to_bytes(size, "big")
	digest = SHA256_PREFIX + hashlib.sha256(message).digest()
	padding = size - len(digest) - 3
	return padding >= 8 and decoded == b"\x00\x01" + b"\xff" * padding + b"\x00" + digest


def verify(token, repository, run_id=None):
	"""Returns the token's claims if it is good, else raises ValueError."""
	try:
		head, body, signature = token.split(".")
		header, claims = json.loads(_b64(head)), json.loads(_b64(body))
	except Exception:
		raise ValueError("not a JWT")
	if header.get("alg") != "RS256":
		raise ValueError("not RS256")
	key = _key(header.get("kid"))
	if not key or not _rs256(f"{head}.{body}".encode(), _b64(signature), key):
		raise ValueError("bad signature")
	if claims.get("iss") != ISSUER or claims.get("aud") != AUDIENCE:
		raise ValueError("wrong issuer or audience")
	if claims.get("exp", 0) < time.time() - 30:
		raise ValueError("expired")
	if claims.get("repository") != repository:
		raise ValueError(f"wrong repository {claims.get('repository')}")
	if run_id is not None and str(claims.get("run_id")) != str(run_id):
		raise ValueError(f"wrong run {claims.get('run_id')}")
	return claims
