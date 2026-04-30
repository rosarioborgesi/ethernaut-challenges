from eth_account import Account
from eth_account.messages import encode_defunct

PLAYER = "0xeCF94300dD67bB8c31F41BE3a2136D3f0abFb0B0"
PRIVATE_KEY="0x10a6891de55baf453d66c5faede86eabccf93f3d284540d205f24207670855cc"

sig_set_admin = Account.sign_message(
    encode_defunct(primitive=b"admin2" + bytes.fromhex(PLAYER[2:])),
    private_key=PRIVATE_KEY
)

sig_unlock = Account.sign_message(
    encode_defunct(primitive=b"lock3"),
    private_key=PRIVATE_KEY
)

print("setAdmin signature:", "0x" + sig_set_admin.signature.hex())
print("unlock signature:", "0x" + sig_unlock.signature.hex())