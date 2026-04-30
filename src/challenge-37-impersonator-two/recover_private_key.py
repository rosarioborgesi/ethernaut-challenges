from eth_account.messages import encode_defunct
from eth_account import Account
from eth_utils import keccak

# secp256k1 curve order
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

OWNER = "0x03E2cf81BBE61D1fD1421aFF98e8605a5A9e953a"
ADMIN = "0xADa4aFfe581d1A31d7F75E1c5a3A98b2D4C40f68"

r = int("e5648161e95dbf2bfc687b72b745269fa906031e2108118050aba59524a23c40", 16)

s1 = int("70026fc30e4e02a15468de57155b080f405bd5b88af05412a9c3217e028537e3", 16) # lock0
s2 = int("4c3ac03b268ae1d2aca1201e8a936adf578a8b95a49986d54de87cd0ccb68a79", 16) # admin1 + ADMIN

def eth_signed_hash(message_bytes: bytes) -> int:
    prefix = f"\x19Ethereum Signed Message:\n{len(message_bytes)}".encode()
    return int.from_bytes(keccak(prefix + message_bytes), "big")

# message 1: abi.encodePacked("lock", "0")
msg1 = b"lock0"

# message 2: abi.encodePacked("admin", "1", ADMIN)
msg2 = b"admin1" + bytes.fromhex(ADMIN[2:])

z1 = eth_signed_hash(msg1)
z2 = eth_signed_hash(msg2)

# Recover nonce k
k = ((z1 - z2) * pow(s1 - s2, -1, N)) % N

# Recover private key d
d = ((s1 * k - z1) * pow(r, -1, N)) % N

private_key = hex(d)
print("private key:", private_key)

acct = Account.from_key(private_key)
print("recovered address:", acct.address)
print("expected owner:   ", OWNER)